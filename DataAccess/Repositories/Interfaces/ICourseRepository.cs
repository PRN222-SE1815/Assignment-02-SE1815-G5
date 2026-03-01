using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface ICourseRepository
{
    Task<bool> CheckPrerequisiteSatisfiedAsync(int studentId, int courseId);
    Task<IReadOnlyList<Course>> GetPrerequisiteCoursesAsync(int courseId);
    Task<IReadOnlyList<Course>> GetMissingPrerequisiteCoursesAsync(int studentId, int courseId);
}
