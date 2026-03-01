namespace BusinessLogic.DTOs.Responses.Chat;

public class ChatAttachmentDto
{
    public long AttachmentId { get; set; }
    public long MessageId { get; set; }
    public string FileUrl { get; set; } = null!;
    public string FileType { get; set; } = null!;
    public long? FileSizeBytes { get; set; }
    public DateTime CreatedAt { get; set; }
}
