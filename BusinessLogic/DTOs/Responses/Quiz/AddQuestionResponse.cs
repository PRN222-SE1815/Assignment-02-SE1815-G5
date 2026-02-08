namespace BusinessLogic.DTOs.Responses.Quiz;

/// <summary>
/// Response DTO after adding a question.
/// </summary>
public class AddQuestionResponse
{
    public int QuestionId { get; set; }
    public int QuizId { get; set; }
    public int CurrentQuestionCount { get; set; }
    public int TotalQuestionsRequired { get; set; }
}
