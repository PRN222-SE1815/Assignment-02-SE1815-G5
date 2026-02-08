using BusinessLogic.DTOs.Requests.Quiz;
using BusinessLogic.DTOs.Responses.Quiz;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using DataAccess;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implements;

public class QuizService : IQuizService
{
    private readonly IQuizRepository _quizRepo;
    private readonly IEnrollmentRepository _enrollmentRepo;
    private readonly SchoolManagementDbContext _dbContext;
    private readonly ILogger<QuizService> _logger;

    // Valid values for TotalQuestions
    private static readonly HashSet<int> ValidTotalQuestions = new() { 10, 20, 30 };

    // Status constants
    private const string STATUS_DRAFT = "DRAFT";
    private const string STATUS_PUBLISHED = "PUBLISHED";
    private const string STATUS_CLOSED = "CLOSED";
    private const string ATTEMPT_IN_PROGRESS = "IN_PROGRESS";
    private const string ATTEMPT_SUBMITTED = "SUBMITTED";

    // Role constants
    private const string ROLE_TEACHER = "TEACHER";
    private const string ROLE_STUDENT = "STUDENT";

    // Question type constants
    private const string QTYPE_MCQ = "MCQ";
    private const string QTYPE_TRUE_FALSE = "TRUE_FALSE";

    public QuizService(
        IQuizRepository quizRepo,
        IEnrollmentRepository enrollmentRepo,
        SchoolManagementDbContext dbContext,
        ILogger<QuizService> logger)
    {
        _quizRepo = quizRepo;
        _enrollmentRepo = enrollmentRepo;
        _dbContext = dbContext;
        _logger = logger;
    }

    // ==================== TEACHER Operations ====================

    public async Task<CreateQuizResponse> CreateDraftQuizAsync(
        int teacherUserId,
        string actorRole,
        CreateQuizRequest request)
    {
        // 1. Authorize: must be TEACHER
        EnsureTeacherRole(actorRole);

        // 2. Validate TotalQuestions
        if (!ValidTotalQuestions.Contains(request.TotalQuestions))
        {
            throw new BusinessException(
                $"TotalQuestions must be one of: {string.Join(", ", ValidTotalQuestions)}",
                "INVALID_TOTAL_QUESTIONS");
        }

        // 3. Validate teacher owns ClassSection
        var classTeacherId = await _quizRepo.GetClassSectionTeacherIdAsync(request.ClassSectionId);
        if (classTeacherId == null)
        {
            throw new NotFoundException("ClassSection", request.ClassSectionId);
        }
        if (classTeacherId != teacherUserId)
        {
            throw new ForbiddenException("You are not the teacher of this class section.");
        }

        // 4. Validate time window
        if (request.StartAt.HasValue && request.EndAt.HasValue && request.EndAt <= request.StartAt)
        {
            throw new BusinessException("EndAt must be after StartAt.", "INVALID_TIME_WINDOW");
        }

        // 5. Create quiz
        var quiz = new Quiz
        {
            ClassSectionId = request.ClassSectionId,
            CreatedBy = teacherUserId,
            QuizTitle = request.QuizTitle,
            Description = request.Description,
            TotalQuestions = request.TotalQuestions,
            TimeLimitMin = request.TimeLimitMin,
            ShuffleQuestions = request.ShuffleQuestions,
            ShuffleAnswers = request.ShuffleAnswers,
            StartAt = request.StartAt,
            EndAt = request.EndAt,
            Status = STATUS_DRAFT,
            CreatedAt = DateTime.UtcNow
        };

        await _quizRepo.CreateQuizAsync(quiz);
        await _quizRepo.SaveChangesAsync();

        _logger.LogInformation("Teacher {TeacherId} created draft quiz {QuizId} for ClassSection {ClassSectionId}",
            teacherUserId, quiz.QuizId, request.ClassSectionId);

        return new CreateQuizResponse
        {
            QuizId = quiz.QuizId,
            QuizTitle = quiz.QuizTitle,
            Status = quiz.Status
        };
    }

