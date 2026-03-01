using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace DataAccess.Repositories.Implements;

public sealed class TuitionFeeRepository : ITuitionFeeRepository
{
    private readonly SchoolManagementDbContext _context;
    private readonly ILogger<TuitionFeeRepository> _logger;

    public TuitionFeeRepository(SchoolManagementDbContext context, ILogger<TuitionFeeRepository> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<TuitionFee?> GetOrCreateTuitionFeeAsync(int studentId, int semesterId, decimal rate)
    {
        try
        {
            var fee = await _context.TuitionFees
                .SingleOrDefaultAsync(tf => tf.StudentId == studentId && tf.SemesterId == semesterId);

            if (fee != null)
            {
                return fee;
            }

            var newFee = new TuitionFee
            {
                StudentId = studentId,
                SemesterId = semesterId,
                TotalCredits = 0,
                AmountPerCredit = rate,
                TotalAmount = 0,
                PaidAmount = 0,
                Status = "UNPAID",
                CreatedAt = DateTime.UtcNow
            };

            _context.TuitionFees.Add(newFee);
            await _context.SaveChangesAsync();
            return newFee;
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "GetOrCreateTuitionFeeAsync DB error — StudentId={StudentId}, SemesterId={SemesterId}", studentId, semesterId);
            throw;
        }
    }

    public async Task AddTuitionFeeAsync(TuitionFee entity)
    {
        try
        {
            _context.TuitionFees.Add(entity);
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "AddTuitionFeeAsync DB error — StudentId={StudentId}, SemesterId={SemesterId}", entity.StudentId, entity.SemesterId);
            throw;
        }
    }

    public async Task UpdateTuitionFeeAsync(TuitionFee entity)
    {
        try
        {
            _context.TuitionFees.Update(entity);
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "UpdateTuitionFeeAsync DB error — FeeId={FeeId}", entity.FeeId);
            throw;
        }
    }
}
