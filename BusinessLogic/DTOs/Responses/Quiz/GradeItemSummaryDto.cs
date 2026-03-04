namespace BusinessLogic.DTOs.Responses.Quiz;

public sealed class GradeItemSummaryDto
{
    public int GradeItemId { get; set; }
    public string ItemName { get; set; } = string.Empty;
    public string MaxScore { get; set; } = string.Empty;
    public string? Weight { get; set; }
}
