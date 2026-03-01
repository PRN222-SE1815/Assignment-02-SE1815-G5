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
}
