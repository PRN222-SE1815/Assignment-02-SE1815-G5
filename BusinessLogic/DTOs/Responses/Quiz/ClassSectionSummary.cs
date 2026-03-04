namespace BusinessLogic.DTOs.Responses.Quiz;

/// <summary>
/// Minimal class section info for quiz filter dropdown.
/// </summary>
public class ClassSectionSummary
{
    public int ClassSectionId { get; set; }
    public string SectionCode { get; set; } = string.Empty;
    public string CourseCode { get; set; } = string.Empty;
}
