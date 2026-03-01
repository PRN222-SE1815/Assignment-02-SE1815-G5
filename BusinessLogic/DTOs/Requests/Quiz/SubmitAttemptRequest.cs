using System.ComponentModel.DataAnnotations;

namespace BusinessLogic.DTOs.Requests.Quiz;

/// <summary>
/// Request DTO for submitting a quiz attempt.
/// </summary>
public class SubmitAttemptRequest
{
    [Required]
    public int AttemptId { get; set; }

    /// <summary>
    /// List of answers submitted by the student.
    /// </summary>
    [Required]
    public List<SubmitAnswerDto> Answers { get; set; } = new();
}