    public async Task<AddQuestionResponse> AddQuestionAsync(
        int teacherUserId,
        string actorRole,
        AddQuestionRequest request)
    {
        // 1. Authorize
        EnsureTeacherRole(actorRole);

        // 2. Validate question type
        if (request.QuestionType != QTYPE_MCQ && request.QuestionType != QTYPE_TRUE_FALSE)
        {
            throw new BusinessException(
                $"QuestionType must be '{QTYPE_MCQ}' or '{QTYPE_TRUE_FALSE}'.",
                "INVALID_QUESTION_TYPE");
        }

        // 3. Validate answers
        ValidateAnswers(request.Answers);

        // 4. Get quiz and authorize
        var quiz = await _quizRepo.GetQuizWithClassSectionAsync(request.QuizId);
        if (quiz == null)
        {
            throw new NotFoundException("Quiz", request.QuizId);
        }
        if (quiz.ClassSection.TeacherId != teacherUserId)
        {
            throw new ForbiddenException("You are not the teacher of this quiz's class section.");
        }

        // 5. Quiz must be DRAFT
        if (quiz.Status != STATUS_DRAFT)
        {
            throw new BusinessException(
                $"Cannot add questions to quiz with status '{quiz.Status}'. Quiz must be DRAFT.",
                "INVALID_QUIZ_STATUS");
        }

        // 6. Check question limit
        var currentCount = await _quizRepo.GetQuestionCountAsync(request.QuizId);
        if (currentCount >= quiz.TotalQuestions)
        {
            throw new BusinessException(
                $"Quiz already has {currentCount} questions (max: {quiz.TotalQuestions}).",
                "QUESTION_LIMIT_REACHED");
        }

        // 7. Create question
        var question = new QuizQuestion
        {
            QuizId = request.QuizId,
            QuestionText = request.QuestionText,
            QuestionType = request.QuestionType,
            Points = request.Points,
            SortOrder = currentCount + 1
        };

        await _quizRepo.CreateQuestionAsync(question);
        await _quizRepo.SaveChangesAsync();

        // 8. Create answers
        var answers = request.Answers.Select(a => new QuizAnswer
        {
            QuestionId = question.QuestionId,
            AnswerText = a.AnswerText,
            IsCorrect = a.IsCorrect
        });
        await _quizRepo.CreateAnswersAsync(answers);
        await _quizRepo.SaveChangesAsync();

        _logger.LogInformation("Teacher {TeacherId} added question {QuestionId} to quiz {QuizId}",
            teacherUserId, question.QuestionId, request.QuizId);

        return new AddQuestionResponse
        {
            QuestionId = question.QuestionId,
            QuizId = request.QuizId,
            CurrentQuestionCount = currentCount + 1,
            TotalQuestionsRequired = quiz.TotalQuestions
        };
    }

    public async Task PublishQuizAsync(
        int teacherUserId,
        string actorRole,
        PublishQuizRequest request)
    {
        // 1. Authorize
        EnsureTeacherRole(actorRole);

        // 2. Get quiz with questions and answers
        var quiz = await _quizRepo.GetQuizWithQuestionsAndAnswersAsync(request.QuizId);
        if (quiz == null)
        {
            throw new NotFoundException("Quiz", request.QuizId);
        }
        if (quiz.ClassSection.TeacherId != teacherUserId)
        {
            throw new ForbiddenException("You are not the teacher of this quiz's class section.");
        }

        // 3. Quiz must be DRAFT
        if (quiz.Status != STATUS_DRAFT)
        {
            throw new BusinessException(
                $"Cannot publish quiz with status '{quiz.Status}'. Quiz must be DRAFT.",
                "INVALID_QUIZ_STATUS");
        }

        // 4. Validate question count
        var questionCount = quiz.QuizQuestions.Count;
        if (questionCount != quiz.TotalQuestions)
        {
            throw new BusinessException(
                $"Quiz has {questionCount} questions but requires exactly {quiz.TotalQuestions}.",
                "INSUFFICIENT_QUESTIONS");
        }

        // 5. Validate each question has proper answers
        foreach (var question in quiz.QuizQuestions)
        {
            var answerDtos = question.QuizAnswers.Select(a => new AddAnswerDto
            {
                AnswerText = a.AnswerText,
                IsCorrect = a.IsCorrect
            }).ToList();
            ValidateAnswers(answerDtos);
        }

        // 6. Validate time window
        var finalStartAt = request.StartAt ?? quiz.StartAt;
        var finalEndAt = request.EndAt ?? quiz.EndAt;
        if (finalStartAt.HasValue && finalEndAt.HasValue && finalEndAt <= finalStartAt)
        {
            throw new BusinessException("EndAt must be after StartAt.", "INVALID_TIME_WINDOW");
        }

        // 7. Update quiz
        quiz.Status = STATUS_PUBLISHED;
        if (request.StartAt.HasValue) quiz.StartAt = request.StartAt;
        if (request.EndAt.HasValue) quiz.EndAt = request.EndAt;

        _quizRepo.UpdateQuiz(quiz);
        await _quizRepo.SaveChangesAsync();

        _logger.LogInformation("Teacher {TeacherId} published quiz {QuizId}", teacherUserId, request.QuizId);
    }

