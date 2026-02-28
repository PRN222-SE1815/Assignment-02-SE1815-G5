using System.Security.Claims;
using BusinessLogic.DTOs.Requests.Quiz;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enum;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Presentation.Areas.Teacher.Pages.Quiz;

[Authorize(Roles = nameof(UserRole.TEACHER))]
public class EditQuestionModel : PageModel
{
    private readonly IQuizService _quizService;
    private readonly ILogger<EditQuestionModel> _logger;

    public EditQuestionModel(IQuizService quizService, ILogger<EditQuestionModel> logger)
    {
        _quizService = quizService;
        _logger = logger;
    }

    [BindProperty(SupportsGet = true)]
    public int QuestionId { get; set; }

    [BindProperty(SupportsGet = true)]
    public int QuizId { get; set; }

    [BindProperty]
    public string QuestionText { get; set; } = "";

    [BindProperty]
    public string QuestionType { get; set; } = "MCQ";

    [BindProperty]
    public decimal Points { get; set; } = 1;

    [BindProperty]
    public List<AnswerInput> AnswerInputs { get; set; } = new();

    public string? SuccessMessage { get; set; }
    public string? ErrorMessage { get; set; }

    public class AnswerInput
    {
        public string AnswerText { get; set; } = "";
        public bool IsCorrect { get; set; }
    }

    public async Task<IActionResult> OnGetAsync(int questionId, int quizId)
    {
        QuestionId = questionId;
        QuizId = quizId;

        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        try
        {
            var questions = await _quizService.GetQuizQuestionsAsync(userId, nameof(UserRole.TEACHER), quizId);
            var question = questions.FirstOrDefault(q => q.QuestionId == questionId);

            if (question == null)
            {
                ErrorMessage = "Question not found.";
                return Page();
            }

            QuestionText = question.QuestionText;
            QuestionType = question.QuestionType;
            Points = question.Points;
            AnswerInputs = question.QuizAnswers.Select(a => new AnswerInput
            {
                AnswerText = a.AnswerText,
                IsCorrect = a.IsCorrect
            }).ToList();

            // Ensure at least 4 answer slots
            while (AnswerInputs.Count < 4) AnswerInputs.Add(new AnswerInput());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error loading question {QuestionId}", questionId);
            ErrorMessage = "Could not load question data.";
        }

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        try
        {
            var answers = AnswerInputs
                .Where(a => !string.IsNullOrWhiteSpace(a.AnswerText))
                .Select(a => new AddAnswerDto { AnswerText = a.AnswerText, IsCorrect = a.IsCorrect })
                .ToList();

            var request = new AddQuestionRequest
            {
                QuizId = QuizId,
                QuestionText = QuestionText,
                QuestionType = QuestionType,
                Points = Points,
                Answers = answers
            };

            await _quizService.UpdateQuestionAsync(userId, nameof(UserRole.TEACHER), QuestionId, request);

            TempData["SuccessMessage"] = "Question updated successfully!";
            return RedirectToPage("/Quiz/Manage", new { area = "Teacher", quizId = QuizId });
        }
        catch (ForbiddenException ex) { ErrorMessage = ex.Message; }
        catch (NotFoundException ex) { ErrorMessage = ex.Message; }
        catch (BusinessException ex) { ErrorMessage = ex.Message; }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating question {QuestionId}", QuestionId);
            ErrorMessage = "An unexpected error occurred.";
        }

        return Page();
    }

    private int GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier);
        return claim is not null && int.TryParse(claim.Value, out var id) ? id : 0;
    }
}
