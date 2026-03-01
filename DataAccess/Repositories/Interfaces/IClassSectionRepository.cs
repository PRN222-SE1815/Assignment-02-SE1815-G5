using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IClassSectionRepository
{
    Task<ClassSection?> GetClassSectionForUpdateAsync(int classSectionId);
    Task<ClassSection?> GetClassSectionWithCourseAsync(int classSectionId);
}
