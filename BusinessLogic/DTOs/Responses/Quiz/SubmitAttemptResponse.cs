namespace BusinessLogic.DTOs.Responses.Quiz;

/// <summary>
/// Response DTO after submitting an attempt.
/// </summary>
public class SubmitAttemptResponse
{
    public int AttemptId { get; set; }
    public decimal Score { get; set; }
    public int CorrectCount { get; set; }
    public int TotalCount { get; set; }
    public DateTime SubmittedAt { get; set; }
    public string? WarningMessage { get; set; }
}
