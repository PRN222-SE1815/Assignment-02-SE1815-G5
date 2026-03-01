using System.ComponentModel.DataAnnotations;

namespace BusinessLogic.DTOs.Requests.Quiz;

/// <summary>
/// DTO for a single answer when adding a question.
/// </summary>
public class AddAnswerDto
{
    [Required]
    [StringLength(1000, MinimumLength = 1)]
    public string AnswerText { get; set; } = string.Empty;

    public bool IsCorrect { get; set; }
}
