using BusinessObject.Entities;

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
    Task<int> CreateDraftQuizAsync(
        int teacherUserId,
        string actorRole,
        int classSectionId,
        string quizTitle,
        string? description,
        int totalQuestions,
        int? timeLimitMin,
        bool shuffleQuestions,
        bool shuffleAnswers,
        DateTime? startAt,
        DateTime? endAt);

    /// <summary>
    /// Add a question with answers to a quiz.
    /// Only TEACHER who owns the quiz's ClassSection can call.
    /// </summary>
    Task<int> AddQuestionAsync(
        int teacherUserId,
        string actorRole,
        int quizId,
        string questionText,
        string questionType,
        decimal points,
        IEnumerable<AnswerInput> answers);

    /// <summary>
    /// Publish a quiz (DRAFT -> PUBLISHED).
    /// Validates question count and answer rules.
    /// </summary>
    Task PublishQuizAsync(
        int teacherUserId,
        string actorRole,
        int quizId,
        DateTime? startAt,
        DateTime? endAt);

    /// <summary>
    /// Close a quiz (PUBLISHED -> CLOSED).
    /// </summary>
    Task CloseQuizAsync(
        int teacherUserId,
        string actorRole,
        int quizId);

    // ==================== STUDENT Operations ====================

    /// <summary>
    /// List published quizzes for a class section.
    /// Student must be ENROLLED in the class.
    /// </summary>
    Task<List<QuizSummary>> ListPublishedQuizzesForClassAsync(
        int studentUserId,
        string actorRole,
        int classSectionId);

    /// <summary>
    /// Start a quiz attempt.
    /// Returns attemptId and questions with answers (shuffled if configured).
    /// </summary>
    Task<StartAttemptResult> StartAttemptAsync(
        int studentUserId,
        string actorRole,
        int quizId,
        DateTime nowUtc);

    /// <summary>
    /// Submit quiz attempt and get score.
    /// </summary>
    Task<SubmitAttemptResult> SubmitAttemptAsync(
        int studentUserId,
        string actorRole,
        int attemptId,
        DateTime nowUtc,
        IEnumerable<AnswerSubmission> answers);
}

// ==================== DTOs for Service ====================

/// <summary>
/// Input for creating an answer.
/// </summary>
public class AnswerInput
{
    public string Text { get; set; } = string.Empty;
    public bool IsCorrect { get; set; }
}

/// <summary>
/// Summary of a quiz (for listing).
/// </summary>
public class QuizSummary
{
    public int QuizId { get; set; }
    public string QuizTitle { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int TotalQuestions { get; set; }
    public int? TimeLimitMin { get; set; }
    public DateTime? StartAt { get; set; }
    public DateTime? EndAt { get; set; }
    public string Status { get; set; } = string.Empty;
}

/// <summary>
/// Result from starting an attempt.
/// </summary>
public class StartAttemptResult
{
    public int AttemptId { get; set; }
    public List<QuestionForAttempt> Questions { get; set; } = new();

    /// <summary>
    /// Note: order is NOT stable on refresh if shuffle is enabled.
    /// To make it stable, we would need to store a snapshot of the order,
    /// but schema changes are forbidden.
    /// </summary>
    public string? ShuffleNote { get; set; }
}

/// <summary>
/// Question data for student during attempt.
/// </summary>
public class QuestionForAttempt
{
    public int QuestionId { get; set; }
    public string QuestionText { get; set; } = string.Empty;
    public string QuestionType { get; set; } = string.Empty;
    public decimal Points { get; set; }
    public List<AnswerForAttempt> Answers { get; set; } = new();
}

/// <summary>
/// Answer data for student during attempt.
/// Note: IsCorrect is NOT exposed to student.
/// </summary>
public class AnswerForAttempt
{
    public int AnswerId { get; set; }
    public string AnswerText { get; set; } = string.Empty;
}

/// <summary>
/// Student's answer submission.
/// </summary>
public class AnswerSubmission
{
    public int QuestionId { get; set; }
    public int SelectedAnswerId { get; set; }
}

/// <summary>
/// Result from submitting an attempt.
/// </summary>
public class SubmitAttemptResult
{
    public decimal FinalScore { get; set; }
    public int CorrectCount { get; set; }
    public int TotalQuestions { get; set; }
}
