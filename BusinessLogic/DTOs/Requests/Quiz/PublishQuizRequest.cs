using System.ComponentModel.DataAnnotations;

namespace BusinessLogic.DTOs.Requests.Quiz;

/// <summary>
/// Request DTO for publishing a quiz.
/// </summary>
public class PublishQuizRequest
{
    [Required]
    public int QuizId { get; set; }

    /// <summary>
    /// Optional: Override/set the start time.
    /// </summary>
    public DateTime? StartAt { get; set; }

    /// <summary>
    /// Optional: Override/set the end time. Must be > StartAt if both provided.
    /// </summary>
    public DateTime? EndAt { get; set; }
}
