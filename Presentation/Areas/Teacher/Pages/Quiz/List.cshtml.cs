using System.Security.Claims;
using BusinessLogic.DTOs.Responses.Quiz;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enum;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Presentation.Areas.Teacher.Pages.Quiz;

[Authorize(Roles = nameof(UserRole.TEACHER))]
public class ListModel : PageModel
{
    private readonly IQuizService _quizService;
    private readonly ILogger<ListModel> _logger;

    public ListModel(IQuizService quizService, ILogger<ListModel> logger)
    {
        _quizService = quizService;
        _logger = logger;
    }

    public List<QuizSummaryResponse> Quizzes { get; set; } = new();
    public string? ErrorMessage { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? StatusFilter { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        try
        {
            Quizzes = await _quizService.ListQuizzesForTeacherAsync(userId, nameof(UserRole.TEACHER));

            // Apply status filter if specified
            if (!string.IsNullOrEmpty(StatusFilter))
            {
                Quizzes = Quizzes.Where(q => q.Status == StatusFilter).ToList();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error loading quizzes for teacher");
            ErrorMessage = "An unexpected error occurred while loading quizzes.";
        }

        return Page();
    }

    private int GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier);
        return claim is not null && int.TryParse(claim.Value, out var id) ? id : 0;
    }
}
