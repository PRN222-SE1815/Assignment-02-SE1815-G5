using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implements;

public sealed class ClassSectionRepository : IClassSectionRepository
{
    private readonly SchoolManagementDbContext _context;

    public ClassSectionRepository(SchoolManagementDbContext context)
    {
        _context = context;
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
