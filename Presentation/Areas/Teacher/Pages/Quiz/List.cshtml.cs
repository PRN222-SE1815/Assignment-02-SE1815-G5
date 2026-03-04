using System.Security.Claims;
using BusinessLogic.DTOs.Responses.Quiz;
using BusinessLogic.Exceptions;
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
    public IReadOnlyList<ClassSectionSummary> ClassSections { get; set; } = new List<ClassSectionSummary>();
    public string? ErrorMessage { get; set; }

    [TempData]
    public string? SuccessMessage { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? StatusFilter { get; set; }

    [BindProperty(SupportsGet = true)]
    public int? ClassSectionFilter { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        try
        {
            ClassSections = await _quizService.GetTeacherClassSectionsForQuizFilterAsync(userId, nameof(UserRole.TEACHER));
            Quizzes = await _quizService.ListQuizzesForTeacherAsync(userId, nameof(UserRole.TEACHER));

            if (ClassSectionFilter.HasValue)
            {
                Quizzes = Quizzes.Where(q => q.ClassSectionId == ClassSectionFilter.Value).ToList();
            }

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

    public async Task<IActionResult> OnPostDeleteAsync(int quizId)
    {
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        try
        {
            await _quizService.DeleteQuizAsync(userId, nameof(UserRole.TEACHER), quizId);
            SuccessMessage = "Quiz deleted successfully.";
        }
        catch (ForbiddenException ex)
        {
            ErrorMessage = ex.Message;
        }
        catch (NotFoundException)
        {
            ErrorMessage = "Quiz not found.";
        }
        catch (BusinessException ex)
        {
            ErrorMessage = ex.Message;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting quiz {QuizId}", quizId);
            ErrorMessage = "An unexpected error occurred while deleting the quiz.";
        }

        return RedirectToPage(new { StatusFilter, ClassSectionFilter });
    }

    private int GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier);
        return claim is not null && int.TryParse(claim.Value, out var id) ? id : 0;
    }
}
