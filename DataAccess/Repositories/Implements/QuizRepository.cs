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

    public async Task<List<Quiz>> GetPublishedQuizzesForStudentAsync(int studentUserId)
    {
        var enrolledClassSectionIds = await _context.Enrollments
            .AsNoTracking()
            .Where(e => e.StudentId == studentUserId && (e.Status == "ENROLLED" || e.Status == "COMPLETED"))
            .Select(e => e.ClassSectionId)
            .ToListAsync();

        return await _context.Quizzes
            .AsNoTracking()
            .Include(q => q.ClassSection)
            .Where(q => enrolledClassSectionIds.Contains(q.ClassSectionId) && q.Status == "PUBLISHED")
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

    public async Task<QuizAttempt?> GetAttemptForGradeSyncAsync(int attemptId, CancellationToken ct = default)
    {
        return await _context.QuizAttempts
            .AsNoTracking()
            .Include(a => a.Quiz)
                .ThenInclude(q => q.ClassSection)
            .Include(a => a.Enrollment)
            .FirstOrDefaultAsync(a => a.AttemptId == attemptId, ct);
    }

    public async Task<QuizAttempt?> GetLatestGradedAttemptByQuizAndEnrollmentAsync(int quizId, int enrollmentId, CancellationToken ct = default)
    {
        return await _context.QuizAttempts
            .AsNoTracking()
            .Include(a => a.Quiz)
                .ThenInclude(q => q.ClassSection)
            .Include(a => a.Enrollment)
            .Where(a => a.QuizId == quizId
                && a.EnrollmentId == enrollmentId
                && a.Status == "GRADED")
            .OrderByDescending(a => a.SubmittedAt ?? DateTime.MinValue)
            .ThenByDescending(a => a.AttemptId)
            .FirstOrDefaultAsync(ct);
    }

    public async Task<GradeItem?> FindGradeItemForQuizAsync(int gradeBookId, int quizId, CancellationToken ct = default)
    {
        var mappingName = $"QUIZ:{quizId}";

        return await _context.GradeItems
            .AsNoTracking()
            .Where(gi => gi.GradeBookId == gradeBookId)
            .FirstOrDefaultAsync(gi => gi.ItemName.ToUpper() == mappingName.ToUpper(), ct);
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

    public async Task DeleteQuizAsync(int quizId)
    {
        var quiz = await _context.Quizzes
            .Include(q => q.QuizQuestions)
                .ThenInclude(qq => qq.QuizAnswers)
            .Include(q => q.QuizAttempts)
                .ThenInclude(qa => qa.QuizAttemptAnswers)
            .FirstOrDefaultAsync(q => q.QuizId == quizId);

        if (quiz != null)
        {
            foreach (var attempt in quiz.QuizAttempts)
                _context.QuizAttemptAnswers.RemoveRange(attempt.QuizAttemptAnswers);
            _context.QuizAttempts.RemoveRange(quiz.QuizAttempts);

            foreach (var question in quiz.QuizQuestions)
                _context.QuizAnswers.RemoveRange(question.QuizAnswers);
            _context.QuizQuestions.RemoveRange(quiz.QuizQuestions);

            _context.Quizzes.Remove(quiz);
        }
    }

    public async Task<QuizQuestion?> GetQuestionByIdAsync(int questionId)
    {
        return await _context.QuizQuestions
            .Include(q => q.QuizAnswers)
            .FirstOrDefaultAsync(q => q.QuestionId == questionId);
    }

    public void UpdateQuestion(QuizQuestion question)
    {
        _context.QuizQuestions.Update(question);
    }

    public async Task DeleteQuestionAsync(int questionId)
    {
        var question = await _context.QuizQuestions
            .Include(q => q.QuizAnswers)
            .FirstOrDefaultAsync(q => q.QuestionId == questionId);

        if (question != null)
        {
            _context.QuizAnswers.RemoveRange(question.QuizAnswers);
            _context.QuizQuestions.Remove(question);
        }
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
