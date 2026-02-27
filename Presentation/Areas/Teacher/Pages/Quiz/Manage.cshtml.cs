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
public class ManageModel : PageModel
{
    private readonly IQuizService _quizService;
    private readonly ILogger<ManageModel> _logger;

    public ManageModel(IQuizService quizService, ILogger<ManageModel> logger)
    {
        _quizService = quizService;
        _logger = logger;
    }

    [BindProperty(SupportsGet = true)]
    public int QuizId { get; set; }

    public string? SuccessMessage { get; set; }
    public string? ErrorMessage { get; set; }

    [BindProperty]
    public DateTime? PublishStartAt { get; set; }

    [BindProperty]
    public DateTime? PublishEndAt { get; set; }

    public IActionResult OnGet(int quizId)
    {
        QuizId = quizId;
        return Page();
    }

    /// <summary>
    /// POST: Publish the quiz (DRAFT -> PUBLISHED).
    /// </summary>
    public async Task<IActionResult> OnPostPublishAsync()
    {
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        try
        {
            var request = new PublishQuizRequest
            {
                QuizId = QuizId,
                StartAt = PublishStartAt,
                EndAt = PublishEndAt
            };

            await _quizService.PublishQuizAsync(userId, nameof(UserRole.TEACHER), request);
            SuccessMessage = "Quiz published successfully! Students can now take it.";
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
            _logger.LogError(ex, "Error publishing Quiz {QuizId}", QuizId);
            ErrorMessage = "An unexpected error occurred.";
        }

        return Page();
    }

    /// <summary>
    /// POST: Close the quiz (PUBLISHED -> CLOSED).
    /// </summary>
    public async Task<IActionResult> OnPostCloseAsync()
    {
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        try
        {
            var request = new CloseQuizRequest { QuizId = QuizId };
            await _quizService.CloseQuizAsync(userId, nameof(UserRole.TEACHER), request);
            SuccessMessage = "Quiz closed successfully. No more attempts will be accepted.";
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
            _logger.LogError(ex, "Error closing Quiz {QuizId}", QuizId);
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
