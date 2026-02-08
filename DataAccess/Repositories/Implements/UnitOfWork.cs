using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore.Storage;

namespace DataAccess.Repositories.Implements;

public class UnitOfWork : IUnitOfWork
{
    private readonly SchoolManagementDbContext _context;
    private IQuizRepository? _quizRepository;
    private IEnrollmentRepository? _enrollmentRepository;
    private bool _disposed;

    public UnitOfWork(SchoolManagementDbContext context)
    {
        _context = context;
    }

    public IQuizRepository Quizzes => _quizRepository ??= new QuizRepository(_context);

    public IEnrollmentRepository Enrollments => _enrollmentRepository ??= new EnrollmentRepository(_context);

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task<IDbContextTransaction> BeginTransactionAsync(CancellationToken cancellationToken = default)
    {
        return await _context.Database.BeginTransactionAsync(cancellationToken);
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed && disposing)
        {
            _context.Dispose();
        }
        _disposed = true;
    }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }
}
