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
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        try
        {
            if (classSectionId <= 0)
            {
                // Fetch all quizzes across all enrolled class sections
                Quizzes = await _quizService.ListAllPublishedQuizzesForStudentAsync(
                    userId, nameof(UserRole.STUDENT));
            }
            else
            {
                // Fetch quizzes for a specific class section
                Quizzes = await _quizService.ListPublishedQuizzesForClassAsync(
                    userId, nameof(UserRole.STUDENT), classSectionId);
            }
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
