using System.Security.Claims;
using BusinessLogic.DTOs.Requests.Quiz;
using BusinessLogic.DTOs.Responses.Quiz;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enum;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Presentation.Areas.Teacher.Pages.Quiz;

[Authorize(Roles = nameof(UserRole.TEACHER))]
public class QuestionsModel : PageModel
{
    private readonly IQuizService _quizService;
    private readonly ILogger<QuestionsModel> _logger;

    public QuestionsModel(IQuizService quizService, ILogger<QuestionsModel> logger)
    {
        _quizService = quizService;
        _logger = logger;
    }

    [BindProperty(SupportsGet = true)]
    public int QuizId { get; set; }

    public AddQuestionResponse? LastAdded { get; set; }
    public string? SuccessMessage { get; set; }
    public string? ErrorMessage { get; set; }

    [BindProperty]
    public AddQuestionRequest AddRequest { get; set; } = new();

    /// <summary>Form model for answers. We bind a fixed set of answer slots.</summary>
    [BindProperty]
    public List<AnswerInput> AnswerInputs { get; set; } = new()
    {
        new(), new(), new(), new()
    };

    public IActionResult OnGet(int quizId)
    {
        QuizId = quizId;
        AddRequest.QuizId = quizId;
        return Page();
    }

    /// <summary>
    /// POST: Add a question with answers to the quiz.
    /// </summary>
    public async Task<IActionResult> OnPostAsync()
    {
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        // Build the request from form data
        AddRequest.QuizId = QuizId;
        AddRequest.Answers = AnswerInputs
            .Where(a => !string.IsNullOrWhiteSpace(a.AnswerText))
            .Select(a => new AddAnswerDto
            {
                AnswerText = a.AnswerText.Trim(),
                IsCorrect = a.IsCorrect
            })
            .ToList();

        if (AddRequest.Answers.Count < 2)
        {
            ErrorMessage = "At least 2 answers are required.";
            return Page();
        }

        if (AddRequest.Answers.Count(a => a.IsCorrect) != 1)
        {
            ErrorMessage = "Exactly one answer must be marked as correct.";
            return Page();
        }

        try
        {
            LastAdded = await _quizService.AddQuestionAsync(
                userId, nameof(UserRole.TEACHER), AddRequest);

            SuccessMessage = $"Question added! ({LastAdded.CurrentQuestionCount}/{LastAdded.TotalQuestionsRequired})";

            // Reset form for next question
            AddRequest = new AddQuestionRequest { QuizId = QuizId };
            AnswerInputs = new List<AnswerInput> { new(), new(), new(), new() };
            ModelState.Clear();
        }
        catch (ForbiddenException ex)
        {
            ErrorMessage = ex.Message;
        }
        catch (NotFoundException ex)
        {
            ErrorMessage = ex.Message;
        }
        catch (BusinessException ex)
        {
            ErrorMessage = ex.Message;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding question to Quiz {QuizId}", QuizId);
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

/// <summary>
/// Form input model for a single answer option.
/// </summary>
public class AnswerInput
{
    public string AnswerText { get; set; } = string.Empty;
    public bool IsCorrect { get; set; }
}
