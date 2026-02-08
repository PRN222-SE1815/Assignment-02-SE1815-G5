using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IQuizRepository
{
    // ==================== Query Methods ====================

    /// <summary>
    /// Get TeacherId of a ClassSection.
    /// </summary>
    Task<int?> GetClassSectionTeacherIdAsync(int classSectionId);

    /// <summary>
    /// Get quiz with ClassSection for teacher authorization check.
    /// </summary>
    Task<Quiz?> GetQuizWithClassSectionAsync(int quizId);

    /// <summary>
    /// Get quiz with all questions and answers (for validation/publish).
    /// </summary>
    Task<Quiz?> GetQuizWithQuestionsAndAnswersAsync(int quizId);

    /// <summary>
    /// Get quiz for student (minimal: status, time window, classSection, shuffle settings).
    /// </summary>
    Task<Quiz?> GetQuizForStudentAsync(int quizId);

    /// <summary>
    /// Get published quizzes for a class section (read-only).
    /// </summary>
    Task<List<Quiz>> GetPublishedQuizzesForClassAsync(int classSectionId);

    /// <summary>
    /// Check if quiz exists and belongs to teacher's class.
    /// </summary>
    Task<bool> IsQuizOwnedByTeacherAsync(int quizId, int teacherUserId);

    /// <summary>
    /// Get question count for a quiz.
    /// </summary>
    Task<int> GetQuizQuestionCountAsync(int quizId);

    /// <summary>
    /// Get questions with answers for attempt (for returning to student).
    /// </summary>
    Task<List<QuizQuestion>> GetQuestionsWithAnswersAsync(int quizId);

    /// <summary>
    /// Get question IDs belonging to a quiz.
    /// </summary>
    Task<HashSet<int>> GetQuestionIdsForQuizAsync(int quizId);

    /// <summary>
    /// Get answer IDs belonging to specific questions.
    /// </summary>
    Task<Dictionary<int, HashSet<int>>> GetAnswerIdsForQuestionsAsync(IEnumerable<int> questionIds);

    /// <summary>
    /// Get correct answer IDs for questions (for grading).
    /// </summary>
    Task<Dictionary<int, int>> GetCorrectAnswerIdsForQuestionsAsync(IEnumerable<int> questionIds);

    /// <summary>
    /// Get question points by question IDs.
    /// </summary>
    Task<Dictionary<int, decimal>> GetQuestionPointsAsync(IEnumerable<int> questionIds);

    // ==================== Quiz Attempt Methods ====================

    /// <summary>
    /// Get attempt with enrollment for ownership check.
    /// </summary>
    Task<QuizAttempt?> GetAttemptWithEnrollmentAsync(int attemptId);

    /// <summary>
    /// Get attempt with quiz details for submit.
    /// </summary>
    Task<QuizAttempt?> GetAttemptWithQuizAsync(int attemptId);

    /// <summary>
    /// Check if student already has an attempt for quiz.
    /// </summary>
    Task<bool> HasAttemptForQuizAsync(int quizId, int enrollmentId);

    // ==================== Create/Update Methods ====================

    /// <summary>
    /// Create new quiz.
    /// </summary>
    Task<Quiz> CreateQuizAsync(Quiz quiz);

    /// <summary>
    /// Create new question.
    /// </summary>
    Task<QuizQuestion> CreateQuestionAsync(QuizQuestion question);

    /// <summary>
    /// Create answers in batch.
    /// </summary>
    Task CreateAnswersAsync(IEnumerable<QuizAnswer> answers);

    /// <summary>
    /// Update quiz entity.
    /// </summary>
    void UpdateQuiz(Quiz quiz);

    /// <summary>
    /// Create quiz attempt.
    /// </summary>
    Task<QuizAttempt> CreateAttemptAsync(QuizAttempt attempt);

    /// <summary>
    /// Update quiz attempt.
    /// </summary>
    void UpdateAttempt(QuizAttempt attempt);

    /// <summary>
    /// Create attempt answers in batch.
    /// </summary>
    Task CreateAttemptAnswersAsync(IEnumerable<QuizAttemptAnswer> answers);
}
