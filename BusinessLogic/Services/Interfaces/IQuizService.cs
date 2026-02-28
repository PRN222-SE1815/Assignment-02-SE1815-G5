using BusinessLogic.DTOs.Requests.Quiz;
using BusinessLogic.DTOs.Responses.Quiz;

namespace BusinessLogic.Services.Interfaces;

/// <summary>
/// Quiz service for Teacher and Student operations.
/// All methods authorize internally based on actorUserId and actorRole.
/// </summary>
public interface IQuizService
{
    // ==================== TEACHER Operations ====================

    /// <summary>
    /// Create a draft quiz for a class section.
    /// Only TEACHER who owns the ClassSection can call.
    /// </summary>
    /// <exception cref="Exceptions.ForbiddenException">Not a teacher or doesn't own the class</exception>
    /// <exception cref="Exceptions.NotFoundException">ClassSection not found</exception>
    /// <exception cref="Exceptions.BusinessException">Validation failed</exception>
    Task<CreateQuizResponse> CreateDraftQuizAsync(int teacherUserId, string actorRole, CreateQuizRequest request);

    /// <summary>
    /// Add a question with answers to a quiz.
    /// Only TEACHER who owns the quiz's ClassSection can call.
    /// </summary>
    /// <exception cref="Exceptions.ForbiddenException">Not authorized</exception>
    /// <exception cref="Exceptions.NotFoundException">Quiz not found</exception>
    /// <exception cref="Exceptions.BusinessException">Validation failed (answers, quiz status, etc.)</exception>
    Task<AddQuestionResponse> AddQuestionAsync(int teacherUserId, string actorRole, AddQuestionRequest request);

    /// <summary>
    /// Publish a quiz (DRAFT -> PUBLISHED).
    /// </summary>
    /// <exception cref="Exceptions.ForbiddenException">Not authorized</exception>
    /// <exception cref="Exceptions.NotFoundException">Quiz not found</exception>
    /// <exception cref="Exceptions.BusinessException">Validation failed (question count, etc.)</exception>
    Task PublishQuizAsync(int teacherUserId, string actorRole, PublishQuizRequest request);

    /// <summary>
    /// Close a quiz (PUBLISHED -> CLOSED).
    /// </summary>
    /// <exception cref="Exceptions.ForbiddenException">Not authorized</exception>
    /// <exception cref="Exceptions.NotFoundException">Quiz not found</exception>
    /// <exception cref="Exceptions.BusinessException">Quiz not in PUBLISHED status</exception>
    Task CloseQuizAsync(int teacherUserId, string actorRole, CloseQuizRequest request);

    /// <summary>
    /// List all quizzes created by the teacher (all statuses).
    /// </summary>
    Task<List<QuizSummaryResponse>> ListQuizzesForTeacherAsync(int teacherUserId, string actorRole);

    // ==================== STUDENT Operations ====================

    /// <summary>
    /// List published quizzes for a class section.
    /// Student must be ENROLLED in the class.
    /// </summary>
    /// <exception cref="Exceptions.ForbiddenException">Not a student or not enrolled</exception>
    Task<List<QuizSummaryResponse>> ListPublishedQuizzesForClassAsync(int studentUserId, string actorRole, int classSectionId);

    /// <summary>
    /// List all published quizzes across all active enrollments for a student.
    /// </summary>
    Task<List<QuizSummaryResponse>> ListAllPublishedQuizzesForStudentAsync(int studentUserId, string actorRole);

    /// <summary>
    /// Start a quiz attempt.
    /// </summary>
    /// <exception cref="Exceptions.ForbiddenException">Not enrolled</exception>
    /// <exception cref="Exceptions.NotFoundException">Quiz not found</exception>
    /// <exception cref="Exceptions.BusinessException">Quiz not available (not published, time window)</exception>
    /// <exception cref="Exceptions.ConflictException">Already attempted (409)</exception>
    Task<StartAttemptResponse> StartAttemptAsync(int studentUserId, string actorRole, StartAttemptRequest request, DateTime nowUtc);

    /// <summary>
    /// Submit quiz attempt and get score.
    /// </summary>
    /// <exception cref="Exceptions.ForbiddenException">Attempt doesn't belong to student</exception>
    /// <exception cref="Exceptions.NotFoundException">Attempt not found</exception>
    /// <exception cref="Exceptions.BusinessException">Quiz expired, invalid answers, etc.</exception>
    Task<SubmitAttemptResponse> SubmitAttemptAsync(int studentUserId, string actorRole, SubmitAttemptRequest request, DateTime nowUtc);
}
