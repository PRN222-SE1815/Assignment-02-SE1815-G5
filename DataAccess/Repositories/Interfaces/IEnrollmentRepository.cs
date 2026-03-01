using System;
using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IEnrollmentRepository
{
    Task<Enrollment?> GetExistingEnrollmentAsync(int studentId, int classSectionId, int semesterId);
    Task<bool> HasTimeConflictAsync(int studentId, int semesterId, DateTime startAt, DateTime endAt);
    Task<int> GetCurrentCreditsAsync(int studentId, int semesterId);
    Task AddEnrollmentAsync(Enrollment entity);
    Task<(IReadOnlyList<Enrollment> Items, int TotalCount)> GetStudentEnrollmentsAsync(
        int studentId,
        int? semesterId,
        int page,
        int pageSize);
}