    public async Task CloseQuizAsync(
        int teacherUserId,
        string actorRole,
        CloseQuizRequest request)
    {
        // 1. Authorize
        EnsureTeacherRole(actorRole);

        // 2. Get quiz
        var quiz = await _quizRepo.GetQuizWithClassSectionAsync(request.QuizId);
        if (quiz == null)
        {
            throw new NotFoundException("Quiz", request.QuizId);
        }
        if (quiz.ClassSection.TeacherId != teacherUserId)
        {
            throw new ForbiddenException("You are not the teacher of this quiz's class section.");
        }

        // 3. Quiz must be PUBLISHED
        if (quiz.Status != STATUS_PUBLISHED)
        {
            throw new BusinessException(
                $"Cannot close quiz with status '{quiz.Status}'. Quiz must be PUBLISHED.",
                "INVALID_QUIZ_STATUS");
        }

        // 4. Update
        quiz.Status = STATUS_CLOSED;
        _quizRepo.UpdateQuiz(quiz);
        await _quizRepo.SaveChangesAsync();

        _logger.LogInformation("Teacher {TeacherId} closed quiz {QuizId}", teacherUserId, request.QuizId);
    }

    // ==================== STUDENT Operations ====================

    public async Task<List<QuizSummaryResponse>> ListPublishedQuizzesForClassAsync(
        int studentUserId,
        string actorRole,
        int classSectionId)
    {
        // 1. Authorize
        EnsureStudentRole(actorRole);

        // 2. Check enrollment
        var isEnrolled = await _enrollmentRepo.IsStudentEnrolledAsync(studentUserId, classSectionId);
        if (!isEnrolled)
        {
            throw new ForbiddenException("You are not enrolled in this class section.");
        }

        // 3. Get published quizzes
        var quizzes = await _quizRepo.GetPublishedQuizzesForClassAsync(classSectionId);

        return quizzes.Select(q => new QuizSummaryResponse
        {
            QuizId = q.QuizId,
            QuizTitle = q.QuizTitle,
            Description = q.Description,
            TotalQuestions = q.TotalQuestions,
            TimeLimitMin = q.TimeLimitMin,
            StartAt = q.StartAt,
            EndAt = q.EndAt,
            Status = q.Status,
            CreatedAt = q.CreatedAt
        }).ToList();
    }

