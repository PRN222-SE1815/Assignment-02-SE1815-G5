using BusinessObject.Entities;
using BusinessObject.Enum;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace DataAccess.Repositories.Implements;

public sealed class CourseRepository : ICourseRepository
{
    private readonly SchoolManagementDbContext _context;
    private readonly ILogger<CourseRepository> _logger;

    public CourseRepository(SchoolManagementDbContext context, ILogger<CourseRepository> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<bool> CheckPrerequisiteSatisfiedAsync(int studentId, int courseId)
    {
        var prerequisiteIds = await _context.Courses
            .AsNoTracking()
            .Where(c => c.CourseId == courseId)
            .SelectMany(c => c.PrerequisiteCourses.Select(p => p.CourseId))
            .ToListAsync();

        if (prerequisiteIds.Count == 0)
        {
            return true;
        }

        var completedCount = await _context.Enrollments
            .AsNoTracking()
            .Where(e => e.StudentId == studentId
                && e.Status == EnrollmentStatus.COMPLETED.ToString()
                && prerequisiteIds.Contains(e.CourseId))
            .Select(e => e.CourseId)
            .Distinct()
            .CountAsync();

        return completedCount == prerequisiteIds.Count;
    }

    public async Task<IReadOnlyList<Course>> GetPrerequisiteCoursesAsync(int courseId)
    {
        return await _context.Courses
            .AsNoTracking()
            .Where(c => c.CourseId == courseId)
            .SelectMany(c => c.PrerequisiteCourses)
            .OrderBy(c => c.CourseCode)
            .ToListAsync();
    }

    public async Task<IReadOnlyList<Course>> GetMissingPrerequisiteCoursesAsync(int studentId, int courseId)
    {
        var prerequisiteCourses = await _context.Courses
            .AsNoTracking()
            .Where(c => c.CourseId == courseId)
            .SelectMany(c => c.PrerequisiteCourses)
            .ToListAsync();

        if (prerequisiteCourses.Count == 0)
        {
            return [];
        }

        var prerequisiteIds = prerequisiteCourses.Select(c => c.CourseId).ToList();

        var completedCourseIds = await _context.Enrollments
            .AsNoTracking()
            .Where(e => e.StudentId == studentId
                && e.Status == EnrollmentStatus.COMPLETED.ToString()
                && prerequisiteIds.Contains(e.CourseId))
            .Select(e => e.CourseId)
            .Distinct()
            .ToListAsync();

        return prerequisiteCourses
            .Where(c => !completedCourseIds.Contains(c.CourseId))
            .OrderBy(c => c.CourseCode)
            .ToList();
    }
}
