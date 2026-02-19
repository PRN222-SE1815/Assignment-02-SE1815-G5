namespace BusinessLogic.DTOs.Responses.Quiz;

/// <summary>
/// Answer option for a question (student view - no IsCorrect exposed).
/// </summary>
public class AnswerOptionResponse
{
    public int AnswerId { get; set; }
    public string AnswerText { get; set; } = string.Empty;
}

/// <summary>
/// Question with answers for student during attempt.
/// </summary>
public class QuestionForAttemptResponse
{
    public int QuestionId { get; set; }
    public string QuestionText { get; set; } = string.Empty;
    public string QuestionType { get; set; } = string.Empty;
    public decimal Points { get; set; }
    public List<AnswerOptionResponse> Answers { get; set; } = new();
}

/// <summary>
/// Response DTO after starting an attempt.
/// </summary>
public class StartAttemptResponse
{
    public int AttemptId { get; set; }
    public int QuizId { get; set; }
    public string QuizTitle { get; set; } = string.Empty;
    public int? TimeLimitMin { get; set; }
    public DateTime StartedAt { get; set; }
    public DateTime? EndAt { get; set; }
    public List<QuestionForAttemptResponse> Questions { get; set; } = new();

    /// <summary>
    /// Note about shuffle limitation due to schema constraint.
    /// </summary>
    public string? ShuffleNote { get; set; }
}
