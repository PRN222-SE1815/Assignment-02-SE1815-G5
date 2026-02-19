using System.ComponentModel.DataAnnotations;

namespace BusinessLogic.DTOs.Requests.Quiz;

/// <summary>
/// Request DTO for creating a draft quiz.
/// </summary>
public class CreateQuizRequest
{
    [Required]
    public int ClassSectionId { get; set; }

    [Required]
    [StringLength(200, MinimumLength = 1)]
    public string QuizTitle { get; set; } = string.Empty;

    public string? Description { get; set; }

    /// <summary>
    /// Must be one of: 10, 20, 30
    /// </summary>
    [Required]
    [Range(10, 30)]
    public int TotalQuestions { get; set; }

    [Range(1, 480)]
    public int? TimeLimitMin { get; set; }

    public bool ShuffleQuestions { get; set; }

    public bool ShuffleAnswers { get; set; }

    public DateTime? StartAt { get; set; }

    public DateTime? EndAt { get; set; }
}
