using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IClassSectionRepository
{
    Task<ClassSection?> GetClassSectionForUpdateAsync(int classSectionId);
    Task<ClassSection?> GetClassSectionWithCourseAsync(int classSectionId);
    /// <summary>
    /// Check if a teacher (by UserId) is assigned to a specific class section.
    /// </summary>
    Task<bool> IsTeacherAssignedAsync(int teacherUserId, int classSectionId);

    /// <summary>
    /// Check if a teacher (by UserId) is assigned to any class section for a given course.
    /// </summary>
    Task<bool> IsTeacherAssignedToCourseAsync(int teacherUserId, int courseId);
}