    public async Task<StartAttemptResponse> StartAttemptAsync(
        int studentUserId,
        string actorRole,
        StartAttemptRequest request,
        DateTime nowUtc)
    {
        // 1. Authorize
        EnsureStudentRole(actorRole);

        // 2. Get quiz
        var quiz = await _quizRepo.GetQuizForStudentAsync(request.QuizId);
        if (quiz == null)
        {
            throw new NotFoundException("Quiz", request.QuizId);
        }

        // 3. Quiz must be PUBLISHED
        if (quiz.Status != STATUS_PUBLISHED)
        {
            throw new BusinessException(
                $"Quiz is not available. Current status: '{quiz.Status}'.",
                "QUIZ_NOT_AVAILABLE");
        }

        // 4. Check time window
        if (quiz.StartAt.HasValue && nowUtc < quiz.StartAt.Value)
        {
            throw new BusinessException(
                $"Quiz has not started yet. Starts at: {quiz.StartAt.Value:u}",
                "QUIZ_NOT_STARTED");
        }
        if (quiz.EndAt.HasValue && nowUtc > quiz.EndAt.Value)
        {
            throw new BusinessException(
                $"Quiz has ended. Ended at: {quiz.EndAt.Value:u}",
                "QUIZ_ENDED");
        }

        // 5. Get enrollment
        var enrollmentId = await _enrollmentRepo.GetEnrolledEnrollmentIdAsync(studentUserId, quiz.ClassSectionId);
        if (enrollmentId == null)
        {
            throw new ForbiddenException("You are not enrolled in this class section.");
        }

        // 6. Check existing attempt
        var hasAttempt = await _quizRepo.HasAttemptAsync(request.QuizId, enrollmentId.Value);
        if (hasAttempt)
        {
            // HTTP 409 Conflict
            throw new ConflictException("You have already attempted this quiz. Only one attempt is allowed.");
        }

        // 7. Create attempt with transaction (for race condition protection)
        var attempt = new QuizAttempt
        {
            QuizId = request.QuizId,
            EnrollmentId = enrollmentId.Value,
            ClassSectionId = quiz.ClassSectionId,
            StartedAt = nowUtc,
            Status = ATTEMPT_IN_PROGRESS
        };

        await using var transaction = await _dbContext.Database.BeginTransactionAsync();
        try
        {
            await _quizRepo.CreateAttemptAsync(attempt);
            await _quizRepo.SaveChangesAsync();
            await transaction.CommitAsync();
        }
        catch (DbUpdateException ex) when (ex.InnerException?.Message.Contains("UX_QuizAttempts_OnePerStudent") == true)
        {
            // Race condition: unique index violation -> HTTP 409
            throw new ConflictException("You have already attempted this quiz. Only one attempt is allowed.");
        }

        _logger.LogInformation("Student {StudentId} started attempt {AttemptId} for quiz {QuizId}",
            studentUserId, attempt.AttemptId, request.QuizId);

        // 8. Get questions
        var questions = await _quizRepo.GetQuestionsWithAnswersAsync(request.QuizId);

        // 9. Apply shuffle
        // NOTE: Order is NOT stable on refresh because we cannot store snapshot order (schema change forbidden).
        // If student refreshes, the order may change. This is a known limitation.
        var rng = new Random();
        string? shuffleNote = null;

        if (quiz.ShuffleQuestions)
        {
            questions = questions.OrderBy(_ => rng.Next()).ToList();
            shuffleNote = "Question/answer order is randomized and NOT stable on page refresh (schema limitation).";
        }

        var questionResponses = questions.Select(q =>
        {
            var answers = q.QuizAnswers.ToList();
            if (quiz.ShuffleAnswers)
            {
                answers = answers.OrderBy(_ => rng.Next()).ToList();
                shuffleNote ??= "Answer order is randomized and NOT stable on page refresh (schema limitation).";
            }

            return new QuestionForAttemptResponse
            {
                QuestionId = q.QuestionId,
                QuestionText = q.QuestionText,
                QuestionType = q.QuestionType,
                Points = q.Points,
                Answers = answers.Select(a => new AnswerOptionResponse
                {
                    AnswerId = a.AnswerId,
                    AnswerText = a.AnswerText
                    // IsCorrect is NOT exposed
                }).ToList()
            };
        }).ToList();

        return new StartAttemptResponse
        {
            AttemptId = attempt.AttemptId,
            QuizId = quiz.QuizId,
            QuizTitle = quiz.QuizTitle,
            TimeLimitMin = quiz.TimeLimitMin,
            StartedAt = attempt.StartedAt,
            EndAt = quiz.EndAt,
            Questions = questionResponses,
            ShuffleNote = shuffleNote
        };
    }

