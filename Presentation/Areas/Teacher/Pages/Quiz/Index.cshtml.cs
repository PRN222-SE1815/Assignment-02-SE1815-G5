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
public class IndexModel : PageModel
{
    private readonly IQuizService _quizService;
    private readonly ILogger<IndexModel> _logger;

    public IndexModel(IQuizService quizService, ILogger<IndexModel> logger)
    {
        _quizService = quizService;
        _logger = logger;
    }

    /// <summary>Newly created quiz (after POST).</summary>
    public CreateQuizResponse? CreatedQuiz { get; set; }

    public string? SuccessMessage { get; set; }
    public string? ErrorMessage { get; set; }

    [BindProperty(SupportsGet = true)]
    public int? ClassSectionId { get; set; }

    [BindProperty]
    public CreateQuizRequest CreateRequest { get; set; } = new();

    public IActionResult OnGet()
    {
        return Page();
    }

    /// <summary>
    /// POST: Create a draft quiz.
    /// </summary>
    public async Task<IActionResult> OnPostCreateAsync()
    {
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        if (!ModelState.IsValid)
        {
            ErrorMessage = "Please correct the form errors.";
            return Page();
        }

        try
        {
            CreatedQuiz = await _quizService.CreateDraftQuizAsync(
                userId, nameof(UserRole.TEACHER), CreateRequest);

            SuccessMessage = $"Quiz \"{CreatedQuiz.QuizTitle}\" created successfully! Now add questions.";
            ClassSectionId = CreateRequest.ClassSectionId;
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
            _logger.LogError(ex, "Error creating quiz");
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
