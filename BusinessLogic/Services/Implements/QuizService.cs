using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implements;

public class QuizService : IQuizService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<QuizService> _logger;

    // Valid values for TotalQuestions as per spec
    private static readonly HashSet<int> ValidTotalQuestions = new() { 10, 20, 30 };

    // Quiz status constants
    private const string STATUS_DRAFT = "DRAFT";
    private const string STATUS_PUBLISHED = "PUBLISHED";
    private const string STATUS_CLOSED = "CLOSED";

    // Attempt status constants
    private const string ATTEMPT_IN_PROGRESS = "IN_PROGRESS";
    private const string ATTEMPT_SUBMITTED = "SUBMITTED";

    // Role constants
    private const string ROLE_TEACHER = "TEACHER";
    private const string ROLE_STUDENT = "STUDENT";

    // Question type constants
    private const string QTYPE_MCQ = "MCQ";
    private const string QTYPE_TRUE_FALSE = "TRUE_FALSE";

    public QuizService(IUnitOfWork unitOfWork, ILogger<QuizService> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    // ==================== TEACHER Operations ====================

    public async Task<int> CreateDraftQuizAsync(
        int teacherUserId,
        string actorRole,
        int classSectionId,
        string quizTitle,
        string? description,
        int totalQuestions,
        int? timeLimitMin,
        bool shuffleQuestions,
        bool shuffleAnswers,
        DateTime? startAt,
        DateTime? endAt)
    {
        // 1. Validate role
        EnsureTeacherRole(actorRole);

        // 2. Validate totalQuestions (must be 10, 20, or 30)
        if (!ValidTotalQuestions.Contains(totalQuestions))
        {
            throw new BusinessException($"TotalQuestions must be one of: {string.Join(", ", ValidTotalQuestions)}");
        }

        // 3. Validate teacher owns this ClassSection
        var classTeacherId = await _unitOfWork.Quizzes.GetClassSectionTeacherIdAsync(classSectionId);
        if (classTeacherId == null)
        {
            throw new NotFoundException("ClassSection", classSectionId);
        }
        if (classTeacherId != teacherUserId)
        {
            throw new ForbiddenException("You are not the teacher of this class section.");
        }

        // 4. Validate time window if provided
        if (startAt.HasValue && endAt.HasValue && endAt <= startAt)
        {
            throw new BusinessException("EndAt must be after StartAt.");
        }

        // 5. Create quiz
        var quiz = new Quiz
        {
            ClassSectionId = classSectionId,
            CreatedBy = teacherUserId,
            QuizTitle = quizTitle,
            Description = description,
            TotalQuestions = totalQuestions,
            TimeLimitMin = timeLimitMin,
            ShuffleQuestions = shuffleQuestions,
            ShuffleAnswers = shuffleAnswers,
            StartAt = startAt,
            EndAt = endAt,
            Status = STATUS_DRAFT,
            CreatedAt = DateTime.UtcNow
        };

        await _unitOfWork.Quizzes.CreateQuizAsync(quiz);
        await _unitOfWork.SaveChangesAsync();

        _logger.LogInformation("Teacher {TeacherId} created draft quiz {QuizId} for ClassSection {ClassSectionId}",
            teacherUserId, quiz.QuizId, classSectionId);

        return quiz.QuizId;
    }

    public async Task<int> AddQuestionAsync(
        int teacherUserId,
        string actorRole,
        int quizId,
        string questionText,
        string questionType,
        decimal points,
        IEnumerable<AnswerInput> answers)
    {
        // 1. Validate role
        EnsureTeacherRole(actorRole);

        // 2. Validate question type
        if (questionType != QTYPE_MCQ && questionType != QTYPE_TRUE_FALSE)
        {
            throw new BusinessException($"QuestionType must be '{QTYPE_MCQ}' or '{QTYPE_TRUE_FALSE}'.");
        }

        // 3. Get quiz and authorize
        var quiz = await _unitOfWork.Quizzes.GetQuizWithClassSectionAsync(quizId);
        if (quiz == null)
        {
            throw new NotFoundException("Quiz", quizId);
        }

        if (quiz.ClassSection.TeacherId != teacherUserId)
        {
            throw new ForbiddenException("You are not the teacher of this quiz's class section.");
        }

        // 4. Quiz must be DRAFT to add questions
        if (quiz.Status != STATUS_DRAFT)
        {
            throw new BusinessException($"Cannot add questions to a quiz with status '{quiz.Status}'. Quiz must be DRAFT.");
        }

        // 5. Validate answers
        var answerList = answers.ToList();
        ValidateAnswers(answerList, questionType);

        // 6. Get current max SortOrder
        var currentCount = await _unitOfWork.Quizzes.GetQuizQuestionCountAsync(quizId);
        if (currentCount >= quiz.TotalQuestions)
        {
            throw new BusinessException($"Quiz already has {currentCount} questions (max: {quiz.TotalQuestions}). Cannot add more.");
        }

        // 7. Create question
        var question = new QuizQuestion
        {
            QuizId = quizId,
            QuestionText = questionText,
            QuestionType = questionType,
            Points = points,
            SortOrder = currentCount + 1
        };

        await _unitOfWork.Quizzes.CreateQuestionAsync(question);
        await _unitOfWork.SaveChangesAsync(); // Save to get QuestionId

        // 8. Create answers
        var quizAnswers = answerList.Select(a => new QuizAnswer
        {
            QuestionId = question.QuestionId,
            AnswerText = a.Text,
            IsCorrect = a.IsCorrect
        });

        await _unitOfWork.Quizzes.CreateAnswersAsync(quizAnswers);
        await _unitOfWork.SaveChangesAsync();

        _logger.LogInformation("Teacher {TeacherId} added question {QuestionId} to quiz {QuizId}",
            teacherUserId, question.QuestionId, quizId);

        return question.QuestionId;
    }

    public async Task PublishQuizAsync(
        int teacherUserId,
        string actorRole,
        int quizId,
        DateTime? startAt,
        DateTime? endAt)
    {
        // 1. Validate role
        EnsureTeacherRole(actorRole);

        // 2. Get quiz with questions and answers
        var quiz = await _unitOfWork.Quizzes.GetQuizWithQuestionsAndAnswersAsync(quizId);
        if (quiz == null)
        {
            throw new NotFoundException("Quiz", quizId);
        }

        if (quiz.ClassSection.TeacherId != teacherUserId)
        {
            throw new ForbiddenException("You are not the teacher of this quiz's class section.");
        }

        // 3. Quiz must be DRAFT
        if (quiz.Status != STATUS_DRAFT)
        {
            throw new BusinessException($"Cannot publish quiz with status '{quiz.Status}'. Quiz must be DRAFT.");
        }

        // 4. Validate question count
        var questionCount = quiz.QuizQuestions.Count;
        if (questionCount != quiz.TotalQuestions)
        {
            throw new BusinessException($"Quiz has {questionCount} questions but requires exactly {quiz.TotalQuestions}.");
        }

        // 5. Validate each question has proper answers
        foreach (var question in quiz.QuizQuestions)
        {
            var answers = question.QuizAnswers.ToList();
            ValidateAnswers(answers.Select(a => new AnswerInput { Text = a.AnswerText, IsCorrect = a.IsCorrect }).ToList(),
                question.QuestionType);
        }

        // 6. Validate time window if provided
        var finalStartAt = startAt ?? quiz.StartAt;
        var finalEndAt = endAt ?? quiz.EndAt;

        if (finalStartAt.HasValue && finalEndAt.HasValue && finalEndAt <= finalStartAt)
        {
            throw new BusinessException("EndAt must be after StartAt.");
        }

        // 7. Update quiz
        quiz.Status = STATUS_PUBLISHED;
        if (startAt.HasValue) quiz.StartAt = startAt;
        if (endAt.HasValue) quiz.EndAt = endAt;

        _unitOfWork.Quizzes.UpdateQuiz(quiz);
        await _unitOfWork.SaveChangesAsync();

        _logger.LogInformation("Teacher {TeacherId} published quiz {QuizId}", teacherUserId, quizId);
    }

    public async Task CloseQuizAsync(
        int teacherUserId,
        string actorRole,
        int quizId)
    {
        // 1. Validate role
        EnsureTeacherRole(actorRole);

        // 2. Get quiz
        var quiz = await _unitOfWork.Quizzes.GetQuizWithClassSectionAsync(quizId);
        if (quiz == null)
        {
            throw new NotFoundException("Quiz", quizId);
        }

        if (quiz.ClassSection.TeacherId != teacherUserId)
        {
            throw new ForbiddenException("You are not the teacher of this quiz's class section.");
        }

        // 3. Can only close PUBLISHED quizzes
        if (quiz.Status != STATUS_PUBLISHED)
        {
            throw new BusinessException($"Cannot close quiz with status '{quiz.Status}'. Quiz must be PUBLISHED.");
        }

        // 4. Update status
        quiz.Status = STATUS_CLOSED;
        _unitOfWork.Quizzes.UpdateQuiz(quiz);
        await _unitOfWork.SaveChangesAsync();

        _logger.LogInformation("Teacher {TeacherId} closed quiz {QuizId}", teacherUserId, quizId);
    }

    // ==================== STUDENT Operations ====================

    public async Task<List<QuizSummary>> ListPublishedQuizzesForClassAsync(
        int studentUserId,
        string actorRole,
        int classSectionId)
    {
        // 1. Validate role
        EnsureStudentRole(actorRole);

        // 2. Check student is enrolled
        var isEnrolled = await _unitOfWork.Enrollments.IsStudentEnrolledInClassAsync(studentUserId, classSectionId);
        if (!isEnrolled)
        {
            throw new ForbiddenException("You are not enrolled in this class section.");
        }

        // 3. Get published quizzes
        var quizzes = await _unitOfWork.Quizzes.GetPublishedQuizzesForClassAsync(classSectionId);

        return quizzes.Select(q => new QuizSummary
        {
            QuizId = q.QuizId,
            QuizTitle = q.QuizTitle,
            Description = q.Description,
            TotalQuestions = q.TotalQuestions,
            TimeLimitMin = q.TimeLimitMin,
            StartAt = q.StartAt,
            EndAt = q.EndAt,
            Status = q.Status
        }).ToList();
    }

    public async Task<StartAttemptResult> StartAttemptAsync(
        int studentUserId,
        string actorRole,
        int quizId,
        DateTime nowUtc)
    {
        // 1. Validate role
        EnsureStudentRole(actorRole);

        // 2. Get quiz
        var quiz = await _unitOfWork.Quizzes.GetQuizForStudentAsync(quizId);
        if (quiz == null)
        {
            throw new NotFoundException("Quiz", quizId);
        }

        // 3. Quiz must be PUBLISHED
        if (quiz.Status != STATUS_PUBLISHED)
        {
            throw new BusinessException($"Quiz is not available. Current status: '{quiz.Status}'.");
        }

        // 4. Check time window
        if (quiz.StartAt.HasValue && nowUtc < quiz.StartAt.Value)
        {
            throw new BusinessException($"Quiz has not started yet. Starts at: {quiz.StartAt.Value:u}");
        }
        if (quiz.EndAt.HasValue && nowUtc > quiz.EndAt.Value)
        {
            throw new BusinessException($"Quiz has ended. Ended at: {quiz.EndAt.Value:u}");
        }

        // 5. Get enrollment
        var enrollmentId = await _unitOfWork.Enrollments.GetEnrolledStudentEnrollmentIdAsync(studentUserId, quiz.ClassSectionId);
        if (enrollmentId == null)
        {
            throw new ForbiddenException("You are not enrolled in this class section.");
        }

        // 6. Check for existing attempt (before transaction)
        var hasAttempt = await _unitOfWork.Quizzes.HasAttemptForQuizAsync(quizId, enrollmentId.Value);
        if (hasAttempt)
        {
            throw new ConflictException("You have already attempted this quiz. Only one attempt is allowed.");
        }

        // 7. Create attempt with transaction to handle race condition
        // Unique index UX_QuizAttempts_OnePerStudent(QuizId, EnrollmentId) will prevent duplicates
        var attempt = new QuizAttempt
        {
            QuizId = quizId,
            EnrollmentId = enrollmentId.Value,
            ClassSectionId = quiz.ClassSectionId,
            StartedAt = nowUtc,
            Status = ATTEMPT_IN_PROGRESS
        };

        await using var transaction = await _unitOfWork.BeginTransactionAsync();
        try
        {
            await _unitOfWork.Quizzes.CreateAttemptAsync(attempt);
            await _unitOfWork.SaveChangesAsync();
            await transaction.CommitAsync();
        }
        catch (DbUpdateException ex) when (ex.InnerException?.Message.Contains("UX_QuizAttempts_OnePerStudent") == true)
        {
            // Race condition: another request already created an attempt
            throw new ConflictException("You have already attempted this quiz. Only one attempt is allowed.");
        }

        _logger.LogInformation("Student {StudentId} started attempt {AttemptId} for quiz {QuizId}",
            studentUserId, attempt.AttemptId, quizId);

        // 8. Get questions with answers
        var questions = await _unitOfWork.Quizzes.GetQuestionsWithAnswersAsync(quizId);

        // 9. Apply shuffle if configured
        // NOTE: Order is NOT stable on refresh because we cannot store snapshot (schema change forbidden).
        // If student refreshes, the order may change. This is a known limitation.
        var rng = new Random();

        if (quiz.ShuffleQuestions)
        {
            questions = questions.OrderBy(_ => rng.Next()).ToList();
        }

        var result = new StartAttemptResult
        {
            AttemptId = attempt.AttemptId,
            Questions = questions.Select(q =>
            {
                var answers = q.QuizAnswers.ToList();
                if (quiz.ShuffleAnswers)
                {
                    answers = answers.OrderBy(_ => rng.Next()).ToList();
                }

                return new QuestionForAttempt
                {
                    QuestionId = q.QuestionId,
                    QuestionText = q.QuestionText,
                    QuestionType = q.QuestionType,
                    Points = q.Points,
                    Answers = answers.Select(a => new AnswerForAttempt
                    {
                        AnswerId = a.AnswerId,
                        AnswerText = a.AnswerText
                        // IsCorrect is NOT exposed to student
                    }).ToList()
                };
            }).ToList()
        };

        // Add note about shuffle instability
        if (quiz.ShuffleQuestions || quiz.ShuffleAnswers)
        {
            result.ShuffleNote = "Order is not stable on refresh. To make it stable, we would need to store a snapshot of the randomized order, but schema changes are forbidden.";
        }

        return result;
    }

    public async Task<SubmitAttemptResult> SubmitAttemptAsync(
        int studentUserId,
        string actorRole,
        int attemptId,
        DateTime nowUtc,
        IEnumerable<AnswerSubmission> answers)
    {
        // 1. Validate role
        EnsureStudentRole(actorRole);

        // 2. Get attempt with quiz and enrollment
        var attempt = await _unitOfWork.Quizzes.GetAttemptWithQuizAsync(attemptId);
        if (attempt == null)
        {
            throw new NotFoundException("QuizAttempt", attemptId);
        }

        // 3. Verify attempt belongs to student
        // Enrollment.StudentId = UserId for students
        if (attempt.Enrollment.StudentId != studentUserId)
        {
            throw new ForbiddenException("This attempt does not belong to you.");
        }

        // 4. Attempt must be IN_PROGRESS
        if (attempt.Status != ATTEMPT_IN_PROGRESS)
        {
            throw new BusinessException($"Cannot submit attempt with status '{attempt.Status}'.");
        }

        // 5. Check if quiz has expired
        if (attempt.Quiz.EndAt.HasValue && nowUtc > attempt.Quiz.EndAt.Value)
        {
            throw new BusinessException("Quiz has expired. Cannot submit after the deadline.");
        }

        // 6. Get valid question IDs for this quiz
        var validQuestionIds = await _unitOfWork.Quizzes.GetQuestionIdsForQuizAsync(attempt.QuizId);

        // 7. Get valid answer IDs for questions
        var answerList = answers.ToList();
        var submittedQuestionIds = answerList.Select(a => a.QuestionId).Distinct().ToList();

        // Validate all submitted questions belong to quiz
        foreach (var qid in submittedQuestionIds)
        {
            if (!validQuestionIds.Contains(qid))
            {
                throw new BusinessException($"Question {qid} does not belong to this quiz.");
            }
        }

        var validAnswersByQuestion = await _unitOfWork.Quizzes.GetAnswerIdsForQuestionsAsync(submittedQuestionIds);

        // Validate all submitted answers belong to their questions
        foreach (var submission in answerList)
        {
            if (!validAnswersByQuestion.TryGetValue(submission.QuestionId, out var validAnswers))
            {
                throw new BusinessException($"Question {submission.QuestionId} not found.");
            }
            if (!validAnswers.Contains(submission.SelectedAnswerId))
            {
                throw new BusinessException($"Answer {submission.SelectedAnswerId} does not belong to question {submission.QuestionId}.");
            }
        }

        // 8. Get correct answers and points for grading
        var correctAnswers = await _unitOfWork.Quizzes.GetCorrectAnswerIdsForQuestionsAsync(submittedQuestionIds);
        var questionPoints = await _unitOfWork.Quizzes.GetQuestionPointsAsync(submittedQuestionIds);

        // 9. Grade and create attempt answers
        decimal totalScore = 0;
        int correctCount = 0;

        var attemptAnswers = new List<QuizAttemptAnswer>();
        foreach (var submission in answerList)
        {
            var isCorrect = correctAnswers.TryGetValue(submission.QuestionId, out var correctAnswerId)
                            && submission.SelectedAnswerId == correctAnswerId;

            if (isCorrect)
            {
                correctCount++;
                if (questionPoints.TryGetValue(submission.QuestionId, out var points))
                {
                    totalScore += points;
                }
            }

            attemptAnswers.Add(new QuizAttemptAnswer
            {
                AttemptId = attemptId,
                QuestionId = submission.QuestionId,
                SelectedAnswerId = submission.SelectedAnswerId,
                IsCorrect = isCorrect
            });
        }

        // 10. Update attempt status and score
        attempt.Status = ATTEMPT_SUBMITTED;
        attempt.SubmittedAt = nowUtc;
        attempt.Score = totalScore;

        // 11. Save all changes
        await _unitOfWork.Quizzes.CreateAttemptAnswersAsync(attemptAnswers);
        _unitOfWork.Quizzes.UpdateAttempt(attempt);
        await _unitOfWork.SaveChangesAsync();

        _logger.LogInformation("Student {StudentId} submitted attempt {AttemptId}. Score: {Score}, Correct: {Correct}/{Total}",
            studentUserId, attemptId, totalScore, correctCount, validQuestionIds.Count);

        return new SubmitAttemptResult
        {
            FinalScore = totalScore,
            CorrectCount = correctCount,
            TotalQuestions = validQuestionIds.Count
        };
    }

    // ==================== Private Helpers ====================

    private static void EnsureTeacherRole(string actorRole)
    {
        if (!string.Equals(actorRole, ROLE_TEACHER, StringComparison.OrdinalIgnoreCase))
        {
            throw new ForbiddenException("Only teachers can perform this action.");
        }
    }

    private static void EnsureStudentRole(string actorRole)
    {
        if (!string.Equals(actorRole, ROLE_STUDENT, StringComparison.OrdinalIgnoreCase))
        {
            throw new ForbiddenException("Only students can perform this action.");
        }
    }

    /// <summary>
    /// Validate answers for a question.
    /// Rules:
    /// - MCQ: >= 2 answers, exactly 1 correct
    /// - TRUE_FALSE: >= 2 answers, exactly 1 correct
    /// </summary>
    private static void ValidateAnswers(List<AnswerInput> answers, string questionType)
    {
        if (answers.Count < 2)
        {
            throw new BusinessException($"Question must have at least 2 answers. Found: {answers.Count}");
        }

        var correctCount = answers.Count(a => a.IsCorrect);
        if (correctCount != 1)
        {
            throw new BusinessException($"Question must have exactly 1 correct answer. Found: {correctCount}");
        }
    }
}