    public async Task<SubmitAttemptResponse> SubmitAttemptAsync(
        int studentUserId,
        string actorRole,
        SubmitAttemptRequest request,
        DateTime nowUtc)
    {
        // 1. Authorize
        EnsureStudentRole(actorRole);

        // 2. Get attempt
        var attempt = await _quizRepo.GetAttemptWithQuizAndEnrollmentAsync(request.AttemptId);
        if (attempt == null)
        {
            throw new NotFoundException("QuizAttempt", request.AttemptId);
        }

        // 3. Verify ownership
        if (attempt.Enrollment.StudentId != studentUserId)
        {
            throw new ForbiddenException("This attempt does not belong to you.");
        }

        // 4. Attempt must be IN_PROGRESS
        if (attempt.Status != ATTEMPT_IN_PROGRESS)
        {
            throw new BusinessException(
                $"Cannot submit attempt with status '{attempt.Status}'.",
                "INVALID_ATTEMPT_STATUS");
        }

        // 5. Check deadline
        if (attempt.Quiz.EndAt.HasValue && nowUtc > attempt.Quiz.EndAt.Value)
        {
            throw new BusinessException("Quiz has expired. Cannot submit after the deadline.", "QUIZ_EXPIRED");
        }

        // 6. Validate answers
        var validQuestionIds = await _quizRepo.GetQuestionIdsForQuizAsync(attempt.QuizId);
        var submittedQuestionIds = request.Answers.Select(a => a.QuestionId).Distinct().ToList();

        foreach (var qid in submittedQuestionIds)
        {
            if (!validQuestionIds.Contains(qid))
            {
                throw new BusinessException($"Question {qid} does not belong to this quiz.", "INVALID_QUESTION");
            }
        }

        var validAnswersByQuestion = await _quizRepo.GetAnswerIdsForQuestionsAsync(submittedQuestionIds);
        foreach (var ans in request.Answers)
        {
            if (!validAnswersByQuestion.TryGetValue(ans.QuestionId, out var validAnswers))
            {
                throw new BusinessException($"Question {ans.QuestionId} not found.", "INVALID_QUESTION");
            }
            if (!validAnswers.Contains(ans.SelectedAnswerId))
            {
                throw new BusinessException(
                    $"Answer {ans.SelectedAnswerId} does not belong to question {ans.QuestionId}.",
                    "INVALID_ANSWER");
            }
        }

        // 7. Grade
        var correctAnswers = await _quizRepo.GetCorrectAnswerIdsAsync(submittedQuestionIds);
        var questionPoints = await _quizRepo.GetQuestionPointsAsync(submittedQuestionIds);

        decimal totalScore = 0;
        int correctCount = 0;

        var attemptAnswers = new List<QuizAttemptAnswer>();
        foreach (var submission in request.Answers)
        {
            var isCorrect = correctAnswers.TryGetValue(submission.QuestionId, out var correctId)
                            && submission.SelectedAnswerId == correctId;

            if (isCorrect)
            {
                correctCount++;
                if (questionPoints.TryGetValue(submission.QuestionId, out var points))
                {
                    totalScore += points;
                }
            }

            attemptAnswers.Add(new QuizAttemptAnswer
            {
                AttemptId = request.AttemptId,
                QuestionId = submission.QuestionId,
                SelectedAnswerId = submission.SelectedAnswerId,
                IsCorrect = isCorrect
            });
        }

        // 8. Update attempt
        attempt.Status = ATTEMPT_SUBMITTED;
        attempt.SubmittedAt = nowUtc;
        attempt.Score = totalScore;

        await _quizRepo.CreateAttemptAnswersAsync(attemptAnswers);
        _quizRepo.UpdateAttempt(attempt);
        await _quizRepo.SaveChangesAsync();

        _logger.LogInformation("Student {StudentId} submitted attempt {AttemptId}. Score: {Score}, Correct: {Correct}/{Total}",
            studentUserId, request.AttemptId, totalScore, correctCount, validQuestionIds.Count);

        return new SubmitAttemptResponse
        {
            AttemptId = request.AttemptId,
            Score = totalScore,
            CorrectCount = correctCount,
            TotalCount = validQuestionIds.Count,
            SubmittedAt = nowUtc
        };
    }

    // ==================== Private Helpers ====================

    private static void EnsureTeacherRole(string actorRole)
    {
        if (!string.Equals(actorRole, ROLE_TEACHER, StringComparison.OrdinalIgnoreCase))
        {
            throw new ForbiddenException("Only teachers can perform this action.");
        }
    }

    private static void EnsureStudentRole(string actorRole)
    {
        if (!string.Equals(actorRole, ROLE_STUDENT, StringComparison.OrdinalIgnoreCase))
        {
            throw new ForbiddenException("Only students can perform this action.");
        }
    }

    /// <summary>
    /// Validate answers: >= 2 answers, exactly 1 correct.
    /// </summary>
    private static void ValidateAnswers(List<AddAnswerDto> answers)
    {
        if (answers.Count < 2)
        {
            throw new BusinessException(
                $"Question must have at least 2 answers. Found: {answers.Count}",
                "INSUFFICIENT_ANSWERS");
        }

        var correctCount = answers.Count(a => a.IsCorrect);
        if (correctCount != 1)
        {
            throw new BusinessException(
                $"Question must have exactly 1 correct answer. Found: {correctCount}",
                "INVALID_CORRECT_COUNT");
        }
    }
}
