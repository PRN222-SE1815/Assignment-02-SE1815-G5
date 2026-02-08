namespace BusinessLogic.DTOs.Responses.Quiz;

/// <summary>
/// Response DTO after creating a quiz.
/// </summary>
public class CreateQuizResponse
{
    public int QuizId { get; set; }
    public string QuizTitle { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
}
