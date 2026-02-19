using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IEnrollmentRepository
{
    /// <summary>
    /// Get EnrollmentId for a student in a class section with ENROLLED status.
    /// Returns null if not enrolled.
    /// </summary>
    Task<int?> GetEnrolledEnrollmentIdAsync(int studentUserId, int classSectionId);

    /// <summary>
    /// Check if student is enrolled (ENROLLED status) in a class section.
    /// </summary>
    Task<bool> IsStudentEnrolledAsync(int studentUserId, int classSectionId);

    /// <summary>
    /// Get StudentId (UserId) by EnrollmentId.
    /// </summary>
    Task<int?> GetStudentUserIdByEnrollmentIdAsync(int enrollmentId);
}
