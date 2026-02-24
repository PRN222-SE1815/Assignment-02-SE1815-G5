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

    public async Task<int?> GetEnrolledEnrollmentIdAsync(int studentUserId, int classSectionId)
    {
        // StudentId in Students/Enrollments = UserId in Users
        return await _context.Enrollments
            .AsNoTracking()
            .Where(e => e.StudentId == studentUserId
                        && e.ClassSectionId == classSectionId
                        && e.Status == "ENROLLED")
            .Select(e => (int?)e.EnrollmentId)
            .FirstOrDefaultAsync();
    }

    public async Task<bool> IsStudentEnrolledAsync(int studentUserId, int classSectionId)
    {
        return await _context.Enrollments
            .AsNoTracking()
            .AnyAsync(e => e.StudentId == studentUserId
                           && e.ClassSectionId == classSectionId
                           && e.Status == "ENROLLED");
    }

    public async Task<int?> GetStudentUserIdByEnrollmentIdAsync(int enrollmentId)
    {
        return await _context.Enrollments
            .AsNoTracking()
            .Where(e => e.EnrollmentId == enrollmentId)
            .Select(e => (int?)e.StudentId)
            .FirstOrDefaultAsync();
    }

    public async Task<Enrollment?> GetEnrollmentBySectionAsync(int studentUserId, int classSectionId)
    {
        return await _context.Enrollments
            .AsNoTracking()
            .FirstOrDefaultAsync(e => e.StudentId == studentUserId
                                      && e.ClassSectionId == classSectionId
                                      && e.Status == "ENROLLED");
    }

    public async Task<bool> IsStudentEnrolledInCourseAsync(int studentUserId, int courseId)
    {
        return await _context.Enrollments
            .AsNoTracking()
            .AnyAsync(e => e.StudentId == studentUserId
                           && e.CourseId == courseId
                           && e.Status == "ENROLLED");
    }
}
