using System.Security.Claims;
using BusinessLogic.DTOs.Responses.Gradebook;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enum;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Presentation.Areas.Admin.Pages.GradebookManagement;

[Authorize(Roles = nameof(UserRole.ADMIN))]
public class IndexModel : PageModel
{
    private readonly IGradebookService _gradebookService;
    private readonly ILogger<IndexModel> _logger;

    public IndexModel(IGradebookService gradebookService, ILogger<IndexModel> logger)
    {
        _gradebookService = gradebookService;
        _logger = logger;
    }

    [BindProperty(SupportsGet = true)]
    public int? SearchClassSectionId { get; set; }

    public GradebookDetailResponse? SearchResult { get; set; }

    [TempData]
    public string? SuccessMessage { get; set; }

    [TempData]
    public string? ErrorMessage { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        var userId = GetUserId();
        if (userId == 0) return RedirectToPage("/Account/Login");

        if (SearchClassSectionId.HasValue && SearchClassSectionId.Value > 0)
        {
            var result = await _gradebookService.GetGradebookAsync(
                userId,
                nameof(UserRole.ADMIN),
                SearchClassSectionId.Value);

            if (result.IsSuccess && result.Data is not null)
            {
                SearchResult = result.Data;
            }
            else
            {
                ErrorMessage = result.Message;
            }
        }

        return Page();
    }

    private int GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier);
        return claim is not null && int.TryParse(claim.Value, out var id) ? id : 0;
    }
}
