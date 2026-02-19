using System.ComponentModel.DataAnnotations;

namespace BusinessLogic.DTOs.Requests.Quiz;

/// <summary>
/// Request DTO for adding a question to a quiz.
/// </summary>
public class AddQuestionRequest
{
    [Required]
    public int QuizId { get; set; }

    [Required]
    public string QuestionText { get; set; } = string.Empty;

    /// <summary>
    /// Must be "MCQ" or "TRUE_FALSE"
    /// </summary>
    [Required]
    [RegularExpression("^(MCQ|TRUE_FALSE)$", ErrorMessage = "QuestionType must be 'MCQ' or 'TRUE_FALSE'")]
    public string QuestionType { get; set; } = string.Empty;

    /// <summary>
    /// Points for this question. Must be > 0.
    /// </summary>
    [Required]
    [Range(0.01, 100)]
    public decimal Points { get; set; }

    /// <summary>
    /// List of answers. Must have >= 2 answers and exactly 1 correct.
    /// </summary>
    [Required]
    [MinLength(2, ErrorMessage = "At least 2 answers are required")]
    public List<AddAnswerDto> Answers { get; set; } = new();
}
