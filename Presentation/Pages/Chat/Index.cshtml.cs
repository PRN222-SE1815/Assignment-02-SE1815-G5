using System.Security.Claims;
using BusinessLogic.DTOs.Response;
using BusinessLogic.DTOs.Responses.Chat;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.Hosting;
using BusinessLogic.DTOs.Requests.Chat;

namespace Presentation.Pages.Chat;

[Authorize]
public class IndexModel : PageModel
{
    private readonly IChatService _chatService;
    private readonly ILogger<IndexModel> _logger;
    private readonly IWebHostEnvironment _env;

    public IndexModel(IChatService chatService, ILogger<IndexModel> logger, IWebHostEnvironment env)
    {
        _chatService = chatService;
        _logger = logger;
        _env = env;
    }

    /// <summary>All chat rooms the current user belongs to.</summary>
    public List<ChatRoomDto> Rooms { get; set; } = new();

    /// <summary>Messages for the currently selected room (server-rendered initial load).</summary>
    public PagedResult<ChatMessageDto> Messages { get; set; } = new()
    {
        Page = 1,
        PageSize = 20,
        TotalCount = 0,
        Items = Array.Empty<ChatMessageDto>()
    };

    /// <summary>The currently selected room (if any).</summary>
    public ChatRoomDto? SelectedRoom { get; set; }

    /// <summary>Current user's ID from claims.</summary>
    public int CurrentUserId { get; set; }

    public async Task<IActionResult> OnGetAsync(int? roomId)
    {
        CurrentUserId = GetUserId();

        if (CurrentUserId == 0)
            return RedirectToPage("/Account/Login");

        Rooms = await _chatService.GetMyRoomsAsync(CurrentUserId);

        if (roomId.HasValue)
        {
            SelectedRoom = await _chatService.GetRoomAsync(roomId.Value, CurrentUserId);
            if (SelectedRoom is not null)
            {
                Messages = await _chatService.GetRoomMessagesAsync(roomId.Value, CurrentUserId, null);
            }
        }
        else if (Rooms.Count > 0)
        {
            // Auto-select the first room
            SelectedRoom = Rooms[0];
            Messages = await _chatService.GetRoomMessagesAsync(SelectedRoom.RoomId, CurrentUserId, null);
        }

        return Page();
    }

    /// <summary>AJAX endpoint: get messages for a room (cursor-based paging).</summary>
    public async Task<IActionResult> OnGetMessagesAsync(int roomId, long? beforeMessageId)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var messages = await _chatService.GetRoomMessagesAsync(roomId, userId, beforeMessageId);
        return new JsonResult(messages);
    }

    /// <summary>AJAX endpoint: search users for new DM / group creation.</summary>
    public async Task<IActionResult> OnGetSearchUsersAsync(string? search)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var users = await _chatService.GetAvailableUsersForChatAsync(userId, search);
        return new JsonResult(users);
    }

    [HttpPost]
    [IgnoreAntiforgeryToken]
    public async Task<IActionResult> OnPostUploadFilesAsync(IFormFileCollection files)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        if (files is null || files.Count == 0)
            return BadRequest("No files found.");

        var uploadPath = Path.Combine(_env.WebRootPath, "uploads", "chat");
        if (!Directory.Exists(uploadPath))
            Directory.CreateDirectory(uploadPath);

        var result = new List<ChatAttachmentInput>();

        foreach (var file in files)
        {
            if (file.Length == 0) continue;

            // Generate a unique filename
            var ext = Path.GetExtension(file.FileName);
            var newFileName = $"{Guid.NewGuid()}{ext}";
            var filePath = Path.Combine(uploadPath, newFileName);

            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            result.Add(new ChatAttachmentInput
            {
                FileUrl = $"/uploads/chat/{newFileName}",
                FileType = Path.GetFileName(file.FileName), // Store original name as type or you could just store extension
                FileSizeBytes = file.Length
            });
        }

        return new JsonResult(result);
    }

    private int GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier);
        return claim is not null && int.TryParse(claim.Value, out var id) ? id : 0;
    }
}
