namespace BusinessLogic.DTOs.Responses.Gradebook;

public sealed class GradeEntryResponse
{
    public int GradeEntryId { get; set; }

    public int GradeItemId { get; set; }

    public int EnrollmentId { get; set; }

    public decimal? Score { get; set; }

    public DateTime UpdatedAt { get; set; }
}
