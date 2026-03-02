using System.Security.Claims;
using BusinessLogic.DTOs.Responses.Quiz;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enum;
using DataAccess.Repositories.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Presentation.Areas.Teacher.Pages.Quiz;

[Authorize(Roles = nameof(UserRole.TEACHER))]
public class ListModel : PageModel
{
    private readonly IQuizService _quizService;
    private readonly IClassSectionRepository _classSectionRepository;
    private readonly ILogger<ListModel> _logger;

    public ListModel(IQuizService quizService, IClassSectionRepository classSectionRepository, ILogger<ListModel> logger)
    {
        _quizService = quizService;
        _classSectionRepository = classSectionRepository;
        _logger = logger;
    }

    public List<QuizSummaryResponse> Quizzes { get; set; } = new();
    public IReadOnlyList<ClassSection> ClassSections { get; set; } = new List<ClassSection>();
    public string? ErrorMessage { get; set; }

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
            // Load class sections for dropdown
            ClassSections = await _classSectionRepository.GetByTeacherIdAsync(userId);

            // Load all quizzes
            Quizzes = await _quizService.ListQuizzesForTeacherAsync(userId, nameof(UserRole.TEACHER));

            // Apply class section filter
            if (ClassSectionFilter.HasValue)
            {
                Quizzes = Quizzes.Where(q => q.ClassSectionId == ClassSectionFilter.Value).ToList();
            }

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
