using Microsoft.EntityFrameworkCore.Storage;

namespace DataAccess.Repositories.Interfaces;

public interface IUnitOfWork : IDisposable
{
    IQuizRepository Quizzes { get; }
    IEnrollmentRepository Enrollments { get; }

    /// <summary>
    /// Save all changes to database.
    /// </summary>
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Begin a database transaction.
    /// </summary>
    Task<IDbContextTransaction> BeginTransactionAsync(CancellationToken cancellationToken = default);
}
