using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IQuizRepository
{
    // ==================== ClassSection Queries ====================
    
    /// <summary>
    /// Get TeacherId of a ClassSection. Returns null if not found.
    /// </summary>
    Task<int?> GetClassSectionTeacherIdAsync(int classSectionId);

    // ==================== Quiz Queries ====================
    
    /// <summary>
    /// Get quiz by ID with ClassSection for authorization.
    /// </summary>
    Task<Quiz?> GetQuizWithClassSectionAsync(int quizId);

    /// <summary>
    /// Get quiz with all questions and answers for validation/publish.
    /// </summary>
    Task<Quiz?> GetQuizWithQuestionsAndAnswersAsync(int quizId);

    /// <summary>
    /// Get quiz for student (read-only, minimal includes).
    /// </summary>
    Task<Quiz?> GetQuizForStudentAsync(int quizId);

    /// <summary>
    /// Get published quizzes for a class section.
    /// </summary>
    Task<List<Quiz>> GetPublishedQuizzesForClassAsync(int classSectionId);

    /// <summary>
    /// Get question count for a quiz.
    /// </summary>
    Task<int> GetQuestionCountAsync(int quizId);

    /// <summary>
    /// Get questions with answers for an attempt (student view).
    /// </summary>
    Task<List<QuizQuestion>> GetQuestionsWithAnswersAsync(int quizId);

    /// <summary>
    /// Get question IDs for a quiz.
    /// </summary>
    Task<HashSet<int>> GetQuestionIdsForQuizAsync(int quizId);

    /// <summary>
    /// Get valid answer IDs grouped by question ID.
    /// </summary>
    Task<Dictionary<int, HashSet<int>>> GetAnswerIdsForQuestionsAsync(IEnumerable<int> questionIds);

    /// <summary>
    /// Get correct answer ID for each question.
    /// </summary>
    Task<Dictionary<int, int>> GetCorrectAnswerIdsAsync(IEnumerable<int> questionIds);

    /// <summary>
    /// Get points for each question.
    /// </summary>
    Task<Dictionary<int, decimal>> GetQuestionPointsAsync(IEnumerable<int> questionIds);

    // ==================== Attempt Queries ====================
    
    /// <summary>
    /// Get attempt with enrollment for ownership check.
    /// </summary>
    Task<QuizAttempt?> GetAttemptWithEnrollmentAsync(int attemptId);

    /// <summary>
    /// Get attempt with quiz for submit validation.
    /// </summary>
    Task<QuizAttempt?> GetAttemptWithQuizAndEnrollmentAsync(int attemptId);

    /// <summary>
    /// Check if student already has an attempt for this quiz.
    /// </summary>
    Task<bool> HasAttemptAsync(int quizId, int enrollmentId);

    // ==================== Create/Update ====================
    
    Task<Quiz> CreateQuizAsync(Quiz quiz);
    Task<QuizQuestion> CreateQuestionAsync(QuizQuestion question);
    Task CreateAnswersAsync(IEnumerable<QuizAnswer> answers);
    void UpdateQuiz(Quiz quiz);
    Task<QuizAttempt> CreateAttemptAsync(QuizAttempt attempt);
    void UpdateAttempt(QuizAttempt attempt);
    Task CreateAttemptAnswersAsync(IEnumerable<QuizAttemptAnswer> answers);

    // ==================== Persistence ====================
    
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
