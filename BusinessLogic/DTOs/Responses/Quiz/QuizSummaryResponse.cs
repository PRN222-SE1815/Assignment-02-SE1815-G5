namespace BusinessLogic.DTOs.Responses.Quiz;

/// <summary>
/// Quiz summary for listing.
/// </summary>
public class QuizSummaryResponse
{
    public int QuizId { get; set; }
    public string QuizTitle { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int TotalQuestions { get; set; }
    public int? TimeLimitMin { get; set; }
    public DateTime? StartAt { get; set; }
    public DateTime? EndAt { get; set; }
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}
