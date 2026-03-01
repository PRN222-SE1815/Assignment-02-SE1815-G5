using System.Security.Claims;
using BusinessLogic.DTOs.Responses.Gradebook;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enum;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Presentation.Areas.Teacher.Pages.MyClasses;

[Authorize(Roles = nameof(UserRole.TEACHER))]
public class IndexModel : PageModel
{
    private readonly IGradebookService _gradebookService;
    private readonly ILogger<IndexModel> _logger;

    public IndexModel(IGradebookService gradebookService, ILogger<IndexModel> logger)
    {
        _gradebookService = gradebookService;
        _logger = logger;
    }

    public IReadOnlyList<TeacherClassSectionDto> ClassSections { get; set; } = [];

    [TempData]
    public string? ErrorMessage { get; set; }

    public async Task<IActionResult> OnGetAsync(CancellationToken ct)
    {
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        var result = await _gradebookService.GetTeacherClassSectionsAsync(
            userId,
            nameof(UserRole.TEACHER),
            ct);

        if (result.IsSuccess && result.Data is not null)
        {
            ClassSections = result.Data;
        }
        else
        {
            ErrorMessage = result.Message;
        }

        return Page();
    }

    private int GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier);
        return claim is not null && int.TryParse(claim.Value, out var id) ? id : 0;
    }
}
