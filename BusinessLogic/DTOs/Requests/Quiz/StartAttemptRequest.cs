using System.ComponentModel.DataAnnotations;

namespace BusinessLogic.DTOs.Requests.Quiz;

/// <summary>
/// Request DTO for starting a quiz attempt.
/// </summary>
public class StartAttemptRequest
{
    [Required]
    public int QuizId { get; set; }
}
