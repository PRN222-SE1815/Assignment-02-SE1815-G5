using System.ComponentModel.DataAnnotations;

namespace BusinessLogic.DTOs.Requests.Quiz;

/// <summary>
/// DTO for a single answer submission.
/// </summary>
public class SubmitAnswerDto
{
    [Required]
    public int QuestionId { get; set; }

    [Required]
    public int SelectedAnswerId { get; set; }
}
