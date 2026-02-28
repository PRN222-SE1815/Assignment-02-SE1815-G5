using System.Security.Claims;
using BusinessLogic.DTOs.Requests.Quiz;
using BusinessLogic.DTOs.Responses.Quiz;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enum;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Presentation.Areas.Student.Pages.Quiz;

[Authorize(Roles = nameof(UserRole.STUDENT))]
public class AttemptModel : PageModel
{
    private readonly IQuizService _quizService;
    private readonly ILogger<AttemptModel> _logger;

    public AttemptModel(IQuizService quizService, ILogger<AttemptModel> logger)
    {
        _quizService = quizService;
        _logger = logger;
    }

    /// <summary>Attempt data after starting (questions, answers, timer info).</summary>
    public StartAttemptResponse? AttemptData { get; set; }

    /// <summary>Submission result after POST.</summary>
    public SubmitAttemptResponse? Result { get; set; }

    [BindProperty(SupportsGet = true)]
    public int QuizId { get; set; }

    public string? ErrorMessage { get; set; }
    public string? ErrorCode { get; set; }

    /// <summary>Bound form model for submitted answers.</summary>
    [BindProperty]
    public int AttemptId { get; set; }

    [BindProperty]
    public List<AnswerSubmission> SubmittedAnswers { get; set; } = new();

    /// <summary>
    /// GET: Start a new quiz attempt.
    /// </summary>
    public async Task<IActionResult> OnGetAsync(int quizId)
    {
        QuizId = quizId;
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        try
        {
            var request = new StartAttemptRequest { QuizId = quizId };
            AttemptData = await _quizService.StartAttemptAsync(
                userId, nameof(UserRole.STUDENT), request, DateTime.UtcNow);
        }
        catch (ConflictException ex)
        {
            ErrorMessage = ex.Message;
            ErrorCode = "ALREADY_ATTEMPTED";
        }
        catch (ForbiddenException ex)
        {
            ErrorMessage = ex.Message;
            ErrorCode = "FORBIDDEN";
        }
        catch (NotFoundException ex)
        {
            ErrorMessage = ex.Message;
            ErrorCode = "NOT_FOUND";
        }
        catch (BusinessException ex)
        {
            ErrorMessage = ex.Message;
            ErrorCode = ex.ErrorCode;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error starting attempt for Quiz {QuizId}", quizId);
            ErrorMessage = "An unexpected error occurred. Please try again.";
        }

        return Page();
    }

    /// <summary>
    /// POST: Submit quiz answers.
    /// </summary>
    public async Task<IActionResult> OnPostAsync()
    {
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        try
        {
            var submitRequest = new SubmitAttemptRequest
            {
                AttemptId = AttemptId,
                Answers = SubmittedAnswers.Select(a => new SubmitAnswerDto
                {
                    QuestionId = a.QuestionId,
                    SelectedAnswerId = a.SelectedAnswerId
                }).ToList()
            };

            Result = await _quizService.SubmitAttemptAsync(
                userId, nameof(UserRole.STUDENT), submitRequest, DateTime.UtcNow);
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
            _logger.LogError(ex, "Error submitting attempt {AttemptId}", AttemptId);
            ErrorMessage = "An unexpected error occurred while submitting your quiz.";
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
/// Helper class for model binding individual answer submissions from the form.
/// </summary>
public class AnswerSubmission
{
    public int QuestionId { get; set; }
    public int SelectedAnswerId { get; set; }
}
