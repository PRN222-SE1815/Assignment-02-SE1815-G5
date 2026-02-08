using System.ComponentModel.DataAnnotations;

namespace BusinessLogic.DTOs.Requests.Quiz;

/// <summary>
/// Request DTO for closing a quiz.
/// </summary>
public class CloseQuizRequest
{
    [Required]
    public int QuizId { get; set; }
}
