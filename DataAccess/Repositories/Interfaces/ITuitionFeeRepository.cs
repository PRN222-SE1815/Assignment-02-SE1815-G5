using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface ITuitionFeeRepository
{
    Task<TuitionFee?> GetOrCreateTuitionFeeAsync(int studentId, int semesterId, decimal rate);
    Task AddTuitionFeeAsync(TuitionFee entity);
    Task UpdateTuitionFeeAsync(TuitionFee entity);
}
