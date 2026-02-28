using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implements;

public class QuizRepository : IQuizRepository
{
    private readonly SchoolManagementDbContext _context;

    public QuizRepository(SchoolManagementDbContext context)
    {
        _context = context;
    }

    // ==================== ClassSection Queries ====================

    public async Task<int?> GetClassSectionTeacherIdAsync(int classSectionId)
    {
        return await _context.ClassSections
            .AsNoTracking()
            .Where(cs => cs.ClassSectionId == classSectionId)
            .Select(cs => (int?)cs.TeacherId)
            .FirstOrDefaultAsync();
    }

    // ==================== Quiz Queries ====================

    public async Task<Quiz?> GetQuizWithClassSectionAsync(int quizId)
    {
        return await _context.Quizzes
            .Include(q => q.ClassSection)
            .FirstOrDefaultAsync(q => q.QuizId == quizId);
    }

    public async Task<Quiz?> GetQuizWithQuestionsAndAnswersAsync(int quizId)
    {
        return await _context.Quizzes
            .Include(q => q.ClassSection)
            .Include(q => q.QuizQuestions)
                .ThenInclude(qq => qq.QuizAnswers)
            .FirstOrDefaultAsync(q => q.QuizId == quizId);
    }

    public async Task<Quiz?> GetQuizForStudentAsync(int quizId)
    {
        return await _context.Quizzes
            .AsNoTracking()
            .Include(q => q.ClassSection)
            .FirstOrDefaultAsync(q => q.QuizId == quizId);
    }

    public async Task<List<Quiz>> GetPublishedQuizzesForClassAsync(int classSectionId)
    {
        return await _context.Quizzes
            .AsNoTracking()
            .Where(q => q.ClassSectionId == classSectionId && q.Status == "PUBLISHED")
            .OrderByDescending(q => q.CreatedAt)
            .ToListAsync();
    }

    public async Task<List<Quiz>> GetQuizzesByTeacherIdAsync(int teacherUserId)
    {
        return await _context.Quizzes
            .AsNoTracking()
            .Include(q => q.ClassSection)
            .Where(q => q.CreatedBy == teacherUserId)
            .OrderByDescending(q => q.CreatedAt)
            .ToListAsync();
    }

    public async Task<int> GetQuestionCountAsync(int quizId)
    {
        return await _context.QuizQuestions
            .AsNoTracking()
            .CountAsync(q => q.QuizId == quizId);
    }

    public async Task<List<QuizQuestion>> GetQuestionsWithAnswersAsync(int quizId)
    {
        return await _context.QuizQuestions
            .AsNoTracking()
            .Include(q => q.QuizAnswers)
            .Where(q => q.QuizId == quizId)
            .OrderBy(q => q.SortOrder)
            .ToListAsync();
    }

    public async Task<HashSet<int>> GetQuestionIdsForQuizAsync(int quizId)
    {
        var ids = await _context.QuizQuestions
            .AsNoTracking()
            .Where(q => q.QuizId == quizId)
            .Select(q => q.QuestionId)
            .ToListAsync();
        return ids.ToHashSet();
    }

    public async Task<Dictionary<int, HashSet<int>>> GetAnswerIdsForQuestionsAsync(IEnumerable<int> questionIds)
    {
        var questionIdList = questionIds.ToList();
        var answers = await _context.QuizAnswers
            .AsNoTracking()
            .Where(a => questionIdList.Contains(a.QuestionId))
            .Select(a => new { a.QuestionId, a.AnswerId })
            .ToListAsync();

        return answers
            .GroupBy(a => a.QuestionId)
            .ToDictionary(g => g.Key, g => g.Select(x => x.AnswerId).ToHashSet());
    }

    public async Task<Dictionary<int, int>> GetCorrectAnswerIdsAsync(IEnumerable<int> questionIds)
    {
        var questionIdList = questionIds.ToList();
        var correctAnswers = await _context.QuizAnswers
            .AsNoTracking()
            .Where(a => questionIdList.Contains(a.QuestionId) && a.IsCorrect)
            .Select(a => new { a.QuestionId, a.AnswerId })
            .ToListAsync();

        return correctAnswers.ToDictionary(a => a.QuestionId, a => a.AnswerId);
    }

    public async Task<Dictionary<int, decimal>> GetQuestionPointsAsync(IEnumerable<int> questionIds)
    {
        var questionIdList = questionIds.ToList();
        return await _context.QuizQuestions
            .AsNoTracking()
            .Where(q => questionIdList.Contains(q.QuestionId))
            .ToDictionaryAsync(q => q.QuestionId, q => q.Points);
    }

    // ==================== Attempt Queries ====================

    public async Task<QuizAttempt?> GetAttemptWithEnrollmentAsync(int attemptId)
    {
        return await _context.QuizAttempts
            .Include(a => a.Enrollment)
            .FirstOrDefaultAsync(a => a.AttemptId == attemptId);
    }

    public async Task<QuizAttempt?> GetAttemptWithQuizAndEnrollmentAsync(int attemptId)
    {
        return await _context.QuizAttempts
            .Include(a => a.Quiz)
            .Include(a => a.Enrollment)
            .FirstOrDefaultAsync(a => a.AttemptId == attemptId);
    }

    public async Task<bool> HasAttemptAsync(int quizId, int enrollmentId)
    {
        return await _context.QuizAttempts
            .AsNoTracking()
            .AnyAsync(a => a.QuizId == quizId && a.EnrollmentId == enrollmentId);
    }

    // ==================== Create/Update ====================

    public async Task<Quiz> CreateQuizAsync(Quiz quiz)
    {
        await _context.Quizzes.AddAsync(quiz);
        return quiz;
    }

    public async Task<QuizQuestion> CreateQuestionAsync(QuizQuestion question)
    {
        await _context.QuizQuestions.AddAsync(question);
        return question;
    }

    public async Task CreateAnswersAsync(IEnumerable<QuizAnswer> answers)
    {
        await _context.QuizAnswers.AddRangeAsync(answers);
    }

    public void UpdateQuiz(Quiz quiz)
    {
        _context.Quizzes.Update(quiz);
    }

    public async Task<QuizAttempt> CreateAttemptAsync(QuizAttempt attempt)
    {
        await _context.QuizAttempts.AddAsync(attempt);
        return attempt;
    }

    public void UpdateAttempt(QuizAttempt attempt)
    {
        _context.QuizAttempts.Update(attempt);
    }

    public async Task CreateAttemptAnswersAsync(IEnumerable<QuizAttemptAnswer> answers)
    {
        await _context.QuizAttemptAnswers.AddRangeAsync(answers);
    }

    // ==================== Persistence ====================

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }
}
