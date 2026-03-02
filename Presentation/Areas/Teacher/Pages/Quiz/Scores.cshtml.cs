using System.Security.Claims;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Logging;

namespace Presentation.Areas.Teacher.Pages.Quiz;

[Authorize(Roles = "TEACHER")]
public class ScoresModel : PageModel
{
    private readonly IQuizService _quizService;
    private readonly ILogger<ScoresModel> _logger;

    public ScoresModel(IQuizService quizService, ILogger<ScoresModel> logger)
    {
        _quizService = quizService;
        _logger = logger;
    }

    public List<QuizAttempt> Attempts { get; set; } = new();
    public string? QuizTitle { get; set; }
    public string? ClassSectionCode { get; set; }
    public int TotalQuestions { get; set; }
    public string? ErrorMessage { get; set; }

    // Statistics
    public int TotalAttempts { get; set; }
    public int GradedCount { get; set; }
    public decimal? AverageScore { get; set; }
    public decimal? HighestScore { get; set; }
    public decimal? LowestScore { get; set; }

    public async Task<IActionResult> OnGetAsync(int quizId)
    {
        try
        {
            var userId = GetUserId();
            if (userId == 0) return RedirectToPage("/Auth/Login", new { area = "" });

            Attempts = await _quizService.GetQuizAttemptsAsync(userId, "TEACHER", quizId);

            if (Attempts.Any())
            {
                var firstAttempt = Attempts.First();
                QuizTitle = firstAttempt.Quiz?.QuizTitle;
                TotalQuestions = firstAttempt.Quiz?.TotalQuestions ?? 0;
                ClassSectionCode = firstAttempt.Quiz?.ClassSection?.SectionCode;
            }

            // Compute statistics
            TotalAttempts = Attempts.Count;
            var graded = Attempts.Where(a => a.Status == "GRADED" && a.Score.HasValue).ToList();
            GradedCount = graded.Count;

            if (graded.Any())
            {
                var scores = graded.Select(a => a.Score!.Value).ToList();
                AverageScore = Math.Round(scores.Average(), 2);
                HighestScore = scores.Max();
                LowestScore = scores.Min();
            }
        }
        catch (ForbiddenException ex)
        {
            _logger.LogWarning(ex, "Forbidden access to quiz scores");
            ErrorMessage = "You do not have permission to view scores for this quiz.";
            Attempts = new List<QuizAttempt>();
        }
        catch (NotFoundException ex)
        {
            _logger.LogWarning(ex, "Quiz not found for scores");
            ErrorMessage = "Quiz not found.";
            Attempts = new List<QuizAttempt>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching quiz attempts");
            ErrorMessage = "An error occurred while loading the scores.";
            Attempts = new List<QuizAttempt>();
        }

        return Page();
    }

    private int GetUserId()
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return int.TryParse(claim, out var id) ? id : 0;
    }
}
