using BusinessLogic.Constants;
using BusinessLogic.DTOs.Requests.Gradebook;
using BusinessLogic.DTOs.Response;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implements;

public sealed class GradebookSyncService : IGradebookSyncService
{
    private const string AttemptStatusGraded = "GRADED";
    private const string GradebookStatusLocked = "LOCKED";
    private const string GradebookStatusArchived = "ARCHIVED";
    private const int MaxRetries = 2;

    private readonly IQuizRepository _quizRepository;
    private readonly IGradeBookRepository _gradeBookRepository;
    private readonly ILogger<GradebookSyncService> _logger;

    public GradebookSyncService(
        IQuizRepository quizRepository,
        IGradeBookRepository gradeBookRepository,
        ILogger<GradebookSyncService> logger)
    {
        _quizRepository = quizRepository;
        _gradeBookRepository = gradeBookRepository;
        _logger = logger;
    }

    public async Task<ServiceResult<bool>> SyncQuizAttemptScoreAsync(SyncQuizScoreRequest request, CancellationToken ct = default)
    {
        try
        {
            if (request is null || request.AttemptId <= 0)
            {
                return ServiceResult<bool>.Fail(ErrorCodes.InvalidInput, "AttemptId must be greater than 0.");
            }

            var attempt = await _quizRepository.GetAttemptForGradeSyncAsync(request.AttemptId, ct);
            if (attempt is null)
            {
                return ServiceResult<bool>.Fail(ErrorCodes.InvalidInput, "Quiz attempt not found.");
            }

            if (!string.Equals(attempt.Status, AttemptStatusGraded, StringComparison.OrdinalIgnoreCase) || !attempt.Score.HasValue)
            {
                return ServiceResult<bool>.Fail(ErrorCodes.InvalidState, "Quiz attempt is not eligible for gradebook sync.");
            }

            var gradebook = await _gradeBookRepository.GetByClassSectionIdAsync(attempt.ClassSectionId, ct);
            if (gradebook is null)
            {
                return ServiceResult<bool>.Fail(ErrorCodes.GradebookNotFound, "Gradebook not found.");
            }

            if (string.Equals(gradebook.Status, GradebookStatusLocked, StringComparison.OrdinalIgnoreCase)
                || string.Equals(gradebook.Status, GradebookStatusArchived, StringComparison.OrdinalIgnoreCase))
            {
                _logger.LogWarning(
                    "Gradebook sync skipped - not editable. AttemptId={AttemptId}, GradeBookId={GradeBookId}, Status={Status}",
                    request.AttemptId, gradebook.GradeBookId, gradebook.Status);
                return ServiceResult<bool>.Fail(ErrorCodes.InvalidState, "Gradebook is not editable.");
            }

            var gradeItem = await _quizRepository.FindGradeItemForQuizAsync(gradebook.GradeBookId, attempt.QuizId, ct);
            if (gradeItem is null)
            {
                _logger.LogWarning(
                    "Gradebook sync skipped - grade item not found. AttemptId={AttemptId}, GradeBookId={GradeBookId}, QuizId={QuizId}",
                    request.AttemptId, gradebook.GradeBookId, attempt.QuizId);
                return ServiceResult<bool>.Fail(ErrorCodes.ItemNotFound, "Quiz grade item mapping not found.");
            }

            var normalizedScore = NormalizeToTenScale(attempt.Score.Value);
            var now = DateTime.UtcNow;
            var actorUserId = request.ActorUserId ?? attempt.Enrollment.StudentId;

            var oldEntry = await _gradeBookRepository.GetGradeEntryAsync(gradeItem.GradeItemId, attempt.EnrollmentId, ct);
            if (oldEntry is not null && oldEntry.Score == normalizedScore)
            {
                _logger.LogInformation(
                    "Gradebook sync idempotent - score unchanged. AttemptId={AttemptId}, GradeItemId={GradeItemId}, EnrollmentId={EnrollmentId}, Score={Score}",
                    request.AttemptId, gradeItem.GradeItemId, attempt.EnrollmentId, normalizedScore);
                return ServiceResult<bool>.Success(true);
            }

            var upsertEntry = new GradeEntry
            {
                GradeItemId = gradeItem.GradeItemId,
                EnrollmentId = attempt.EnrollmentId,
                Score = normalizedScore,
                UpdatedBy = actorUserId,
                UpdatedAt = now
            };

            var auditLog = new GradeAuditLog
            {
                ActorUserId = actorUserId,
                OldScore = oldEntry?.Score,
                NewScore = normalizedScore,
                Reason = string.IsNullOrWhiteSpace(request.Reason) ? "AUTO_SYNC_FROM_QUIZ" : request.Reason.Trim(),
                CreatedAt = now
            };

            for (var retry = 0; retry <= MaxRetries; retry++)
            {
                try
                {
                    await _gradeBookRepository.UpsertGradeEntryAsync(upsertEntry, ct);

                    if (oldEntry is null)
                    {
                        auditLog.GradeEntry = upsertEntry;
                    }
                    else
                    {
                        auditLog.GradeEntryId = oldEntry.GradeEntryId;
                    }

                    await _gradeBookRepository.AddGradeAuditLogAsync(auditLog, ct);
                    await _gradeBookRepository.SaveChangesAsync(ct);
                    break;
                }
                catch (DbUpdateConcurrencyException) when (retry < MaxRetries)
                {
                    _logger.LogWarning(
                        "Concurrency conflict during gradebook sync, retry {Retry}/{MaxRetries}. AttemptId={AttemptId}",
                        retry + 1, MaxRetries, request.AttemptId);
                    await Task.Delay(50 * (retry + 1), ct);
                }
            }

            _logger.LogInformation(
                "Gradebook sync completed. AttemptId={AttemptId}, GradeItemId={GradeItemId}, EnrollmentId={EnrollmentId}, OldScore={OldScore}, NewScore={NewScore}",
                request.AttemptId, gradeItem.GradeItemId, attempt.EnrollmentId, oldEntry?.Score, normalizedScore);

            return ServiceResult<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "SyncQuizAttemptScoreAsync failed. AttemptId={AttemptId}", request?.AttemptId);
            return ServiceResult<bool>.Fail(ErrorCodes.InternalError, "An unexpected error occurred.");
        }
    }

    private static decimal NormalizeToTenScale(decimal score)
    {
        return Math.Clamp(score, 0m, 10m);
    }
}
