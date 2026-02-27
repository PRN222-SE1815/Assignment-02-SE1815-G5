using System.Security.Claims;
using BusinessLogic.DTOs.Responses.Quiz;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enum;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Presentation.Areas.Student.Pages.Quiz;

[Authorize(Roles = nameof(UserRole.STUDENT))]
public class IndexModel : PageModel
{
    private readonly IQuizService _quizService;
    private readonly ILogger<IndexModel> _logger;

    public IndexModel(IQuizService quizService, ILogger<IndexModel> logger)
    {
        _quizService = quizService;
        _logger = logger;
    }

    public List<QuizSummaryResponse> Quizzes { get; set; } = new();

    [BindProperty(SupportsGet = true)]
    public int ClassSectionId { get; set; }

    public string? ErrorMessage { get; set; }

    public async Task<IActionResult> OnGetAsync(int classSectionId)
    {
        ClassSectionId = classSectionId;

        if (classSectionId <= 0)
        {
            ErrorMessage = "Please provide a valid class section.";
            return Page();
        }

        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        try
        {
            Quizzes = await _quizService.ListPublishedQuizzesForClassAsync(
                userId, nameof(UserRole.STUDENT), classSectionId);
        }
        catch (BusinessLogic.Exceptions.ForbiddenException ex)
        {
            ErrorMessage = ex.Message;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error loading quizzes for ClassSection {ClassSectionId}", classSectionId);
            ErrorMessage = "An error occurred while loading quizzes.";
        }

        return Page();
    }

    private int GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier);
        return claim is not null && int.TryParse(claim.Value, out var id) ? id : 0;
    }
}
