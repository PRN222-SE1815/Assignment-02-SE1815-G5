using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implements;

public class EnrollmentRepository : IEnrollmentRepository
{
    private readonly SchoolManagementDbContext _context;

    public EnrollmentRepository(SchoolManagementDbContext context)
    {
        _context = context;
    }

    public async Task<int?> GetEnrolledStudentEnrollmentIdAsync(int studentUserId, int classSectionId)
    {
        // StudentId in Students table = UserId in Users table
        return await _context.Enrollments
            .AsNoTracking()
            .Where(e => e.StudentId == studentUserId
                        && e.ClassSectionId == classSectionId
                        && e.Status == "ENROLLED")
            .Select(e => (int?)e.EnrollmentId)
            .FirstOrDefaultAsync();
    }

    public async Task<bool> IsStudentEnrolledInClassAsync(int studentUserId, int classSectionId)
    {
        return await _context.Enrollments
            .AsNoTracking()
            .AnyAsync(e => e.StudentId == studentUserId
                           && e.ClassSectionId == classSectionId
                           && e.Status == "ENROLLED");
    }

    public async Task<Enrollment?> GetByIdAsync(int enrollmentId)
    {
        return await _context.Enrollments
            .AsNoTracking()
            .FirstOrDefaultAsync(e => e.EnrollmentId == enrollmentId);
    }

    public async Task<int?> GetStudentUserIdByEnrollmentIdAsync(int enrollmentId)
    {
        // StudentId in Enrollments = UserId (since StudentId PK/FK to Users)
        return await _context.Enrollments
            .AsNoTracking()
            .Where(e => e.EnrollmentId == enrollmentId)
            .Select(e => (int?)e.StudentId)
            .FirstOrDefaultAsync();
    }
}
