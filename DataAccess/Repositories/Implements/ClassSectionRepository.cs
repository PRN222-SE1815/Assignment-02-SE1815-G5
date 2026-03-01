using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace DataAccess.Repositories.Implements;

public sealed class ClassSectionRepository : IClassSectionRepository
{
    private readonly SchoolManagementDbContext _context;
    private readonly ILogger<ClassSectionRepository> _logger;

    public ClassSectionRepository(SchoolManagementDbContext context, ILogger<ClassSectionRepository> logger)
    {
        _context = context;
        _logger = logger;
    }

    public Task<ClassSection?> GetClassSectionForUpdateAsync(int classSectionId)
    {
        // TODO: lock at service via transaction isolation.
        return _context.ClassSections
            .AsTracking()
            .SingleOrDefaultAsync(cs => cs.ClassSectionId == classSectionId);
    }

    public Task<ClassSection?> GetClassSectionWithCourseAsync(int classSectionId)
    {
        return _context.ClassSections
            .AsNoTracking()
            .Include(cs => cs.Course)
            .Include(cs => cs.Semester)
            .SingleOrDefaultAsync(cs => cs.ClassSectionId == classSectionId);
    }

    public async Task<bool> IsTeacherAssignedAsync(int teacherUserId, int classSectionId)
    {
        // ClassSections.TeacherId = Teachers.TeacherId = Users.UserId
        return await _context.ClassSections
            .AsNoTracking()
            .AnyAsync(cs => cs.ClassSectionId == classSectionId && cs.TeacherId == teacherUserId);
    }

    public async Task<bool> IsTeacherAssignedToCourseAsync(int teacherUserId, int courseId)
    {
        return await _context.ClassSections
            .AsNoTracking()
            .AnyAsync(cs => cs.CourseId == courseId && cs.TeacherId == teacherUserId);
    }
}
