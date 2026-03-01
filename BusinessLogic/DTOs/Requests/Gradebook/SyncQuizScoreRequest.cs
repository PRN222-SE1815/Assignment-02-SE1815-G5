namespace BusinessLogic.DTOs.Requests.Gradebook;

public sealed class SyncQuizScoreRequest
{
    public int AttemptId { get; set; }

    public int? ActorUserId { get; set; }

    public string? Reason { get; set; }
}
