using System;
using System.Collections.Generic;
using DataAccess.Entities;
using Microsoft.EntityFrameworkCore;

namespace DataAccess;

public partial class SchoolManagementDbContext : DbContext
{
    public SchoolManagementDbContext(DbContextOptions<SchoolManagementDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<AIChatMessage> AIChatMessages { get; set; }

    public virtual DbSet<AIChatSession> AIChatSessions { get; set; }

    public virtual DbSet<AIToolCall> AIToolCalls { get; set; }

    public virtual DbSet<ChatMessage> ChatMessages { get; set; }

    public virtual DbSet<ChatMessageAttachment> ChatMessageAttachments { get; set; }

    public virtual DbSet<ChatModerationLog> ChatModerationLogs { get; set; }

    public virtual DbSet<ChatRoom> ChatRooms { get; set; }

    public virtual DbSet<ChatRoomMember> ChatRoomMembers { get; set; }

    public virtual DbSet<ClassSection> ClassSections { get; set; }

    public virtual DbSet<Course> Courses { get; set; }

    public virtual DbSet<Enrollment> Enrollments { get; set; }

    public virtual DbSet<GradeAuditLog> GradeAuditLogs { get; set; }

    public virtual DbSet<GradeBook> GradeBooks { get; set; }

    public virtual DbSet<GradeBookApproval> GradeBookApprovals { get; set; }

    public virtual DbSet<GradeEntry> GradeEntries { get; set; }

    public virtual DbSet<GradeItem> GradeItems { get; set; }

    public virtual DbSet<Notification> Notifications { get; set; }

    public virtual DbSet<NotificationRecipient> NotificationRecipients { get; set; }

    public virtual DbSet<PaymentTransaction> PaymentTransactions { get; set; }

    public virtual DbSet<Program> Programs { get; set; }

    public virtual DbSet<Quiz> Quizzes { get; set; }

    public virtual DbSet<QuizAnswer> QuizAnswers { get; set; }

    public virtual DbSet<QuizAttempt> QuizAttempts { get; set; }

    public virtual DbSet<QuizAttemptAnswer> QuizAttemptAnswers { get; set; }

    public virtual DbSet<QuizQuestion> QuizQuestions { get; set; }

    public virtual DbSet<Recurrence> Recurrences { get; set; }

    public virtual DbSet<ScheduleChangeLog> ScheduleChangeLogs { get; set; }

    public virtual DbSet<ScheduleEvent> ScheduleEvents { get; set; }

    public virtual DbSet<ScheduleEventOverride> ScheduleEventOverrides { get; set; }

    public virtual DbSet<Semester> Semesters { get; set; }

    public virtual DbSet<Student> Students { get; set; }

    public virtual DbSet<StudentWallet> StudentWallets { get; set; }

    public virtual DbSet<Teacher> Teachers { get; set; }

    public virtual DbSet<TuitionFee> TuitionFees { get; set; }

    public virtual DbSet<User> Users { get; set; }

    public virtual DbSet<WalletTransaction> WalletTransactions { get; set; }

    public virtual DbSet<vw_ClassSectionSummary> vw_ClassSectionSummaries { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<AIChatMessage>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.ChatSession).WithMany(p => p.AIChatMessages)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_AIChatMessages_Session");
        });

        modelBuilder.Entity<AIChatSession>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.State).HasDefaultValue("ACTIVE");

            entity.HasOne(d => d.User).WithMany(p => p.AIChatSessions)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_AIChatSessions_User");
        });

        modelBuilder.Entity<AIToolCall>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Status).HasDefaultValue("OK");

            entity.HasOne(d => d.ChatSession).WithMany(p => p.AIToolCalls)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_AIToolCalls_Session");
        });

        modelBuilder.Entity<ChatMessage>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.MessageType).HasDefaultValue("TEXT");

            entity.HasOne(d => d.Room).WithMany(p => p.ChatMessages)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ChatMessages_Room");

            entity.HasOne(d => d.Sender).WithMany(p => p.ChatMessages)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ChatMessages_Sender");
        });

        modelBuilder.Entity<ChatMessageAttachment>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.Message).WithMany(p => p.ChatMessageAttachments)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ChatMessageAttachments_Message");
        });

        modelBuilder.Entity<ChatModerationLog>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.ActorUser).WithMany(p => p.ChatModerationLogActorUsers)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ChatModerationLogs_Actor");

            entity.HasOne(d => d.Room).WithMany(p => p.ChatModerationLogs)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ChatModerationLogs_Room");

            entity.HasOne(d => d.TargetMessage).WithMany(p => p.ChatModerationLogs).HasConstraintName("FK_ChatModerationLogs_TargetMessage");

            entity.HasOne(d => d.TargetUser).WithMany(p => p.ChatModerationLogTargetUsers).HasConstraintName("FK_ChatModerationLogs_TargetUser");
        });

        modelBuilder.Entity<ChatRoom>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Status).HasDefaultValue("ACTIVE");

            entity.HasOne(d => d.ClassSection).WithMany(p => p.ChatRooms).HasConstraintName("FK_ChatRooms_ClassSections");

            entity.HasOne(d => d.Course).WithMany(p => p.ChatRooms).HasConstraintName("FK_ChatRooms_Courses");

            entity.HasOne(d => d.CreatedByNavigation).WithMany(p => p.ChatRooms)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ChatRooms_CreatedBy");
        });

        modelBuilder.Entity<ChatRoomMember>(entity =>
        {
            entity.Property(e => e.JoinedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.MemberStatus).HasDefaultValue("JOINED");
            entity.Property(e => e.RoleInRoom).HasDefaultValue("MEMBER");

            entity.HasOne(d => d.Room).WithMany(p => p.ChatRoomMembers)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ChatRoomMembers_Room");

            entity.HasOne(d => d.User).WithMany(p => p.ChatRoomMembers)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ChatRoomMembers_User");
        });

        modelBuilder.Entity<ClassSection>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.IsOpen).HasDefaultValue(true);
            entity.Property(e => e.MaxCapacity).HasDefaultValue(30);

            entity.HasOne(d => d.Course).WithMany(p => p.ClassSections)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ClassSections_Courses");

            entity.HasOne(d => d.Semester).WithMany(p => p.ClassSections)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ClassSections_Semesters");

            entity.HasOne(d => d.Teacher).WithMany(p => p.ClassSections)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ClassSections_Teachers");
        });

        modelBuilder.Entity<Course>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.IsActive).HasDefaultValue(true);

            entity.HasMany(d => d.Courses).WithMany(p => p.PrerequisiteCourses)
                .UsingEntity<Dictionary<string, object>>(
                    "CoursePrerequisite",
                    r => r.HasOne<Course>().WithMany()
                        .HasForeignKey("CourseId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("FK_CoursePrerequisites_Course"),
                    l => l.HasOne<Course>().WithMany()
                        .HasForeignKey("PrerequisiteCourseId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("FK_CoursePrerequisites_Prereq"),
                    j =>
                    {
                        j.HasKey("CourseId", "PrerequisiteCourseId");
                        j.ToTable("CoursePrerequisites");
                    });

            entity.HasMany(d => d.PrerequisiteCourses).WithMany(p => p.Courses)
                .UsingEntity<Dictionary<string, object>>(
                    "CoursePrerequisite",
                    r => r.HasOne<Course>().WithMany()
                        .HasForeignKey("PrerequisiteCourseId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("FK_CoursePrerequisites_Prereq"),
                    l => l.HasOne<Course>().WithMany()
                        .HasForeignKey("CourseId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("FK_CoursePrerequisites_Course"),
                    j =>
                    {
                        j.HasKey("CourseId", "PrerequisiteCourseId");
                        j.ToTable("CoursePrerequisites");
                    });
        });

        modelBuilder.Entity<Enrollment>(entity =>
        {
            entity.HasIndex(e => new { e.StudentId, e.CourseId, e.SemesterId }, "UX_Enrollments_Student_Course_Sem_Active")
                .IsUnique()
                .HasFilter("([Status] IN (N'ENROLLED', N'WITHDRAWN'))");

            entity.Property(e => e.EnrolledAt).HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.ClassSection).WithMany(p => p.Enrollments)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Enrollments_ClassSections");

            entity.HasOne(d => d.Course).WithMany(p => p.Enrollments)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Enrollments_Courses");

            entity.HasOne(d => d.Semester).WithMany(p => p.Enrollments)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Enrollments_Semesters");

            entity.HasOne(d => d.Student).WithMany(p => p.Enrollments)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Enrollments_Students");
        });

        modelBuilder.Entity<GradeAuditLog>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.ActorUser).WithMany(p => p.GradeAuditLogs)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_GradeAuditLogs_Actor");

            entity.HasOne(d => d.GradeEntry).WithMany(p => p.GradeAuditLogs)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_GradeAuditLogs_GradeEntries");
        });

        modelBuilder.Entity<GradeBook>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Status).HasDefaultValue("DRAFT");
            entity.Property(e => e.Version).HasDefaultValue(1);

            entity.HasOne(d => d.ClassSection).WithOne(p => p.GradeBook)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_GradeBooks_ClassSections");
        });

        modelBuilder.Entity<GradeBookApproval>(entity =>
        {
            entity.HasKey(e => e.ApprovalId).HasName("PK__GradeBoo__328477F4F70674EC");

            entity.Property(e => e.RequestAt).HasDefaultValueSql("(sysutcdatetime())");
        });

        modelBuilder.Entity<GradeEntry>(entity =>
        {
            entity.Property(e => e.UpdatedAt).HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.Enrollment).WithMany(p => p.GradeEntries)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_GradeEntries_Enrollments");

            entity.HasOne(d => d.GradeItem).WithMany(p => p.GradeEntries)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_GradeEntries_GradeItems");

            entity.HasOne(d => d.UpdatedByNavigation).WithMany(p => p.GradeEntries).HasConstraintName("FK_GradeEntries_UpdatedBy");
        });

        modelBuilder.Entity<GradeItem>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.MaxScore).HasDefaultValue(10.00m);

            entity.HasOne(d => d.GradeBook).WithMany(p => p.GradeItems)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_GradeItems_GradeBooks");
        });

        modelBuilder.Entity<Notification>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Status).HasDefaultValue("PENDING");
        });

        modelBuilder.Entity<NotificationRecipient>(entity =>
        {
            entity.HasOne(d => d.Notification).WithMany(p => p.NotificationRecipients)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_NotificationRecipients_Notification");

            entity.HasOne(d => d.User).WithMany(p => p.NotificationRecipients)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_NotificationRecipients_User");
        });

        modelBuilder.Entity<PaymentTransaction>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.PaymentMethod).HasDefaultValue("MOMO");
            entity.Property(e => e.Status).HasDefaultValue("PENDING");

            entity.HasOne(d => d.Student).WithMany(p => p.PaymentTransactions)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PaymentTransactions_Students");
        });

        modelBuilder.Entity<Program>(entity =>
        {
            entity.Property(e => e.IsActive).HasDefaultValue(true);
        });

        modelBuilder.Entity<Quiz>(entity =>
        {
            entity.HasKey(e => e.QuizId).HasName("PK__Quizzes__8B42AE8E476E718C");

            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.ShuffleAnswers).HasDefaultValue(true);
            entity.Property(e => e.ShuffleQuestions).HasDefaultValue(true);
            entity.Property(e => e.Status).HasDefaultValue("DRAFT");

            entity.HasOne(d => d.ClassSection).WithMany(p => p.Quizzes)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Quizzes_ClassSection");

            entity.HasOne(d => d.CreatedByNavigation).WithMany(p => p.Quizzes)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Quizzes_CreatedBy");
        });

        modelBuilder.Entity<QuizAnswer>(entity =>
        {
            entity.HasKey(e => e.AnswerId).HasName("PK__QuizAnsw__D48250046621B434");

            entity.HasOne(d => d.Question).WithMany(p => p.QuizAnswers)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QuizAnswers_Question");
        });

        modelBuilder.Entity<QuizAttempt>(entity =>
        {
            entity.HasKey(e => e.AttemptId).HasName("PK__QuizAtte__891A68E65C020986");

            entity.Property(e => e.StartedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Status).HasDefaultValue("IN_PROGRESS");

            entity.HasOne(d => d.ClassSection).WithMany(p => p.QuizAttempts)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QuizAttempts_ClassSection");

            entity.HasOne(d => d.Enrollment).WithMany(p => p.QuizAttempts)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QuizAttempts_Enrollment");

            entity.HasOne(d => d.Quiz).WithMany(p => p.QuizAttempts)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QuizAttempts_Quiz");
        });

        modelBuilder.Entity<QuizAttemptAnswer>(entity =>
        {
            entity.HasKey(e => e.AttemptAnswerId).HasName("PK__QuizAtte__EC6FE54E7FB5A5CC");

            entity.HasOne(d => d.Attempt).WithMany(p => p.QuizAttemptAnswers)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QAA_Attempt");

            entity.HasOne(d => d.Question).WithMany(p => p.QuizAttemptAnswers)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QAA_Question");

            entity.HasOne(d => d.SelectedAnswer).WithMany(p => p.QuizAttemptAnswers).HasConstraintName("FK_QAA_Answer");
        });

        modelBuilder.Entity<QuizQuestion>(entity =>
        {
            entity.HasKey(e => e.QuestionId).HasName("PK__QuizQues__0DC06FAC9A96F3F9");

            entity.Property(e => e.Points).HasDefaultValue(1m);
            entity.Property(e => e.QuestionType).HasDefaultValue("MCQ");

            entity.HasOne(d => d.Quiz).WithMany(p => p.QuizQuestions)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_QuizQuestions_Quiz");
        });

        modelBuilder.Entity<Recurrence>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
        });

        modelBuilder.Entity<ScheduleChangeLog>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.ActorUser).WithMany(p => p.ScheduleChangeLogs)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ScheduleChangeLogs_Actor");

            entity.HasOne(d => d.ScheduleEvent).WithMany(p => p.ScheduleChangeLogs)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ScheduleChangeLogs_Event");
        });

        modelBuilder.Entity<ScheduleEvent>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Status).HasDefaultValue("DRAFT");
            entity.Property(e => e.Timezone).HasDefaultValue("Asia/Ho_Chi_Minh");

            entity.HasOne(d => d.ClassSection).WithMany(p => p.ScheduleEvents)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ScheduleEvents_ClassSection");

            entity.HasOne(d => d.CreatedByNavigation).WithMany(p => p.ScheduleEventCreatedByNavigations)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ScheduleEvents_CreatedBy");

            entity.HasOne(d => d.Recurrence).WithMany(p => p.ScheduleEvents).HasConstraintName("FK_ScheduleEvents_Recurrence");

            entity.HasOne(d => d.Teacher).WithMany(p => p.ScheduleEvents).HasConstraintName("FK_ScheduleEvents_Teacher");

            entity.HasOne(d => d.UpdatedByNavigation).WithMany(p => p.ScheduleEventUpdatedByNavigations).HasConstraintName("FK_ScheduleEvents_UpdatedBy");
        });

        modelBuilder.Entity<ScheduleEventOverride>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.NewTeacher).WithMany(p => p.ScheduleEventOverrides).HasConstraintName("FK_ScheduleEventOverrides_Teacher");

            entity.HasOne(d => d.Recurrence).WithMany(p => p.ScheduleEventOverrides)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ScheduleEventOverrides_Recurrence");
        });

        modelBuilder.Entity<Semester>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.MaxCredits).HasDefaultValue(16);
            entity.Property(e => e.MinCredits).HasDefaultValue(8);
        });

        modelBuilder.Entity<Student>(entity =>
        {
            entity.Property(e => e.StudentId).ValueGeneratedNever();
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.CurrentSemester).WithMany(p => p.Students).HasConstraintName("FK_Students_CurrentSemester");

            entity.HasOne(d => d.Program).WithMany(p => p.Students).HasConstraintName("FK_Students_Programs");

            entity.HasOne(d => d.StudentNavigation).WithOne(p => p.Student)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Students_Users");
        });

        modelBuilder.Entity<StudentWallet>(entity =>
        {
            entity.Property(e => e.LastUpdated).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.WalletStatus).HasDefaultValue("ACTIVE");

            entity.HasOne(d => d.Student).WithOne(p => p.StudentWallet)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_StudentWallets_Students");
        });

        modelBuilder.Entity<Teacher>(entity =>
        {
            entity.Property(e => e.TeacherId).ValueGeneratedNever();
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.TeacherNavigation).WithOne(p => p.Teacher)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Teachers_Users");
        });

        modelBuilder.Entity<TuitionFee>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Status).HasDefaultValue("UNPAID");

            entity.HasOne(d => d.Semester).WithMany(p => p.TuitionFees)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_TuitionFees_Semesters");

            entity.HasOne(d => d.Student).WithMany(p => p.TuitionFees)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_TuitionFees_Students");
        });

        modelBuilder.Entity<User>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.IsActive).HasDefaultValue(true);
        });

        modelBuilder.Entity<WalletTransaction>(entity =>
        {
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.RelatedFee).WithMany(p => p.WalletTransactions).HasConstraintName("FK_WalletTransactions_Fee");

            entity.HasOne(d => d.RelatedPayment).WithMany(p => p.WalletTransactions).HasConstraintName("FK_WalletTransactions_Payment");

            entity.HasOne(d => d.Wallet).WithMany(p => p.WalletTransactions)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_WalletTransactions_Wallet");
        });

        modelBuilder.Entity<vw_ClassSectionSummary>(entity =>
        {
            entity.ToView("vw_ClassSectionSummary");
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
