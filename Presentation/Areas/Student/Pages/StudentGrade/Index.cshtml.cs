using System.Security.Claims;
using BusinessLogic.DTOs.Responses.Gradebook;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enum;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Presentation.Areas.Student.Pages.StudentGrade;

[Authorize(Roles = nameof(UserRole.STUDENT))]
public class IndexModel : PageModel
{
    private readonly IEnrollmentService _enrollmentService;
    private readonly IGradebookService _gradebookService;
    private readonly ILogger<IndexModel> _logger;

    public IndexModel(
        IEnrollmentService enrollmentService,
        IGradebookService gradebookService,
        ILogger<IndexModel> logger)
    {
        _enrollmentService = enrollmentService;
        _gradebookService = gradebookService;
        _logger = logger;
    }

    public List<StudentGradeViewModel> GradeViewModels { get; set; } = [];

    [TempData]
    public string? ErrorMessage { get; set; }

    [BindProperty(SupportsGet = true)]
    public int? SemesterId { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        try
        {
            var coursesPage = await _enrollmentService.GetMyCoursesAsync(userId, SemesterId, 1, 100);
            var viewModels = new List<StudentGradeViewModel>();

            foreach (var course in coursesPage.Items)
            {
                var vm = new StudentGradeViewModel
                {
                    CourseCode = course.CourseCode,
                    CourseName = course.CourseName,
                    SectionCode = course.SectionCode,
                    ClassSectionId = course.ClassSectionId,
                    EnrollmentStatus = course.Status
                };

                var result = await _gradebookService.GetGradebookAsync(
                    userId,
                    nameof(UserRole.STUDENT),
                    course.ClassSectionId);

                if (result.IsSuccess && result.Data is not null)
                {
                    var gb = result.Data;
                    var isViewable = string.Equals(gb.Status, "PUBLISHED", StringComparison.OrdinalIgnoreCase)
                        || string.Equals(gb.Status, "LOCKED", StringComparison.OrdinalIgnoreCase);

                    if (isViewable)
                    {
                        vm.GradebookStatus = gb.Status;
                        vm.GradeItems = gb.GradeItems.ToList();
                        vm.GradeEntries = gb.GradeEntries.ToList();
                        vm.HasGrades = true;
                    }
                }

                viewModels.Add(vm);
            }

            GradeViewModels = viewModels;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "StudentGrade OnGetAsync error");
            ErrorMessage = "An unexpected error occurred.";
        }

        return Page();
    }

    private int GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier);
        return claim is not null && int.TryParse(claim.Value, out var id) ? id : 0;
    }

    public sealed class StudentGradeViewModel
    {
        public string CourseCode { get; set; } = string.Empty;
        public string CourseName { get; set; } = string.Empty;
        public string SectionCode { get; set; } = string.Empty;
        public int ClassSectionId { get; set; }
        public string EnrollmentStatus { get; set; } = string.Empty;
        public string? GradebookStatus { get; set; }
        public bool HasGrades { get; set; }
        public List<GradeItemResponse> GradeItems { get; set; } = [];
        public List<GradeEntryResponse> GradeEntries { get; set; } = [];
    }
}
