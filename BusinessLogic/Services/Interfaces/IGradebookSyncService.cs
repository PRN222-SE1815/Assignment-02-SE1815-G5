using BusinessLogic.DTOs.Requests.Gradebook;
using BusinessLogic.DTOs.Response;

namespace BusinessLogic.Services.Interfaces;

public interface IGradebookSyncService
{
    Task<ServiceResult<bool>> SyncQuizAttemptScoreAsync(SyncQuizScoreRequest request, CancellationToken ct = default);
}
