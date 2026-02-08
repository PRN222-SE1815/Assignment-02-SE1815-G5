using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IEnrollmentRepository
{
    /// <summary>
    /// Get EnrollmentId for a student in a class section with ENROLLED status.
    /// </summary>
    Task<int?> GetEnrolledStudentEnrollmentIdAsync(int studentUserId, int classSectionId);

    /// <summary>
    /// Check if student is enrolled (ENROLLED status) in a class section.
    /// </summary>
    Task<bool> IsStudentEnrolledInClassAsync(int studentUserId, int classSectionId);

    /// <summary>
    /// Get enrollment by ID.
    /// </summary>
    Task<Enrollment?> GetByIdAsync(int enrollmentId);

    /// <summary>
    /// Get StudentId (from Students table, which equals UserId) by EnrollmentId.
    /// </summary>
    Task<int?> GetStudentUserIdByEnrollmentIdAsync(int enrollmentId);
}
