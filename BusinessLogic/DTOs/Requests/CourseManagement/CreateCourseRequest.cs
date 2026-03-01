namespace BusinessLogic.DTOs.Requests.CourseManagement;

public sealed class CreateCourseRequest
{
    public string CourseCode { get; set; } = string.Empty;
    public string CourseName { get; set; } = string.Empty;
    public int Credits { get; set; }
    public string? Description { get; set; }
    public string? ContentHtml { get; set; }
    public string? LearningPathJson { get; set; }
    public bool IsActive { get; set; } = true;
}
