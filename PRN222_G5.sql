/*
PRN222_G5.sql
Database: SQL Server (Database First) for School Management (Student/Teacher/Admin)
Generated from Ass01.docx functional spec.
Notes:
- Default database name: SchoolManagementDb (change as needed).
- Enums are enforced via CHECK constraints.
- Some complex constraints (time conflict, prerequisite satisfaction, credit max) are enforced in application logic.
*/

SET NOCOUNT ON;
GO

/* ===== Create database ===== */
IF DB_ID(N'SchoolManagementDb') IS NULL
BEGIN
    CREATE DATABASE [SchoolManagementDb];
END
GO

USE [SchoolManagementDb];
GO

/* ===== Basic settings ===== */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ===== Drop tables (optional for re-run) =====
   Uncomment if you want to recreate from scratch.

-- DROP TABLE in reverse dependency order
*/

/* =========================
   1) Identity & Core catalog
   ========================= */

CREATE TABLE dbo.Users (
    UserId          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
    Username        NVARCHAR(100) NOT NULL,
    PasswordHash    NVARCHAR(255) NOT NULL, -- BCrypt hash
    Email           NVARCHAR(255) NULL,
    FullName        NVARCHAR(200) NOT NULL,
    Role            NVARCHAR(20) NOT NULL,  -- STUDENT | TEACHER | ADMIN
    IsActive        BIT NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
    CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt       DATETIME2(0) NULL
);
GO

ALTER TABLE dbo.Users
ADD CONSTRAINT UQ_Users_Username UNIQUE (Username);
GO

ALTER TABLE dbo.Users
ADD CONSTRAINT CK_Users_Role CHECK (Role IN (N'STUDENT', N'TEACHER', N'ADMIN'));
GO

CREATE TABLE dbo.Programs (
    ProgramId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Programs PRIMARY KEY,
    ProgramCode NVARCHAR(50) NOT NULL,
    ProgramName NVARCHAR(200) NOT NULL,
    IsActive    BIT NOT NULL CONSTRAINT DF_Programs_IsActive DEFAULT (1)
);
GO

ALTER TABLE dbo.Programs
ADD CONSTRAINT UQ_Programs_ProgramCode UNIQUE (ProgramCode);
GO

CREATE TABLE dbo.Semesters (
    SemesterId           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Semesters PRIMARY KEY,
    SemesterCode         NVARCHAR(50) NOT NULL,
    SemesterName         NVARCHAR(200) NOT NULL,
    StartDate            DATE NOT NULL,
    EndDate              DATE NOT NULL,
    IsActive             BIT NOT NULL CONSTRAINT DF_Semesters_IsActive DEFAULT (0),

    -- Registration windows / rules (from spec)
    RegistrationEndDate  DATE NULL,
    AddDropDeadline      DATE NULL,
    WithdrawalDeadline   DATE NULL,
    MaxCredits           INT NOT NULL CONSTRAINT DF_Semesters_MaxCredits DEFAULT (16),
    MinCredits           INT NOT NULL CONSTRAINT DF_Semesters_MinCredits DEFAULT (8),

    CreatedAt            DATETIME2(0) NOT NULL CONSTRAINT DF_Semesters_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.Semesters
ADD CONSTRAINT UQ_Semesters_SemesterCode UNIQUE (SemesterCode);
GO

ALTER TABLE dbo.Semesters
ADD CONSTRAINT CK_Semesters_DateRange CHECK (EndDate >= StartDate);
GO

CREATE TABLE dbo.Students (
    StudentId        INT NOT NULL CONSTRAINT PK_Students PRIMARY KEY, -- FK to Users(UserId)
    StudentCode      NVARCHAR(50) NOT NULL,
    ProgramId        INT NULL,
    CurrentSemesterId INT NULL,
    CreatedAt        DATETIME2(0) NOT NULL CONSTRAINT DF_Students_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.Students
ADD CONSTRAINT FK_Students_Users FOREIGN KEY (StudentId) REFERENCES dbo.Users(UserId);
GO

ALTER TABLE dbo.Students
ADD CONSTRAINT FK_Students_Programs FOREIGN KEY (ProgramId) REFERENCES dbo.Programs(ProgramId);
GO

ALTER TABLE dbo.Students
ADD CONSTRAINT FK_Students_CurrentSemester FOREIGN KEY (CurrentSemesterId) REFERENCES dbo.Semesters(SemesterId);
GO

ALTER TABLE dbo.Students
ADD CONSTRAINT UQ_Students_StudentCode UNIQUE (StudentCode);
GO

CREATE TABLE dbo.Teachers (
    TeacherId    INT NOT NULL CONSTRAINT PK_Teachers PRIMARY KEY, -- FK to Users(UserId)
    TeacherCode  NVARCHAR(50) NOT NULL,
    Department   NVARCHAR(200) NULL,
    CreatedAt    DATETIME2(0) NOT NULL CONSTRAINT DF_Teachers_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.Teachers
ADD CONSTRAINT FK_Teachers_Users FOREIGN KEY (TeacherId) REFERENCES dbo.Users(UserId);
GO

ALTER TABLE dbo.Teachers
ADD CONSTRAINT UQ_Teachers_TeacherCode UNIQUE (TeacherCode);
GO

CREATE TABLE dbo.Courses (
    CourseId         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Courses PRIMARY KEY,
    CourseCode       NVARCHAR(50) NOT NULL,
    CourseName       NVARCHAR(200) NOT NULL,
    Credits          INT NOT NULL,
    Description      NVARCHAR(MAX) NULL,
    ContentHtml      NVARCHAR(MAX) NULL,      -- course content (optional)
    LearningPathJson NVARCHAR(MAX) NULL,      -- learning path (optional, JSON)
    IsActive         BIT NOT NULL CONSTRAINT DF_Courses_IsActive DEFAULT (1),
    CreatedAt        DATETIME2(0) NOT NULL CONSTRAINT DF_Courses_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.Courses
ADD CONSTRAINT UQ_Courses_CourseCode UNIQUE (CourseCode);
GO

ALTER TABLE dbo.Courses
ADD CONSTRAINT CK_Courses_Credits CHECK (Credits > 0 AND Credits <= 10);
GO

CREATE TABLE dbo.CoursePrerequisites (
    CourseId             INT NOT NULL,
    PrerequisiteCourseId INT NOT NULL,
    CONSTRAINT PK_CoursePrerequisites PRIMARY KEY (CourseId, PrerequisiteCourseId)
);
GO

ALTER TABLE dbo.CoursePrerequisites
ADD CONSTRAINT FK_CoursePrerequisites_Course FOREIGN KEY (CourseId) REFERENCES dbo.Courses(CourseId);
GO
ALTER TABLE dbo.CoursePrerequisites
ADD CONSTRAINT FK_CoursePrerequisites_Prereq FOREIGN KEY (PrerequisiteCourseId) REFERENCES dbo.Courses(CourseId);
GO

ALTER TABLE dbo.CoursePrerequisites
ADD CONSTRAINT CK_CoursePrerequisites_NoSelf CHECK (CourseId <> PrerequisiteCourseId);
GO

/* =========================
   2) Class sections & Enrollment
   ========================= */

CREATE TABLE dbo.ClassSections (
    ClassSectionId     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ClassSections PRIMARY KEY,
    SemesterId         INT NOT NULL,
    CourseId           INT NOT NULL,
    TeacherId          INT NOT NULL,
    SectionCode        NVARCHAR(50) NOT NULL,      -- e.g. CS101-01
    IsOpen             BIT NOT NULL CONSTRAINT DF_ClassSections_IsOpen DEFAULT (1),
    MaxCapacity        INT NOT NULL CONSTRAINT DF_ClassSections_MaxCapacity DEFAULT (30),
    CurrentEnrollment  INT NOT NULL CONSTRAINT DF_ClassSections_CurrentEnrollment DEFAULT (0),
    Room               NVARCHAR(100) NULL,
    OnlineUrl          NVARCHAR(500) NULL,
    Notes              NVARCHAR(MAX) NULL,
    CreatedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_ClassSections_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.ClassSections
ADD CONSTRAINT FK_ClassSections_Semesters FOREIGN KEY (SemesterId) REFERENCES dbo.Semesters(SemesterId);
GO
ALTER TABLE dbo.ClassSections
ADD CONSTRAINT FK_ClassSections_Courses FOREIGN KEY (CourseId) REFERENCES dbo.Courses(CourseId);
GO
ALTER TABLE dbo.ClassSections
ADD CONSTRAINT FK_ClassSections_Teachers FOREIGN KEY (TeacherId) REFERENCES dbo.Teachers(TeacherId);
GO

ALTER TABLE dbo.ClassSections
ADD CONSTRAINT UQ_ClassSections_Sem_Course_Section UNIQUE (SemesterId, CourseId, SectionCode);
GO

ALTER TABLE dbo.ClassSections
ADD CONSTRAINT CK_ClassSections_Capacity CHECK (MaxCapacity > 0 AND CurrentEnrollment >= 0 AND CurrentEnrollment <= MaxCapacity);
GO

CREATE TABLE dbo.Enrollments (
    EnrollmentId    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Enrollments PRIMARY KEY,
    StudentId       INT NOT NULL,
    ClassSectionId  INT NOT NULL,

    -- Denormalized keys for enforceable constraints & reporting
    SemesterId      INT NOT NULL,
    CourseId        INT NOT NULL,
    CreditsSnapshot INT NOT NULL,

    Status          NVARCHAR(20) NOT NULL,  -- ENROLLED | WAITLIST | DROPPED | WITHDRAWN | COMPLETED | CANCELED
    EnrolledAt      DATETIME2(0) NOT NULL CONSTRAINT DF_Enrollments_EnrolledAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt       DATETIME2(0) NULL
);
GO

ALTER TABLE dbo.Enrollments
ADD CONSTRAINT FK_Enrollments_Students FOREIGN KEY (StudentId) REFERENCES dbo.Students(StudentId);
GO
ALTER TABLE dbo.Enrollments
ADD CONSTRAINT FK_Enrollments_ClassSections FOREIGN KEY (ClassSectionId) REFERENCES dbo.ClassSections(ClassSectionId);
GO
ALTER TABLE dbo.Enrollments
ADD CONSTRAINT FK_Enrollments_Semesters FOREIGN KEY (SemesterId) REFERENCES dbo.Semesters(SemesterId);
GO
ALTER TABLE dbo.Enrollments
ADD CONSTRAINT FK_Enrollments_Courses FOREIGN KEY (CourseId) REFERENCES dbo.Courses(CourseId);
GO

ALTER TABLE dbo.Enrollments
ADD CONSTRAINT CK_Enrollments_Status CHECK (Status IN (N'ENROLLED', N'WAITLIST', N'DROPPED', N'WITHDRAWN', N'COMPLETED', N'CANCELED'));
GO

ALTER TABLE dbo.Enrollments
ADD CONSTRAINT CK_Enrollments_CreditsSnapshot CHECK (CreditsSnapshot > 0 AND CreditsSnapshot <= 10);
GO

/* Anti-duplicate: one student cannot be ENROLLED or WITHDRAWN for same Course in same Semester */
CREATE UNIQUE INDEX UX_Enrollments_Student_Course_Sem_Active
ON dbo.Enrollments(StudentId, CourseId, SemesterId)
WHERE Status IN (N'ENROLLED', N'WITHDRAWN');
GO

CREATE INDEX IX_Enrollments_ClassSection ON dbo.Enrollments(ClassSectionId);
GO

/* =========================
   3) Gradebook
   ========================= */

CREATE TABLE dbo.GradeBooks (
    GradeBookId    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GradeBooks PRIMARY KEY,
    ClassSectionId INT NOT NULL,
    Status         NVARCHAR(20) NOT NULL CONSTRAINT DF_GradeBooks_Status DEFAULT (N'DRAFT'), -- DRAFT|PUBLISHED|LOCKED|ARCHIVED
    Version        INT NOT NULL CONSTRAINT DF_GradeBooks_Version DEFAULT (1),
    PublishedAt    DATETIME2(0) NULL,
    LockedAt       DATETIME2(0) NULL,
    CreatedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_GradeBooks_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt      DATETIME2(0) NULL
);
GO

ALTER TABLE dbo.GradeBooks
ADD CONSTRAINT FK_GradeBooks_ClassSections FOREIGN KEY (ClassSectionId) REFERENCES dbo.ClassSections(ClassSectionId);
GO

ALTER TABLE dbo.GradeBooks
ADD CONSTRAINT UQ_GradeBooks_ClassSection UNIQUE (ClassSectionId);
GO

ALTER TABLE dbo.GradeBooks
ADD CONSTRAINT CK_GradeBooks_Status CHECK (Status IN (N'DRAFT', N'PUBLISHED', N'LOCKED', N'ARCHIVED'));
GO

-- Bảng lưu lịch sử yêu cầu/duyệt (Optional nhưng recommend)
CREATE TABLE dbo.GradeBookApprovals (
    ApprovalId INT IDENTITY(1,1) PRIMARY KEY,
    GradeBookId INT NOT NULL,
    RequestBy INT NOT NULL, -- Teacher
    RequestAt DATETIME2(0) DEFAULT SYSUTCDATETIME(),
    RequestMessage NVARCHAR(500),
    
    ResponseBy INT NULL, -- Admin
    ResponseAt DATETIME2(0) NULL,
    ResponseMessage NVARCHAR(500), -- Lý do reject
    Outcome NVARCHAR(20) NULL -- APPROVED / REJECTED
);

CREATE TABLE dbo.GradeItems (
    GradeItemId    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GradeItems PRIMARY KEY,
    GradeBookId    INT NOT NULL,
    ItemName       NVARCHAR(200) NOT NULL,        -- e.g. Quiz 1
    MaxScore       DECIMAL(5,2) NOT NULL CONSTRAINT DF_GradeItems_MaxScore DEFAULT (10.00),
    Weight         DECIMAL(6,4) NULL,             -- e.g. 0.2000 (20%). NULL = not weighted/standalone
    IsRequired     BIT NOT NULL CONSTRAINT DF_GradeItems_IsRequired DEFAULT (0),
    SortOrder      INT NOT NULL CONSTRAINT DF_GradeItems_SortOrder DEFAULT (0),
    CreatedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_GradeItems_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.GradeItems
ADD CONSTRAINT FK_GradeItems_GradeBooks FOREIGN KEY (GradeBookId) REFERENCES dbo.GradeBooks(GradeBookId);
GO

ALTER TABLE dbo.GradeItems
ADD CONSTRAINT CK_GradeItems_MaxScore CHECK (MaxScore > 0 AND MaxScore <= 100);
GO

ALTER TABLE dbo.GradeItems
ADD CONSTRAINT CK_GradeItems_Weight CHECK (Weight IS NULL OR (Weight >= 0 AND Weight <= 1));
GO

CREATE TABLE dbo.GradeEntries (
    GradeEntryId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GradeEntries PRIMARY KEY,
    GradeItemId    INT NOT NULL,
    EnrollmentId   INT NOT NULL,
    Score          DECIMAL(5,2) NULL,             -- NULL = not graded
    UpdatedBy      INT NULL,                      -- Users(UserId)
    UpdatedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_GradeEntries_UpdatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.GradeEntries
ADD CONSTRAINT FK_GradeEntries_GradeItems FOREIGN KEY (GradeItemId) REFERENCES dbo.GradeItems(GradeItemId);
GO

ALTER TABLE dbo.GradeEntries
ADD CONSTRAINT FK_GradeEntries_Enrollments FOREIGN KEY (EnrollmentId) REFERENCES dbo.Enrollments(EnrollmentId);
GO

ALTER TABLE dbo.GradeEntries
ADD CONSTRAINT FK_GradeEntries_UpdatedBy FOREIGN KEY (UpdatedBy) REFERENCES dbo.Users(UserId);
GO

ALTER TABLE dbo.GradeEntries
ADD CONSTRAINT CK_GradeEntries_Score CHECK (Score IS NULL OR (Score >= 0 AND Score <= 10));
GO

ALTER TABLE dbo.GradeEntries
ADD CONSTRAINT UQ_GradeEntries_Item_Enrollment UNIQUE (GradeItemId, EnrollmentId);
GO

CREATE TABLE dbo.GradeAuditLogs (
    GradeAuditLogId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GradeAuditLogs PRIMARY KEY,
    GradeEntryId    INT NOT NULL,
    ActorUserId     INT NOT NULL,
    OldScore        DECIMAL(5,2) NULL,
    NewScore        DECIMAL(5,2) NULL,
    Reason          NVARCHAR(500) NULL,
    CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_GradeAuditLogs_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.GradeAuditLogs
ADD CONSTRAINT FK_GradeAuditLogs_GradeEntries FOREIGN KEY (GradeEntryId) REFERENCES dbo.GradeEntries(GradeEntryId);
GO
ALTER TABLE dbo.GradeAuditLogs
ADD CONSTRAINT FK_GradeAuditLogs_Actor FOREIGN KEY (ActorUserId) REFERENCES dbo.Users(UserId);
GO

/* =========================
   4) Chat (SignalR realtime)
   ========================= */

CREATE TABLE dbo.ChatRooms (
    RoomId         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ChatRooms PRIMARY KEY,
    RoomType       NVARCHAR(20) NOT NULL,         -- COURSE | CLASS | GROUP | DM
    CourseId       INT NULL,
    ClassSectionId INT NULL,
    RoomName       NVARCHAR(200) NOT NULL,
    Status         NVARCHAR(20) NOT NULL CONSTRAINT DF_ChatRooms_Status DEFAULT (N'ACTIVE'), -- ACTIVE|LOCKED|ARCHIVED|DELETED
    CreatedBy      INT NOT NULL,
    CreatedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_ChatRooms_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.ChatRooms
ADD CONSTRAINT FK_ChatRooms_Courses FOREIGN KEY (CourseId) REFERENCES dbo.Courses(CourseId);
GO
ALTER TABLE dbo.ChatRooms
ADD CONSTRAINT FK_ChatRooms_ClassSections FOREIGN KEY (ClassSectionId) REFERENCES dbo.ClassSections(ClassSectionId);
GO
ALTER TABLE dbo.ChatRooms
ADD CONSTRAINT FK_ChatRooms_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(UserId);
GO

ALTER TABLE dbo.ChatRooms
ADD CONSTRAINT CK_ChatRooms_RoomType CHECK (RoomType IN (N'COURSE', N'CLASS', N'GROUP', N'DM'));
GO
ALTER TABLE dbo.ChatRooms
ADD CONSTRAINT CK_ChatRooms_Status CHECK (Status IN (N'ACTIVE', N'LOCKED', N'ARCHIVED', N'DELETED'));
GO

CREATE TABLE dbo.ChatRoomMembers (
    RoomId          INT NOT NULL,
    UserId          INT NOT NULL,
    RoleInRoom      NVARCHAR(20) NOT NULL CONSTRAINT DF_ChatRoomMembers_Role DEFAULT (N'MEMBER'), -- MEMBER|MODERATOR|OWNER
    MemberStatus    NVARCHAR(20) NOT NULL CONSTRAINT DF_ChatRoomMembers_Status DEFAULT (N'JOINED'), -- JOINED|MUTED|READ_ONLY|BANNED|REMOVED
    LastReadMessageId BIGINT NULL,
    JoinedAt        DATETIME2(0) NOT NULL CONSTRAINT DF_ChatRoomMembers_JoinedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_ChatRoomMembers PRIMARY KEY (RoomId, UserId)
);
GO

ALTER TABLE dbo.ChatRoomMembers
ADD CONSTRAINT FK_ChatRoomMembers_Room FOREIGN KEY (RoomId) REFERENCES dbo.ChatRooms(RoomId);
GO
ALTER TABLE dbo.ChatRoomMembers
ADD CONSTRAINT FK_ChatRoomMembers_User FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId);
GO

ALTER TABLE dbo.ChatRoomMembers
ADD CONSTRAINT CK_ChatRoomMembers_Role CHECK (RoleInRoom IN (N'MEMBER', N'MODERATOR', N'OWNER'));
GO
ALTER TABLE dbo.ChatRoomMembers
ADD CONSTRAINT CK_ChatRoomMembers_Status CHECK (MemberStatus IN (N'JOINED', N'MUTED', N'READ_ONLY', N'BANNED', N'REMOVED'));
GO

CREATE TABLE dbo.ChatMessages (
    MessageId      BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ChatMessages PRIMARY KEY,
    RoomId         INT NOT NULL,
    SenderId       INT NOT NULL,
    MessageType    NVARCHAR(20) NOT NULL CONSTRAINT DF_ChatMessages_Type DEFAULT (N'TEXT'), -- TEXT|SYSTEM
    Content        NVARCHAR(MAX) NULL,
    CreatedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_ChatMessages_CreatedAt DEFAULT (SYSUTCDATETIME()),
    EditedAt       DATETIME2(0) NULL,
    DeletedAt      DATETIME2(0) NULL
);
GO

ALTER TABLE dbo.ChatMessages
ADD CONSTRAINT FK_ChatMessages_Room FOREIGN KEY (RoomId) REFERENCES dbo.ChatRooms(RoomId);
GO
ALTER TABLE dbo.ChatMessages
ADD CONSTRAINT FK_ChatMessages_Sender FOREIGN KEY (SenderId) REFERENCES dbo.Users(UserId);
GO

ALTER TABLE dbo.ChatMessages
ADD CONSTRAINT CK_ChatMessages_Type CHECK (MessageType IN (N'TEXT', N'SYSTEM'));
GO

CREATE INDEX IX_ChatMessages_Room_CreatedAt ON dbo.ChatMessages(RoomId, CreatedAt DESC);
GO

CREATE TABLE dbo.ChatMessageAttachments (
    AttachmentId   BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ChatMessageAttachments PRIMARY KEY,
    MessageId      BIGINT NOT NULL,
    FileUrl        NVARCHAR(1000) NOT NULL,
    FileType       NVARCHAR(100) NOT NULL,
    FileSizeBytes  BIGINT NULL,
    CreatedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_ChatMessageAttachments_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.ChatMessageAttachments
ADD CONSTRAINT FK_ChatMessageAttachments_Message FOREIGN KEY (MessageId) REFERENCES dbo.ChatMessages(MessageId);
GO

CREATE TABLE dbo.ChatModerationLogs (
    ModerationLogId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ChatModerationLogs PRIMARY KEY,
    RoomId          INT NOT NULL,
    ActorUserId     INT NOT NULL,
    Action          NVARCHAR(50) NOT NULL,         -- LOCK|UNLOCK|REMOVE_MEMBER|DELETE_MESSAGE|REPORT
    TargetUserId    INT NULL,
    TargetMessageId BIGINT NULL,
    MetadataJson    NVARCHAR(MAX) NULL,
    CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_ChatModerationLogs_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.ChatModerationLogs
ADD CONSTRAINT FK_ChatModerationLogs_Room FOREIGN KEY (RoomId) REFERENCES dbo.ChatRooms(RoomId);
GO
ALTER TABLE dbo.ChatModerationLogs
ADD CONSTRAINT FK_ChatModerationLogs_Actor FOREIGN KEY (ActorUserId) REFERENCES dbo.Users(UserId);
GO
ALTER TABLE dbo.ChatModerationLogs
ADD CONSTRAINT FK_ChatModerationLogs_TargetUser FOREIGN KEY (TargetUserId) REFERENCES dbo.Users(UserId);
GO
ALTER TABLE dbo.ChatModerationLogs
ADD CONSTRAINT FK_ChatModerationLogs_TargetMessage FOREIGN KEY (TargetMessageId) REFERENCES dbo.ChatMessages(MessageId);
GO

/* =========================
   5) Calendar / schedule
   ========================= */

CREATE TABLE dbo.Recurrences (
    RecurrenceId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Recurrences PRIMARY KEY,
    RRule        NVARCHAR(500) NOT NULL, -- iCal RRULE
    StartDate    DATE NOT NULL,
    EndDate      DATE NOT NULL,
    CreatedAt    DATETIME2(0) NOT NULL CONSTRAINT DF_Recurrences_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.Recurrences
ADD CONSTRAINT CK_Recurrences_DateRange CHECK (EndDate >= StartDate);
GO

CREATE TABLE dbo.ScheduleEvents (
    ScheduleEventId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ScheduleEvents PRIMARY KEY,
    ClassSectionId  INT NOT NULL,
    Title           NVARCHAR(200) NOT NULL,
    StartAt         DATETIME2(0) NOT NULL,         -- stored in UTC recommended
    EndAt           DATETIME2(0) NOT NULL,
    Timezone        NVARCHAR(100) NOT NULL CONSTRAINT DF_ScheduleEvents_Timezone DEFAULT (N'Asia/Ho_Chi_Minh'),
    Location        NVARCHAR(200) NULL,
    OnlineUrl       NVARCHAR(500) NULL,
    TeacherId       INT NULL,                      -- can override section teacher
    Status          NVARCHAR(20) NOT NULL CONSTRAINT DF_ScheduleEvents_Status DEFAULT (N'DRAFT'), -- DRAFT|PUBLISHED|RESCHEDULED|CANCELLED|COMPLETED|ARCHIVED
    RecurrenceId    INT NULL,
    CreatedBy       INT NOT NULL,
    UpdatedBy       INT NULL,
    CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_ScheduleEvents_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt       DATETIME2(0) NULL
);
GO

ALTER TABLE dbo.ScheduleEvents
ADD CONSTRAINT FK_ScheduleEvents_ClassSection FOREIGN KEY (ClassSectionId) REFERENCES dbo.ClassSections(ClassSectionId);
GO
ALTER TABLE dbo.ScheduleEvents
ADD CONSTRAINT FK_ScheduleEvents_Recurrence FOREIGN KEY (RecurrenceId) REFERENCES dbo.Recurrences(RecurrenceId);
GO
ALTER TABLE dbo.ScheduleEvents
ADD CONSTRAINT FK_ScheduleEvents_Teacher FOREIGN KEY (TeacherId) REFERENCES dbo.Teachers(TeacherId);
GO
ALTER TABLE dbo.ScheduleEvents
ADD CONSTRAINT FK_ScheduleEvents_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(UserId);
GO
ALTER TABLE dbo.ScheduleEvents
ADD CONSTRAINT FK_ScheduleEvents_UpdatedBy FOREIGN KEY (UpdatedBy) REFERENCES dbo.Users(UserId);
GO

ALTER TABLE dbo.ScheduleEvents
ADD CONSTRAINT CK_ScheduleEvents_Time CHECK (EndAt > StartAt);
GO

ALTER TABLE dbo.ScheduleEvents
ADD CONSTRAINT CK_ScheduleEvents_Status CHECK (Status IN (N'DRAFT', N'PUBLISHED', N'RESCHEDULED', N'CANCELLED', N'COMPLETED', N'ARCHIVED'));
GO

CREATE INDEX IX_ScheduleEvents_ClassSection_StartAt ON dbo.ScheduleEvents(ClassSectionId, StartAt);
GO

CREATE TABLE dbo.ScheduleEventOverrides (
    OverrideId      BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ScheduleEventOverrides PRIMARY KEY,
    RecurrenceId    INT NOT NULL,
    OriginalDate    DATE NOT NULL,
    OverrideType    NVARCHAR(20) NOT NULL,         -- RESCHEDULE|CANCEL
    NewStartAt      DATETIME2(0) NULL,
    NewEndAt        DATETIME2(0) NULL,
    NewLocation     NVARCHAR(200) NULL,
    NewTeacherId    INT NULL,
    Reason          NVARCHAR(500) NULL,
    CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_ScheduleEventOverrides_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.ScheduleEventOverrides
ADD CONSTRAINT FK_ScheduleEventOverrides_Recurrence FOREIGN KEY (RecurrenceId) REFERENCES dbo.Recurrences(RecurrenceId);
GO
ALTER TABLE dbo.ScheduleEventOverrides
ADD CONSTRAINT FK_ScheduleEventOverrides_Teacher FOREIGN KEY (NewTeacherId) REFERENCES dbo.Teachers(TeacherId);
GO

ALTER TABLE dbo.ScheduleEventOverrides
ADD CONSTRAINT CK_ScheduleEventOverrides_Type CHECK (OverrideType IN (N'RESCHEDULE', N'CANCEL'));
GO

CREATE TABLE dbo.ScheduleChangeLogs (
    ChangeLogId     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ScheduleChangeLogs PRIMARY KEY,
    ScheduleEventId BIGINT NOT NULL,
    ActorUserId     INT NOT NULL,
    ChangeType      NVARCHAR(50) NOT NULL,         -- CREATE|UPDATE|CANCEL|PUBLISH|LOCK
    OldJson         NVARCHAR(MAX) NULL,
    NewJson         NVARCHAR(MAX) NULL,
    Reason          NVARCHAR(500) NULL,
    CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_ScheduleChangeLogs_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.ScheduleChangeLogs
ADD CONSTRAINT FK_ScheduleChangeLogs_Event FOREIGN KEY (ScheduleEventId) REFERENCES dbo.ScheduleEvents(ScheduleEventId);
GO
ALTER TABLE dbo.ScheduleChangeLogs
ADD CONSTRAINT FK_ScheduleChangeLogs_Actor FOREIGN KEY (ActorUserId) REFERENCES dbo.Users(UserId);
GO

/* =========================
   6) Notifications
   ========================= */

CREATE TABLE dbo.Notifications (
    NotificationId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Notifications PRIMARY KEY,
    NotificationType NVARCHAR(50) NOT NULL,        -- SCHEDULE_CHANGED|GRADE_PUBLISHED|CHAT_MENTION|...
    PayloadJson     NVARCHAR(MAX) NOT NULL,
    Status          NVARCHAR(20) NOT NULL CONSTRAINT DF_Notifications_Status DEFAULT (N'PENDING'), -- PENDING|SENT|DELIVERED
    CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_Notifications_CreatedAt DEFAULT (SYSUTCDATETIME()),
    SentAt          DATETIME2(0) NULL
);
GO

ALTER TABLE dbo.Notifications
ADD CONSTRAINT CK_Notifications_Status CHECK (Status IN (N'PENDING', N'SENT', N'DELIVERED'));
GO

CREATE TABLE dbo.NotificationRecipients (
    NotificationId BIGINT NOT NULL,
    UserId         INT NOT NULL,
    DeliveredAt    DATETIME2(0) NULL,
    ReadAt         DATETIME2(0) NULL,
    CONSTRAINT PK_NotificationRecipients PRIMARY KEY (NotificationId, UserId)
);
GO

ALTER TABLE dbo.NotificationRecipients
ADD CONSTRAINT FK_NotificationRecipients_Notification FOREIGN KEY (NotificationId) REFERENCES dbo.Notifications(NotificationId);
GO
ALTER TABLE dbo.NotificationRecipients
ADD CONSTRAINT FK_NotificationRecipients_User FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId);
GO

/* =========================
   7) AI Chatbot (logs & audit)
   ========================= */

CREATE TABLE dbo.AIChatSessions (
    ChatSessionId  BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AIChatSessions PRIMARY KEY,
    UserId         INT NOT NULL,
    Purpose        NVARCHAR(50) NOT NULL,          -- SCORE_SUMMARY|STUDY_PLAN|COURSE_SUGGESTION
    ModelName      NVARCHAR(100) NULL,             -- e.g. gemini-...
    State          NVARCHAR(30) NOT NULL CONSTRAINT DF_AIChatSessions_State DEFAULT (N'ACTIVE'),
    PromptVersion  NVARCHAR(50) NULL,
    CreatedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_AIChatSessions_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CompletedAt    DATETIME2(0) NULL
);
GO

ALTER TABLE dbo.AIChatSessions
ADD CONSTRAINT FK_AIChatSessions_User FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId);
GO

CREATE TABLE dbo.AIChatMessages (
    ChatMessageId  BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AIChatMessages PRIMARY KEY,
    ChatSessionId  BIGINT NOT NULL,
    SenderType     NVARCHAR(20) NOT NULL,          -- USER|ASSISTANT|SYSTEM
    Content        NVARCHAR(MAX) NOT NULL,
    CreatedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_AIChatMessages_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.AIChatMessages
ADD CONSTRAINT FK_AIChatMessages_Session FOREIGN KEY (ChatSessionId) REFERENCES dbo.AIChatSessions(ChatSessionId);
GO
ALTER TABLE dbo.AIChatMessages
ADD CONSTRAINT CK_AIChatMessages_SenderType CHECK (SenderType IN (N'USER', N'ASSISTANT', N'SYSTEM'));
GO

CREATE TABLE dbo.AIToolCalls (
    ToolCallId     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AIToolCalls PRIMARY KEY,
    ChatSessionId  BIGINT NOT NULL,
    ToolName       NVARCHAR(200) NOT NULL,
    RequestJson    NVARCHAR(MAX) NOT NULL,
    ResponseJson   NVARCHAR(MAX) NULL,
    Status         NVARCHAR(20) NOT NULL CONSTRAINT DF_AIToolCalls_Status DEFAULT (N'OK'), -- OK|ERROR
    CreatedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_AIToolCalls_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.AIToolCalls
ADD CONSTRAINT FK_AIToolCalls_Session FOREIGN KEY (ChatSessionId) REFERENCES dbo.AIChatSessions(ChatSessionId);
GO

ALTER TABLE dbo.AIToolCalls
ADD CONSTRAINT CK_AIToolCalls_Status CHECK (Status IN (N'OK', N'ERROR'));
GO

/* =========================
   8) Helpful views (optional)
   ========================= */

CREATE VIEW dbo.vw_ClassSectionSummary
AS
SELECT
    cs.ClassSectionId,
    cs.SectionCode,
    s.SemesterCode,
    c.CourseCode,
    c.CourseName,
    c.Credits,
    cs.IsOpen,
    cs.CurrentEnrollment,
    cs.MaxCapacity,
    u.FullName AS TeacherFullName
FROM dbo.ClassSections cs
JOIN dbo.Semesters s ON s.SemesterId = cs.SemesterId
JOIN dbo.Courses c ON c.CourseId = cs.CourseId
JOIN dbo.Teachers t ON t.TeacherId = cs.TeacherId
JOIN dbo.Users u ON u.UserId = t.TeacherId;
GO
--===========================QUIZZ test ====================================--
CREATE TABLE dbo.Quizzes (
    QuizId INT IDENTITY(1,1) PRIMARY KEY,
    ClassSectionId INT NOT NULL,
    CreatedBy INT NOT NULL,
    QuizTitle NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    TotalQuestions INT NOT NULL,
    TimeLimitMin INT NULL,
    ShuffleQuestions BIT NOT NULL DEFAULT 1,
    ShuffleAnswers BIT NOT NULL DEFAULT 1,
    StartAt DATETIME2(0) NULL,
    EndAt DATETIME2(0) NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

ALTER TABLE dbo.Quizzes
ADD CONSTRAINT FK_Quizzes_ClassSection FOREIGN KEY (ClassSectionId)
REFERENCES dbo.ClassSections(ClassSectionId);

ALTER TABLE dbo.Quizzes
ADD CONSTRAINT FK_Quizzes_CreatedBy FOREIGN KEY (CreatedBy)
REFERENCES dbo.Users(UserId);

ALTER TABLE dbo.Quizzes
ADD CONSTRAINT CK_Quizzes_TotalQuestions CHECK (TotalQuestions IN (10,20,30));

ALTER TABLE dbo.Quizzes
ADD CONSTRAINT CK_Quizzes_Status CHECK (Status IN ('DRAFT','PUBLISHED','CLOSED'));
GO


--=========================================
CREATE TABLE dbo.QuizQuestions (
    QuestionId INT IDENTITY(1,1) PRIMARY KEY,
    QuizId INT NOT NULL,
    QuestionText NVARCHAR(MAX) NOT NULL,
    QuestionType NVARCHAR(20) NOT NULL DEFAULT 'MCQ',
    Points DECIMAL(5,2) NOT NULL DEFAULT 1,
    SortOrder INT NOT NULL DEFAULT 0
);
GO

ALTER TABLE dbo.QuizQuestions
ADD CONSTRAINT FK_QuizQuestions_Quiz FOREIGN KEY (QuizId)
REFERENCES dbo.Quizzes(QuizId);

ALTER TABLE dbo.QuizQuestions
ADD CONSTRAINT CK_QuizQuestions_Type CHECK (QuestionType IN ('MCQ','TRUE_FALSE'));
GO
--======================
CREATE TABLE dbo.QuizAnswers (
    AnswerId INT IDENTITY(1,1) PRIMARY KEY,
    QuestionId INT NOT NULL,
    AnswerText NVARCHAR(1000) NOT NULL,
    IsCorrect BIT NOT NULL DEFAULT 0
);
GO

ALTER TABLE dbo.QuizAnswers
ADD CONSTRAINT FK_QuizAnswers_Question FOREIGN KEY (QuestionId)
REFERENCES dbo.QuizQuestions(QuestionId);
GO
--=====================
CREATE TABLE dbo.QuizAttempts (
    AttemptId INT IDENTITY(1,1) PRIMARY KEY,
    QuizId INT NOT NULL,
    EnrollmentId INT NOT NULL,
    ClassSectionId INT NOT NULL,
    StartedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    SubmittedAt DATETIME2(0) NULL,
    Score DECIMAL(5,2) NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS'
);
GO

ALTER TABLE dbo.QuizAttempts
ADD CONSTRAINT FK_QuizAttempts_Quiz FOREIGN KEY (QuizId)
REFERENCES dbo.Quizzes(QuizId);

ALTER TABLE dbo.QuizAttempts
ADD CONSTRAINT FK_QuizAttempts_Enrollment FOREIGN KEY (EnrollmentId)
REFERENCES dbo.Enrollments(EnrollmentId);

ALTER TABLE dbo.QuizAttempts
ADD CONSTRAINT CK_QuizAttempts_Status CHECK (Status IN ('IN_PROGRESS','SUBMITTED','GRADED'));

ALTER TABLE dbo.QuizAttempts
ADD CONSTRAINT FK_QuizAttempts_ClassSection FOREIGN KEY (ClassSectionId)
REFERENCES dbo.ClassSections(ClassSectionId);

CREATE UNIQUE INDEX UX_QuizAttempts_OnePerStudent
ON dbo.QuizAttempts(QuizId, EnrollmentId);
GO

---====================================

CREATE TABLE dbo.QuizAttemptAnswers (
    AttemptAnswerId INT IDENTITY(1,1) PRIMARY KEY,
    AttemptId INT NOT NULL,
    QuestionId INT NOT NULL,
    SelectedAnswerId INT NULL,
    IsCorrect BIT NULL
);
GO

ALTER TABLE dbo.QuizAttemptAnswers
ADD CONSTRAINT FK_QAA_Attempt FOREIGN KEY (AttemptId)
REFERENCES dbo.QuizAttempts(AttemptId);

ALTER TABLE dbo.QuizAttemptAnswers
ADD CONSTRAINT FK_QAA_Question FOREIGN KEY (QuestionId)
REFERENCES dbo.QuizQuestions(QuestionId);

ALTER TABLE dbo.QuizAttemptAnswers
ADD CONSTRAINT FK_QAA_Answer FOREIGN KEY (SelectedAnswerId)
REFERENCES dbo.QuizAnswers(AnswerId);
GO

--=========================
/* =============================================================
   MODULE 9: FINANCE & MOMO PAYMENT (COURSE REGISTRATION SUPPORT)
   Notes: 
   - Manages Tuition Fees based on Credits registered.
   - Integrates MoMo Payment Gateway.
   - Uses Wallet system to handle Add/Drop refunds easily.
   ============================================================= */

/* 1. Bảng Ví sinh viên (StudentWallets)
   Mục đích: Lưu số dư khả dụng để đóng tiền học. 
   Khi nạp MoMo -> Tiền vào đây -> Sinh viên bấm "Thanh toán học phí" -> Trừ tiền ở đây.
*/
CREATE TABLE dbo.StudentWallets (
    WalletId        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_StudentWallets PRIMARY KEY,
    StudentId       INT NOT NULL,
    Balance         DECIMAL(18,2) NOT NULL CONSTRAINT DF_StudentWallets_Balance DEFAULT (0),
    WalletStatus    NVARCHAR(20) NOT NULL CONSTRAINT DF_StudentWallets_Status DEFAULT (N'ACTIVE'), -- ACTIVE | LOCKED
    LastUpdated     DATETIME2(0) NOT NULL CONSTRAINT DF_StudentWallets_LastUpdated DEFAULT (SYSUTCDATETIME()),
);
GO

ALTER TABLE dbo.StudentWallets
ADD CONSTRAINT FK_StudentWallets_Students FOREIGN KEY (StudentId) REFERENCES dbo.Students(StudentId);
GO
ALTER TABLE dbo.StudentWallets
ADD CONSTRAINT UQ_StudentWallets_Student UNIQUE (StudentId);
GO

/* 2. Bảng Học phí (TuitionFees)
   Mục đích: Tổng hợp số tiền cần đóng cho 1 kỳ học cụ thể.
   Khi sinh viên đăng ký môn học (Enrollments), hệ thống sẽ tính toán và cập nhật bảng này.
*/
CREATE TABLE dbo.TuitionFees (
    FeeId           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TuitionFees PRIMARY KEY,
    StudentId       INT NOT NULL,
    SemesterId      INT NOT NULL,
    TotalCredits    INT NOT NULL DEFAULT (0),       -- Tổng tín chỉ đã đăng ký
    AmountPerCredit DECIMAL(18,2) NOT NULL DEFAULT (0), -- Đơn giá 1 tín chỉ
    TotalAmount     DECIMAL(18,2) NOT NULL,         -- = TotalCredits * AmountPerCredit
    PaidAmount      DECIMAL(18,2) NOT NULL CONSTRAINT DF_TuitionFees_PaidAmount DEFAULT (0), -- Số tiền đã thanh toán
    Status          NVARCHAR(20) NOT NULL CONSTRAINT DF_TuitionFees_Status DEFAULT (N'UNPAID'), -- UNPAID | PARTIAL | PAID | OVERDUE
    DueDate         DATE NULL,
    CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_TuitionFees_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt       DATETIME2(0) NULL
);
GO

ALTER TABLE dbo.TuitionFees
ADD CONSTRAINT FK_TuitionFees_Students FOREIGN KEY (StudentId) REFERENCES dbo.Students(StudentId);
GO
ALTER TABLE dbo.TuitionFees
ADD CONSTRAINT FK_TuitionFees_Semesters FOREIGN KEY (SemesterId) REFERENCES dbo.Semesters(SemesterId);
GO
ALTER TABLE dbo.TuitionFees
ADD CONSTRAINT CK_TuitionFees_Status CHECK (Status IN (N'UNPAID', N'PARTIAL', N'PAID', N'OVERDUE'));
GO
/* Mỗi sinh viên chỉ có 1 hồ sơ học phí cho 1 kỳ */
ALTER TABLE dbo.TuitionFees
ADD CONSTRAINT UQ_TuitionFees_Student_Semester UNIQUE (StudentId, SemesterId);
GO

/* 3. Bảng Giao dịch Cổng thanh toán (PaymentTransactions) - LOG MOMO
   Mục đích: Lưu lịch sử gọi API sang MoMo và kết quả trả về (IPN).
*/
CREATE TABLE dbo.PaymentTransactions (
    TransactionId   BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PaymentTransactions PRIMARY KEY,
    StudentId       INT NOT NULL,
    PaymentMethod   NVARCHAR(50) NOT NULL CONSTRAINT DF_PaymentTransactions_Method DEFAULT (N'MOMO'), 
    
    -- Các trường quan trọng để map với MoMo API
    MoMoRequestId   NVARCHAR(100) NOT NULL, -- requestId (Unique per attempt)
    MoMoOrderId     NVARCHAR(100) NOT NULL, -- orderId (Unique per logical order)
    MoMoTransId     BIGINT NULL,            -- transId (Mã giao dịch phía MoMo trả về)
    
    Amount          DECIMAL(18,2) NOT NULL,
    OrderInfo       NVARCHAR(500) NULL,     -- Nội dung chuyển khoản (VD: Nap tien hoc phi SP26)
    
    -- Trạng thái xử lý
    Status          NVARCHAR(20) NOT NULL CONSTRAINT DF_PaymentTransactions_Status DEFAULT (N'PENDING'), -- PENDING | SUCCESS | FAILED | CANCELLED
    ErrorCode       INT NULL,               -- Mã lỗi MoMo (0 = Thành công)
    LocalMessage    NVARCHAR(500) NULL,     -- Ghi chú nội bộ
    
    RawResponse     NVARCHAR(MAX) NULL,     -- Lưu JSON response từ MoMo để debug khi cần
    PaymentDate     DATETIME2(0) NULL,      -- Thời điểm nhận tiền thành công
    CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_PaymentTransactions_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.PaymentTransactions
ADD CONSTRAINT FK_PaymentTransactions_Students FOREIGN KEY (StudentId) REFERENCES dbo.Students(StudentId);
GO
/* Đảm bảo OrderId không trùng lặp để đối soát */
CREATE UNIQUE INDEX UX_PaymentTransactions_MoMoOrderId ON dbo.PaymentTransactions(MoMoOrderId);
GO

/* 4. Bảng Lịch sử dòng tiền (WalletTransactions)
   Mục đích: Ghi lại biến động số dư (Dòng tiền vào/ra ví).
   Ví dụ: Nạp 5tr (DEPOSIT) -> Đóng học 3tr (TUITION_PAYMENT) -> Hủy môn hoàn 1tr (REFUND)
*/
CREATE TABLE dbo.WalletTransactions (
    WalletTransId   BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_WalletTransactions PRIMARY KEY,
    WalletId        INT NOT NULL,
    Amount          DECIMAL(18,2) NOT NULL, -- Dương (+) là tăng tiền, Âm (-) là giảm tiền
    TransactionType NVARCHAR(50) NOT NULL,  -- DEPOSIT (Nạp từ MoMo) | TUITION_PAYMENT (Thanh toán học phí) | REFUND (Hoàn tiền khi Drop)
    
    -- Liên kết nguồn gốc giao dịch
    RelatedPaymentId BIGINT NULL,           -- Link tới PaymentTransactions (nếu là Nạp tiền)
    RelatedFeeId     INT NULL,              -- Link tới TuitionFees (nếu là Đóng học phí)
    
    Description     NVARCHAR(500) NULL,
    CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_WalletTransactions_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

ALTER TABLE dbo.WalletTransactions
ADD CONSTRAINT FK_WalletTransactions_Wallet FOREIGN KEY (WalletId) REFERENCES dbo.StudentWallets(WalletId);
GO
ALTER TABLE dbo.WalletTransactions
ADD CONSTRAINT FK_WalletTransactions_Payment FOREIGN KEY (RelatedPaymentId) REFERENCES dbo.PaymentTransactions(TransactionId);
GO
ALTER TABLE dbo.WalletTransactions
ADD CONSTRAINT FK_WalletTransactions_Fee FOREIGN KEY (RelatedFeeId) REFERENCES dbo.TuitionFees(FeeId);
GO
--===========================



INSERT INTO dbo.Programs (ProgramCode, ProgramName) VALUES
('SE', N'Kỹ thuật phần mềm'),
('AI', N'Trí tuệ nhân tạo'),
('GD', N'Thiết kế đồ họa');
GO

-- 2. Tạo dữ liệu Học kỳ (Semesters)
INSERT INTO dbo.Semesters (SemesterCode, SemesterName, StartDate, EndDate, IsActive, RegistrationEndDate, AddDropDeadline) VALUES
('SP26', N'Spring 2026', '2026-01-05', '2026-04-30', 1, '2025-12-31', '2026-01-15'),
('SU26', N'Summer 2026', '2026-05-10', '2026-08-30', 0, '2026-05-01', '2026-05-20');
GO

-- 3. Tạo dữ liệu Môn học (Courses)
INSERT INTO dbo.Courses (CourseCode, CourseName, Credits, Description) VALUES
('PRN211', N'Basic Cross-Platform App Programming', 3, N'C# basic and WinForms'),
('PRN222', N'Advanced Cross-Platform App Programming', 3, N'ASP.NET Core, EF Core, SignalR'),
('PRN231', N'Building Cross-Platform Web APIs', 3, N'RESTful API, OData, JWT'),
('SWP391', N'Software Development Project', 4, N'Capstone project for juniors');
GO

-- =============================================================
-- 4. TẠO USERS (1 Admin, 5 Teachers, 14 Students)
-- Lưu ý: PasswordHash ở đây là giả lập. Trong thực tế cần dùng BCrypt hash.
-- Mật khẩu mặc định ví dụ: '123456' (Hash giả: $2a$11$...)
-- =============================================================

-- 4.1 Tạo Admin (1 người)
INSERT INTO dbo.Users (Username, PasswordHash, Email, FullName, Role, IsActive) VALUES
('admin', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'admin@fpt.edu.vn', N'Quản Trị Viên Hệ Thống', 'ADMIN', 1);

-- 4.2 Tạo Teachers (5 người)
INSERT INTO dbo.Users (Username, PasswordHash, Email, FullName, Role, IsActive) VALUES
('teacher1', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'hungnv@fpt.edu.vn', N'Nguyễn Văn Hùng', 'TEACHER', 1),
('teacher2', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'hoangtm@fpt.edu.vn', N'Trần Minh Hoàng', 'TEACHER', 1),
('teacher3', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'lannt@fpt.edu.vn', N'Nguyễn Thị Lan', 'TEACHER', 1),
('teacher4', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'dungpa@fpt.edu.vn', N'Phạm Anh Dũng', 'TEACHER', 1),
('teacher5', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'huonglt@fpt.edu.vn', N'Lê Thị Hương', 'TEACHER', 1);

-- 4.3 Tạo Students (14 người)
INSERT INTO dbo.Users (Username, PasswordHash, Email, FullName, Role, IsActive) VALUES
('student1', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'namnv@he18.vn', N'Nguyễn Văn Nam', 'STUDENT', 1),
('student2', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'linhtt@he18.vn', N'Trần Thùy Linh', 'STUDENT', 1),
('student3', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'quanlm@he18.vn', N'Lê Minh Quân', 'STUDENT', 1),
('student4', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'maihtp@he18.vn', N'Hoàng Thị Phương Mai', 'STUDENT', 1),
('student5', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'duongtv@he18.vn', N'Trương Văn Dương', 'STUDENT', 1),
('student6', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'thanhhv@he18.vn', N'Hà Văn Thành', 'STUDENT', 1),
('student7', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'ngocdth@he18.vn', N'Đỗ Thị Hồng Ngọc', 'STUDENT', 1),
('student8', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'khoand@he18.vn', N'Nguyễn Đăng Khoa', 'STUDENT', 1),
('student9', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'mylt@he18.vn', N'Lý Thị Mỹ', 'STUDENT', 1),
('student10', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'phucbp@he18.vn', N'Bùi Phi Phúc', 'STUDENT', 1),
('student11', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'trangnt@he18.vn', N'Ngô Thùy Trang', 'STUDENT', 1),
('student12', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'vietpd@he18.vn', N'Phạm Đức Việt', 'STUDENT', 1),
('student13', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'anhtt@he18.vn', N'Trịnh Tuấn Anh', 'STUDENT', 1),
('student14', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'yennh@he18.vn', N'Nguyễn Hải Yến', 'STUDENT', 1);
GO

-- =============================================================
-- 5. LINK DỮ LIỆU VÀO BẢNG TEACHERS VÀ STUDENTS
-- =============================================================

-- 5.1 Insert vào bảng Teachers (Lấy UserId từ bảng Users có Role='TEACHER')
INSERT INTO dbo.Teachers (TeacherId, TeacherCode, Department)
SELECT 
    UserId, 
    'GV' + RIGHT('0000' + CAST(UserId AS VARCHAR(10)), 4), -- Tạo mã GV0002, GV0003...
    CASE 
        WHEN UserId % 2 = 0 THEN N'Kỹ thuật phần mềm' 
        ELSE N'Khoa học máy tính' 
    END
FROM dbo.Users 
WHERE Role = 'TEACHER';
GO

-- 5.2 Insert vào bảng Students (Lấy UserId từ bảng Users có Role='STUDENT')
-- Gán ngẫu nhiên vào ProgramId=1 (SE) và SemesterId=1 (SP26)
DECLARE @ProgramId INT = (SELECT TOP 1 ProgramId FROM dbo.Programs WHERE ProgramCode = 'SE');
DECLARE @SemesterId INT = (SELECT TOP 1 SemesterId FROM dbo.Semesters WHERE SemesterCode = 'SP26');

INSERT INTO dbo.Students (StudentId, StudentCode, ProgramId, CurrentSemesterId)
SELECT 
    UserId, 
    'HE18' + RIGHT('0000' + CAST(UserId AS VARCHAR(10)), 4), -- Tạo mã HE180007...
    @ProgramId,
    @SemesterId
FROM dbo.Users 
WHERE Role = 'STUDENT';
GO

-- =============================================================
-- 6. TẠO LỚP HỌC (CLASS SECTIONS) & PHÂN CÔNG GIẢNG DẠY (Tùy chọn thêm để test)
-- =============================================================

DECLARE @SemId INT = (SELECT SemesterId FROM dbo.Semesters WHERE SemesterCode = 'SP26');
DECLARE @CourseId INT = (SELECT CourseId FROM dbo.Courses WHERE CourseCode = 'PRN222');
DECLARE @TeacherId INT = (SELECT TOP 1 TeacherId FROM dbo.Teachers);

-- Tạo 2 lớp học cho môn PRN222
INSERT INTO dbo.ClassSections (SemesterId, CourseId, TeacherId, SectionCode, Room, MaxCapacity) VALUES
(@SemId, @CourseId, @TeacherId, 'SE1801', 'BE-301', 30),
(@SemId, @CourseId, @TeacherId, 'SE1802', 'BE-302', 30);
GO

/* =====================================================
   SEED DATA - 100 rows per table
   ===================================================== */

-- =====================================================
-- SEED: Users (100 rows total: 1 existing admin + 5 existing teachers + 14 existing students = 20 already inserted)
-- We add 19 more teachers (total 24) + 56 more students (total 70) + some admins = 80 new rows
-- Actually we insert fresh 100 additional seed users here (teachers + students)
-- =====================================================

-- 19 more Teachers (user rows)
INSERT INTO dbo.Users (Username, PasswordHash, Email, FullName, Role, IsActive) VALUES
('teacher6',  '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher6@fpt.edu.vn',  N'Võ Thị Thu', 'TEACHER', 1),
('teacher7',  '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher7@fpt.edu.vn',  N'Đinh Quang Minh', 'TEACHER', 1),
('teacher8',  '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher8@fpt.edu.vn',  N'Lưu Thị Hoa', 'TEACHER', 1),
('teacher9',  '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher9@fpt.edu.vn',  N'Phan Văn Đức', 'TEACHER', 1),
('teacher10', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher10@fpt.edu.vn', N'Bùi Thị Nga', 'TEACHER', 1),
('teacher11', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher11@fpt.edu.vn', N'Trịnh Văn Long', 'TEACHER', 1),
('teacher12', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher12@fpt.edu.vn', N'Ngô Thị Bích', 'TEACHER', 1),
('teacher13', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher13@fpt.edu.vn', N'Hồ Văn Phong', 'TEACHER', 1),
('teacher14', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher14@fpt.edu.vn', N'Đặng Thị Loan', 'TEACHER', 1),
('teacher15', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher15@fpt.edu.vn', N'Vũ Quốc Hùng', 'TEACHER', 1),
('teacher16', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher16@fpt.edu.vn', N'Lê Thị Kim Anh', 'TEACHER', 1),
('teacher17', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher17@fpt.edu.vn', N'Nguyễn Hữu Trung', 'TEACHER', 1),
('teacher18', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher18@fpt.edu.vn', N'Phạm Thị Yến', 'TEACHER', 1),
('teacher19', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher19@fpt.edu.vn', N'Cao Văn Tài', 'TEACHER', 1),
('teacher20', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher20@fpt.edu.vn', N'Trần Thị Mai', 'TEACHER', 1),
('teacher21', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher21@fpt.edu.vn', N'Lý Văn Sang', 'TEACHER', 1),
('teacher22', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher22@fpt.edu.vn', N'Dương Thị Hà', 'TEACHER', 1),
('teacher23', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher23@fpt.edu.vn', N'Mai Văn Khải', 'TEACHER', 1),
('teacher24', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 'teacher24@fpt.edu.vn', N'Hoàng Thị Nga', 'TEACHER', 1);
GO

-- 81 more Students (user rows) to reach 100 total new rows in this seed block
INSERT INTO dbo.Users (Username, PasswordHash, Email, FullName, Role, IsActive) VALUES
('student15', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's15@he18.vn', N'Phùng Thị Lan', 'STUDENT', 1),
('student16', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's16@he18.vn', N'Tô Văn Bình', 'STUDENT', 1),
('student17', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's17@he18.vn', N'Đỗ Thị Hằng', 'STUDENT', 1),
('student18', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's18@he18.vn', N'Lê Văn Cường', 'STUDENT', 1),
('student19', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's19@he18.vn', N'Vũ Thị Hoa', 'STUDENT', 1),
('student20', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's20@he18.vn', N'Trần Văn Đạt', 'STUDENT', 1),
('student21', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's21@he18.vn', N'Nguyễn Thị Thảo', 'STUDENT', 1),
('student22', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's22@he18.vn', N'Phạm Văn Kiên', 'STUDENT', 1),
('student23', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's23@he18.vn', N'Hoàng Thị Nhung', 'STUDENT', 1),
('student24', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's24@he18.vn', N'Bùi Văn Tú', 'STUDENT', 1),
('student25', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's25@he18.vn', N'Lê Thị Phương', 'STUDENT', 1),
('student26', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's26@he18.vn', N'Đinh Văn Tùng', 'STUDENT', 1),
('student27', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's27@he18.vn', N'Trịnh Thị Huyền', 'STUDENT', 1),
('student28', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's28@he18.vn', N'Võ Văn Hải', 'STUDENT', 1),
('student29', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's29@he18.vn', N'Ngô Thị Bảo', 'STUDENT', 1),
('student30', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's30@he18.vn', N'Phan Văn Lộc', 'STUDENT', 1),
('student31', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's31@he18.vn', N'Lưu Thị Diểm', 'STUDENT', 1),
('student32', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's32@he18.vn', N'Hà Văn Quý', 'STUDENT', 1),
('student33', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's33@he18.vn', N'Đặng Thị Thu', 'STUDENT', 1),
('student34', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's34@he18.vn', N'Vương Văn Duy', 'STUDENT', 1),
('student35', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's35@he18.vn', N'Cao Thị Xuân', 'STUDENT', 1),
('student36', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's36@he18.vn', N'Lý Văn Hiếu', 'STUDENT', 1),
('student37', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's37@he18.vn', N'Dương Thị Ngân', 'STUDENT', 1),
('student38', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's38@he18.vn', N'Mai Văn Thắng', 'STUDENT', 1),
('student39', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's39@he18.vn', N'Hồ Thị Liên', 'STUDENT', 1),
('student40', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's40@he18.vn', N'Tống Văn Khoa', 'STUDENT', 1),
('student41', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's41@he18.vn', N'Trương Thị Minh', 'STUDENT', 1),
('student42', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's42@he18.vn', N'Đoàn Văn Phú', 'STUDENT', 1),
('student43', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's43@he18.vn', N'Lê Thị Oanh', 'STUDENT', 1),
('student44', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's44@he18.vn', N'Nguyễn Văn Quyết', 'STUDENT', 1),
('student45', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's45@he18.vn', N'Phạm Thị Hồng', 'STUDENT', 1),
('student46', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's46@he18.vn', N'Bùi Văn Tân', 'STUDENT', 1),
('student47', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's47@he18.vn', N'Hoàng Văn Sơn', 'STUDENT', 1),
('student48', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's48@he18.vn', N'Trần Thị Diệu', 'STUDENT', 1),
('student49', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's49@he18.vn', N'Đinh Văn Hải', 'STUDENT', 1),
('student50', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's50@he18.vn', N'Võ Thị Hạnh', 'STUDENT', 1),
('student51', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's51@he18.vn', N'Lưu Văn Cảnh', 'STUDENT', 1),
('student52', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's52@he18.vn', N'Ngô Thị Lan', 'STUDENT', 1),
('student53', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's53@he18.vn', N'Phan Văn Tài', 'STUDENT', 1),
('student54', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's54@he18.vn', N'Hà Thị Thúy', 'STUDENT', 1),
('student55', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's55@he18.vn', N'Lý Văn Dũng', 'STUDENT', 1),
('student56', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's56@he18.vn', N'Dương Thị Quỳnh', 'STUDENT', 1),
('student57', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's57@he18.vn', N'Cao Văn Nghĩa', 'STUDENT', 1),
('student58', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's58@he18.vn', N'Trịnh Thị Vân', 'STUDENT', 1),
('student59', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's59@he18.vn', N'Đặng Văn Thành', 'STUDENT', 1),
('student60', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's60@he18.vn', N'Vương Thị Bích', 'STUDENT', 1),
('student61', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's61@he18.vn', N'Hồ Văn Duy', 'STUDENT', 1),
('student62', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's62@he18.vn', N'Tô Thị Hà', 'STUDENT', 1),
('student63', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's63@he18.vn', N'Lê Văn Toàn', 'STUDENT', 1),
('student64', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's64@he18.vn', N'Nguyễn Thị Ngọc', 'STUDENT', 1),
('student65', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's65@he18.vn', N'Phạm Văn Long', 'STUDENT', 1),
('student66', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's66@he18.vn', N'Bùi Thị Mai', 'STUDENT', 1),
('student67', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's67@he18.vn', N'Võ Văn Khang', 'STUDENT', 1),
('student68', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's68@he18.vn', N'Trần Thị Thùy', 'STUDENT', 1),
('student69', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's69@he18.vn', N'Đinh Thị Loan', 'STUDENT', 1),
('student70', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's70@he18.vn', N'Lưu Văn Minh', 'STUDENT', 1),
('student71', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's71@he18.vn', N'Hoàng Văn Hải', 'STUDENT', 1),
('student72', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's72@he18.vn', N'Ngô Thị Hương', 'STUDENT', 1),
('student73', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's73@he18.vn', N'Phan Văn Đông', 'STUDENT', 1),
('student74', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's74@he18.vn', N'Đoàn Thị Phúc', 'STUDENT', 1),
('student75', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's75@he18.vn', N'Tống Văn Bảo', 'STUDENT', 1),
('student76', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's76@he18.vn', N'Vũ Thị Thu', 'STUDENT', 1),
('student77', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's77@he18.vn', N'Hà Văn Sỹ', 'STUDENT', 1),
('student78', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's78@he18.vn', N'Dương Thị Châu', 'STUDENT', 1),
('student79', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's79@he18.vn', N'Trương Văn Tín', 'STUDENT', 1),
('student80', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's80@he18.vn', N'Cao Thị Yến', 'STUDENT', 1),
('student81', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's81@he18.vn', N'Lý Văn Đức', 'STUDENT', 1),
('student82', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's82@he18.vn', N'Trịnh Thị Khánh', 'STUDENT', 1),
('student83', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's83@he18.vn', N'Đặng Văn Phong', 'STUDENT', 1),
('student84', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's84@he18.vn', N'Mai Thị Hồng', 'STUDENT', 1),
('student85', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's85@he18.vn', N'Hồ Văn Hòa', 'STUDENT', 1),
('student86', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's86@he18.vn', N'Tô Thị Lệ', 'STUDENT', 1),
('student87', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's87@he18.vn', N'Phùng Văn An', 'STUDENT', 1),
('student88', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's88@he18.vn', N'Lưu Thị Bình', 'STUDENT', 1),
('student89', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's89@he18.vn', N'Nguyễn Văn Trí', 'STUDENT', 1),
('student90', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's90@he18.vn', N'Phạm Thị Cúc', 'STUDENT', 1),
('student91', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's91@he18.vn', N'Hoàng Văn Linh', 'STUDENT', 1),
('student92', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's92@he18.vn', N'Trần Thị Bích', 'STUDENT', 1),
('student93', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's93@he18.vn', N'Đinh Văn Tuấn', 'STUDENT', 1),
('student94', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's94@he18.vn', N'Võ Thị Giang', 'STUDENT', 1),
('student95', '$2a$10$Buj5ZRDdXG/uQTQzgCmoDul02XwRUh83447c09UreThGSYbOA0wx.', 's95@he18.vn', N'Bùi Văn Quang', 'STUDENT', 1);
GO

-- Link new Teachers -> dbo.Teachers
INSERT INTO dbo.Teachers (TeacherId, TeacherCode, Department)
SELECT UserId,
       'GV' + RIGHT('0000' + CAST(UserId AS VARCHAR(10)), 4),
       CASE WHEN UserId % 3 = 0 THEN N'Kỹ thuật phần mềm'
            WHEN UserId % 3 = 1 THEN N'Khoa học máy tính'
            ELSE N'Hệ thống thông tin' END
FROM dbo.Users WHERE Role = 'TEACHER' AND UserId NOT IN (SELECT TeacherId FROM dbo.Teachers);
GO

-- Link new Students -> dbo.Students
DECLARE @PId INT = (SELECT TOP 1 ProgramId FROM dbo.Programs ORDER BY ProgramId);
DECLARE @SId INT = (SELECT TOP 1 SemesterId FROM dbo.Semesters WHERE IsActive = 1);
INSERT INTO dbo.Students (StudentId, StudentCode, ProgramId, CurrentSemesterId)
SELECT UserId,
       'HE18' + RIGHT('0000' + CAST(UserId AS VARCHAR(10)), 4),
       @PId, @SId
FROM dbo.Users WHERE Role = 'STUDENT' AND UserId NOT IN (SELECT StudentId FROM dbo.Students);
GO

-- =====================================================
-- SEED: Programs (97 more => total 100)
-- =====================================================
INSERT INTO dbo.Programs (ProgramCode, ProgramName, IsActive) VALUES
('IS',   N'Hệ thống thông tin', 1),
('CS',   N'Khoa học máy tính', 1),
('BA',   N'Kinh doanh và Quản trị', 1),
('MK',   N'Marketing số', 1),
('EC',   N'Kinh tế học', 1),
('DS',   N'Khoa học dữ liệu', 1),
('CN',   N'Mạng máy tính', 1),
('CEP',  N'Kỹ thuật máy tính', 1),
('EE',   N'Kỹ thuật điện', 1),
('ME',   N'Kỹ thuật cơ khí', 1),
('JP',   N'Ngôn ngữ Nhật', 1),
('KR',   N'Ngôn ngữ Hàn', 1),
('EN',   N'Ngôn ngữ Anh', 1),
('LA',   N'Luật kinh tế', 1),
('AC',   N'Kế toán', 1),
('FI',   N'Tài chính ngân hàng', 1),
('HR',   N'Quản trị nhân lực', 1),
('HT',   N'Quản trị khách sạn', 1),
('TN',   N'Du lịch lữ hành', 1),
('MT',   N'Truyền thông đa phương tiện', 1),
('FA',   N'Thiết kế nội thất', 1),
('FD',   N'Thiết kế thời trang', 1),
('PH',   N'Nhiếp ảnh và Phim ảnh', 1),
('MU',   N'Âm nhạc ứng dụng', 1),
('GA',   N'Thiết kế game', 1),
('AR',   N'Kiến trúc', 1),
('CI',   N'Kỹ thuật xây dựng', 1),
('BT',   N'Công nghệ sinh học', 1),
('FO',   N'Công nghệ thực phẩm', 1),
('EN2',  N'Kỹ thuật môi trường', 1),
('NF',   N'Dinh dưỡng học', 1),
('PY',   N'Tâm lý học', 1),
('SO',   N'Xã hội học', 1),
('PO',   N'Khoa học chính trị', 1),
('HI',   N'Lịch sử', 1),
('LI',   N'Thư viện thông tin', 1),
('PEP',  N'Giáo dục thể chất', 1),
('NC',   N'Điều dưỡng', 1),
('MD',   N'Y khoa', 1),
('PH2',  N'Dược học', 1),
('DEP',  N'Kinh tế phát triển', 1),
('RM',   N'Quản trị rủi ro', 1),
('SC',   N'Chuỗi cung ứng', 1),
('IE',   N'Kỹ thuật công nghiệp', 1),
('AU',   N'Kỹ thuật ô tô', 1),
('AV',   N'Kỹ thuật hàng không', 1),
('MA',   N'Toán học ứng dụng', 1),
('PH3',  N'Vật lý kỹ thuật', 1),
('CH',   N'Hóa học ứng dụng', 1),
('BI',   N'Sinh học ứng dụng', 1),
('GE',   N'Kỹ thuật địa chất', 1),
('SP',   N'Ngôn ngữ Tây Ban Nha', 1),
('FR',   N'Ngôn ngữ Pháp', 1),
('DE2',  N'Ngôn ngữ Đức', 1),
('RU',   N'Ngôn ngữ Nga', 1),
('ZH',   N'Ngôn ngữ Trung', 1),
('ID',   N'Quản lý công nghiệp', 1),
('LO',   N'Logistics', 1),
('PM',   N'Quản lý dự án', 1),
('EM',   N'Khởi nghiệp', 1),
('EA',   N'Kiểm toán', 1),
('TX',   N'Thuế', 1),
('RE',   N'Bất động sản', 1),
('INS',  N'Bảo hiểm', 1),
('BK',   N'Ngân hàng số', 1),
('CY',   N'An ninh mạng', 1),
('BL',   N'Chuỗi khối', 1),
('ML',   N'Học máy', 1),
('RO',   N'Robotics', 1),
('IOT',  N'Internet vạn vật', 1),
('CV',   N'Thị giác máy tính', 1),
('NLP',  N'Xử lý ngôn ngữ tự nhiên', 1),
('CG',   N'Đồ họa máy tính', 1),
('HCI',  N'Tương tác người-máy', 1),
('DM',   N'Khai phá dữ liệu', 1),
('BI2',  N'Kinh doanh thông minh', 1),
('OR',   N'Nghiên cứu vận trù', 1),
('ST',   N'Thống kê ứng dụng', 1),
('QA',   N'Đảm bảo chất lượng phần mềm', 1),
('SD',   N'Kiến trúc phần mềm', 1),
('DB',   N'Cơ sở dữ liệu nâng cao', 1),
('OSP',  N'Hệ điều hành nâng cao', 1),
('DC',   N'Điện toán phân tán', 1),
('CC',   N'Điện toán đám mây', 1),
('DV',   N'DevOps', 1),
('SA',   N'Kiến trúc hệ thống', 1),
('WD',   N'Phát triển web nâng cao', 1),
('MB',   N'Phát triển ứng dụng di động', 1),
('UX',   N'Thiết kế trải nghiệm người dùng', 1),
('GD2',  N'Thiết kế đồ họa nâng cao', 1),
('AN',   N'Hoạt hình kỹ thuật số', 1),
('VR',   N'Thực tế ảo và Thực tế tăng cường', 1);
GO

-- =====================================================
-- SEED: Semesters (98 more => total 100)
-- =====================================================
INSERT INTO dbo.Semesters (SemesterCode, SemesterName, StartDate, EndDate, IsActive, RegistrationEndDate, AddDropDeadline, WithdrawalDeadline, MaxCredits, MinCredits) VALUES
('FA22', N'Fall 2022',   '2022-08-15', '2022-12-15', 0, '2022-08-01', '2022-08-25', '2022-09-15', 20, 8),
('SP23', N'Spring 2023', '2023-01-05', '2023-04-30', 0, '2022-12-25', '2023-01-15', '2023-02-01', 20, 8),
('SU23', N'Summer 2023', '2023-05-10', '2023-08-10', 0, '2023-05-01', '2023-05-20', '2023-06-01', 12, 6),
('FA23', N'Fall 2023',   '2023-08-15', '2023-12-15', 0, '2023-08-01', '2023-08-25', '2023-09-15', 20, 8),
('SP24', N'Spring 2024', '2024-01-05', '2024-04-30', 0, '2023-12-25', '2024-01-15', '2024-02-01', 20, 8),
('SU24', N'Summer 2024', '2024-05-10', '2024-08-10', 0, '2024-05-01', '2024-05-20', '2024-06-01', 12, 6),
('FA24', N'Fall 2024',   '2024-08-15', '2024-12-15', 0, '2024-08-01', '2024-08-25', '2024-09-15', 20, 8),
('SP25', N'Spring 2025', '2025-01-05', '2025-04-30', 0, '2024-12-25', '2025-01-15', '2025-02-01', 20, 8),
('SU25', N'Summer 2025', '2025-05-10', '2025-08-10', 0, '2025-05-01', '2025-05-20', '2025-06-01', 12, 6),
('FA25', N'Fall 2025',   '2025-08-15', '2025-12-15', 0, '2025-08-01', '2025-08-25', '2025-09-15', 20, 8),
('SU26', N'Summer 2026', '2026-05-10', '2026-08-30', 0, '2026-05-01', '2026-05-20', '2026-06-10', 12, 6),
('FA26', N'Fall 2026',   '2026-08-15', '2026-12-15', 0, '2026-08-01', '2026-08-25', '2026-09-15', 20, 8),
('SP27', N'Spring 2027', '2027-01-05', '2027-04-30', 0, '2026-12-25', '2027-01-15', '2027-02-01', 20, 8),
('SU27', N'Summer 2027', '2027-05-10', '2027-08-10', 0, '2027-05-01', '2027-05-20', '2027-06-01', 12, 6),
('FA27', N'Fall 2027',   '2027-08-15', '2027-12-15', 0, '2027-08-01', '2027-08-25', '2027-09-15', 20, 8),
('SP28', N'Spring 2028', '2028-01-05', '2028-04-30', 0, '2027-12-25', '2028-01-15', '2028-02-01', 20, 8),
('SU28', N'Summer 2028', '2028-05-10', '2028-08-10', 0, '2028-05-01', '2028-05-20', '2028-06-01', 12, 6),
('FA28', N'Fall 2028',   '2028-08-15', '2028-12-15', 0, '2028-08-01', '2028-08-25', '2028-09-15', 20, 8),
('SP29', N'Spring 2029', '2029-01-05', '2029-04-30', 0, '2028-12-25', '2029-01-15', '2029-02-01', 20, 8),
('SU29', N'Summer 2029', '2029-05-10', '2029-08-10', 0, '2029-05-01', '2029-05-20', '2029-06-01', 12, 6),
('FA19', N'Fall 2019',   '2019-08-15', '2019-12-15', 0, '2019-08-01', '2019-08-25', '2019-09-15', 20, 8),
('SP20', N'Spring 2020', '2020-01-05', '2020-04-30', 0, '2019-12-25', '2020-01-15', '2020-02-01', 20, 8),
('SU20', N'Summer 2020', '2020-05-10', '2020-08-10', 0, '2020-05-01', '2020-05-20', '2020-06-01', 12, 6),
('FA20', N'Fall 2020',   '2020-08-15', '2020-12-15', 0, '2020-08-01', '2020-08-25', '2020-09-15', 20, 8),
('SP21', N'Spring 2021', '2021-01-05', '2021-04-30', 0, '2020-12-25', '2021-01-15', '2021-02-01', 20, 8),
('SU21', N'Summer 2021', '2021-05-10', '2021-08-10', 0, '2021-05-01', '2021-05-20', '2021-06-01', 12, 6),
('FA21', N'Fall 2021',   '2021-08-15', '2021-12-15', 0, '2021-08-01', '2021-08-25', '2021-09-15', 20, 8),
('SP22', N'Spring 2022', '2022-01-05', '2022-04-30', 0, '2021-12-25', '2022-01-15', '2022-02-01', 20, 8),
('SU22', N'Summer 2022', '2022-05-10', '2022-08-10', 0, '2022-05-01', '2022-05-20', '2022-06-01', 12, 6),
('FA30', N'Fall 2030',   '2030-08-15', '2030-12-15', 0, '2030-08-01', '2030-08-25', '2030-09-15', 20, 8),
('SP31', N'Spring 2031', '2031-01-05', '2031-04-30', 0, '2030-12-25', '2031-01-15', '2031-02-01', 20, 8),
('SU31', N'Summer 2031', '2031-05-10', '2031-08-10', 0, '2031-05-01', '2031-05-20', '2031-06-01', 12, 6),
('FA31', N'Fall 2031',   '2031-08-15', '2031-12-15', 0, '2031-08-01', '2031-08-25', '2031-09-15', 20, 8),
('SP32', N'Spring 2032', '2032-01-05', '2032-04-30', 0, '2031-12-25', '2032-01-15', '2032-02-01', 20, 8),
('SU32', N'Summer 2032', '2032-05-10', '2032-08-10', 0, '2032-05-01', '2032-05-20', '2032-06-01', 12, 6),
('FA32', N'Fall 2032',   '2032-08-15', '2032-12-15', 0, '2032-08-01', '2032-08-25', '2032-09-15', 20, 8),
('SP33', N'Spring 2033', '2033-01-05', '2033-04-30', 0, '2032-12-25', '2033-01-15', '2033-02-01', 20, 8),
('SU33', N'Summer 2033', '2033-05-10', '2033-08-10', 0, '2033-05-01', '2033-05-20', '2033-06-01', 12, 6),
('FA33', N'Fall 2033',   '2033-08-15', '2033-12-15', 0, '2033-08-01', '2033-08-25', '2033-09-15', 20, 8),
('SP34', N'Spring 2034', '2034-01-05', '2034-04-30', 0, '2033-12-25', '2034-01-15', '2034-02-01', 20, 8),
('SU34', N'Summer 2034', '2034-05-10', '2034-08-10', 0, '2034-05-01', '2034-05-20', '2034-06-01', 12, 6),
('FA34', N'Fall 2034',   '2034-08-15', '2034-12-15', 0, '2034-08-01', '2034-08-25', '2034-09-15', 20, 8),
('SP35', N'Spring 2035', '2035-01-05', '2035-04-30', 0, '2034-12-25', '2035-01-15', '2035-02-01', 20, 8),
('SU35', N'Summer 2035', '2035-05-10', '2035-08-10', 0, '2035-05-01', '2035-05-20', '2035-06-01', 12, 6),
('FA35', N'Fall 2035',   '2035-08-15', '2035-12-15', 0, '2035-08-01', '2035-08-25', '2035-09-15', 20, 8),
('SP36', N'Spring 2036', '2036-01-05', '2036-04-30', 0, '2035-12-25', '2036-01-15', '2036-02-01', 20, 8),
('SU36', N'Summer 2036', '2036-05-10', '2036-08-10', 0, '2036-05-01', '2036-05-20', '2036-06-01', 12, 6),
('FA36', N'Fall 2036',   '2036-08-15', '2036-12-15', 0, '2036-08-01', '2036-08-25', '2036-09-15', 20, 8),
('SP37', N'Spring 2037', '2037-01-05', '2037-04-30', 0, '2036-12-25', '2037-01-15', '2037-02-01', 20, 8),
('SU37', N'Summer 2037', '2037-05-10', '2037-08-10', 0, '2037-05-01', '2037-05-20', '2037-06-01', 12, 6),
('FA37', N'Fall 2037',   '2037-08-15', '2037-12-15', 0, '2037-08-01', '2037-08-25', '2037-09-15', 20, 8),
('SP38', N'Spring 2038', '2038-01-05', '2038-04-30', 0, '2037-12-25', '2038-01-15', '2038-02-01', 20, 8),
('SU38', N'Summer 2038', '2038-05-10', '2038-08-10', 0, '2038-05-01', '2038-05-20', '2038-06-01', 12, 6),
('FA38', N'Fall 2038',   '2038-08-15', '2038-12-15', 0, '2038-08-01', '2038-08-25', '2038-09-15', 20, 8),
('SP39', N'Spring 2039', '2039-01-05', '2039-04-30', 0, '2038-12-25', '2039-01-15', '2039-02-01', 20, 8),
('SU39', N'Summer 2039', '2039-05-10', '2039-08-10', 0, '2039-05-01', '2039-05-20', '2039-06-01', 12, 6),
('FA39', N'Fall 2039',   '2039-08-15', '2039-12-15', 0, '2039-08-01', '2039-08-25', '2039-09-15', 20, 8),
('SP40', N'Spring 2040', '2040-01-05', '2040-04-30', 0, '2039-12-25', '2040-01-15', '2040-02-01', 20, 8),
('SU40', N'Summer 2040', '2040-05-10', '2040-08-10', 0, '2040-05-01', '2040-05-20', '2040-06-01', 12, 6),
('FA40', N'Fall 2040',   '2040-08-15', '2040-12-15', 0, '2040-08-01', '2040-08-25', '2040-09-15', 20, 8),
('SP41', N'Spring 2041', '2041-01-05', '2041-04-30', 0, '2040-12-25', '2041-01-15', '2041-02-01', 20, 8),
('SU41', N'Summer 2041', '2041-05-10', '2041-08-10', 0, '2041-05-01', '2041-05-20', '2041-06-01', 12, 6),
('FA41', N'Fall 2041',   '2041-08-15', '2041-12-15', 0, '2041-08-01', '2041-08-25', '2041-09-15', 20, 8),
('SP42', N'Spring 2042', '2042-01-05', '2042-04-30', 0, '2041-12-25', '2042-01-15', '2042-02-01', 20, 8),
('SU42', N'Summer 2042', '2042-05-10', '2042-08-10', 0, '2042-05-01', '2042-05-20', '2042-06-01', 12, 6),
('FA42', N'Fall 2042',   '2042-08-15', '2042-12-15', 0, '2042-08-01', '2042-08-25', '2042-09-15', 20, 8),
('SP43', N'Spring 2043', '2043-01-05', '2043-04-30', 0, '2042-12-25', '2043-01-15', '2043-02-01', 20, 8),
('SU43', N'Summer 2043', '2043-05-10', '2043-08-10', 0, '2043-05-01', '2043-05-20', '2043-06-01', 12, 6),
('FA43', N'Fall 2043',   '2043-08-15', '2043-12-15', 0, '2043-08-01', '2043-08-25', '2043-09-15', 20, 8),
('SP44', N'Spring 2044', '2044-01-05', '2044-04-30', 0, '2043-12-25', '2044-01-15', '2044-02-01', 20, 8),
('SU44', N'Summer 2044', '2044-05-10', '2044-08-10', 0, '2044-05-01', '2044-05-20', '2044-06-01', 12, 6),
('FA44', N'Fall 2044',   '2044-08-15', '2044-12-15', 0, '2044-08-01', '2044-08-25', '2044-09-15', 20, 8),
('SP45', N'Spring 2045', '2045-01-05', '2045-04-30', 0, '2044-12-25', '2045-01-15', '2045-02-01', 20, 8),
('SU45', N'Summer 2045', '2045-05-10', '2045-08-10', 0, '2045-05-01', '2045-05-20', '2045-06-01', 12, 6),
('FA45', N'Fall 2045',   '2045-08-15', '2045-12-15', 0, '2045-08-01', '2045-08-25', '2045-09-15', 20, 8),
('SP46', N'Spring 2046', '2046-01-05', '2046-04-30', 0, '2045-12-25', '2046-01-15', '2046-02-01', 20, 8),
('SU46', N'Summer 2046', '2046-05-10', '2046-08-10', 0, '2046-05-01', '2046-05-20', '2046-06-01', 12, 6),
('FA46', N'Fall 2046',   '2046-08-15', '2046-12-15', 0, '2046-08-01', '2046-08-25', '2046-09-15', 20, 8),
('SP47', N'Spring 2047', '2047-01-05', '2047-04-30', 0, '2046-12-25', '2047-01-15', '2047-02-01', 20, 8),
('SU47', N'Summer 2047', '2047-05-10', '2047-08-10', 0, '2047-05-01', '2047-05-20', '2047-06-01', 12, 6),
('FA47', N'Fall 2047',   '2047-08-15', '2047-12-15', 0, '2047-08-01', '2047-08-25', '2047-09-15', 20, 8),
('SP48', N'Spring 2048', '2048-01-05', '2048-04-30', 0, '2047-12-25', '2048-01-15', '2048-02-01', 20, 8),
('SU48', N'Summer 2048', '2048-05-10', '2048-08-10', 0, '2048-05-01', '2048-05-20', '2048-06-01', 12, 6),
('FA48', N'Fall 2048',   '2048-08-15', '2048-12-15', 0, '2048-08-01', '2048-08-25', '2048-09-15', 20, 8),
('SP49', N'Spring 2049', '2049-01-05', '2049-04-30', 0, '2048-12-25', '2049-01-15', '2049-02-01', 20, 8),
('SU49', N'Summer 2049', '2049-05-10', '2049-08-10', 0, '2049-05-01', '2049-05-20', '2049-06-01', 12, 6),
('FA49', N'Fall 2049',   '2049-08-15', '2049-12-15', 0, '2049-08-01', '2049-08-25', '2049-09-15', 20, 8),
('SP50', N'Spring 2050', '2050-01-05', '2050-04-30', 0, '2049-12-25', '2050-01-15', '2050-02-01', 20, 8),
('SU50', N'Summer 2050', '2050-05-10', '2050-08-10', 0, '2050-05-01', '2050-05-20', '2050-06-01', 12, 6),
('FA50', N'Fall 2050',   '2050-08-15', '2050-12-15', 0, '2050-08-01', '2050-08-25', '2050-09-15', 20, 8),
('SP51', N'Spring 2051', '2051-01-05', '2051-04-30', 0, '2050-12-25', '2051-01-15', '2051-02-01', 20, 8);
GO

-- =====================================================
-- SEED: Courses (96 more => total 100)
-- =====================================================
INSERT INTO dbo.Courses (CourseCode, CourseName, Credits, Description) VALUES
('MAE101', N'Toán cao cấp E1', 3, N'Giải tích một biến'),
('MAE102', N'Toán cao cấp E2', 3, N'Giải tích nhiều biến'),
('PHY101', N'Vật lý đại cương 1', 3, N'Cơ học Newton'),
('PHY102', N'Vật lý đại cương 2', 3, N'Nhiệt học, điện từ học'),
('CHE101', N'Hóa học đại cương', 3, N'Nguyên tử, liên kết hóa học'),
('ENG101', N'Tiếng Anh 1', 2, N'Nghe nói đọc viết cơ bản'),
('ENG102', N'Tiếng Anh 2', 2, N'Giao tiếp học thuật'),
('ENG201', N'Tiếng Anh chuyên ngành CNTT', 3, N'Từ vựng kỹ thuật'),
('CEA101', N'Nhập môn kỹ thuật máy tính', 3, N'Logic số, hệ thống số'),
('CEA201', N'Cấu trúc máy tính', 3, N'CPU, bộ nhớ, bus'),
('OOP101', N'Lập trình hướng đối tượng', 3, N'Java OOP cơ bản'),
('DSA201', N'Cấu trúc dữ liệu và giải thuật', 4, N'Stack, Queue, Tree, Sort'),
('DBI201', N'Nhập môn cơ sở dữ liệu', 3, N'SQL Server cơ bản'),
('DBI302', N'Cơ sở dữ liệu nâng cao', 3, N'Stored Procedure, Index'),
('SWE201', N'Nhập môn kỹ thuật phần mềm', 3, N'SDLC, Agile'),
('SWD391', N'Phát triển ứng dụng web', 4, N'HTML, CSS, JS, Bootstrap'),
('SWD392', N'Phát triển web nâng cao', 4, N'React, Node.js'),
('SWR302', N'Kiểm thử phần mềm', 3, N'Unit test, Integration test'),
('NET101', N'Mạng máy tính cơ bản', 3, N'TCP/IP, OSI model'),
('SEC201', N'An ninh mạng cơ bản', 3, N'Mã hóa, xác thực'),
('OSC201', N'Hệ điều hành', 3, N'Process, Thread, Memory'),
('COT201', N'Lý thuyết tính toán', 3, N'Otomat, ngôn ngữ hình thức'),
('FIN201', N'Tài chính doanh nghiệp', 3, N'NPV, IRR, định giá'),
('ACC101', N'Kế toán đại cương', 3, N'Bảng cân đối kế toán'),
('MAN201', N'Quản trị học', 3, N'Hoạch định, lãnh đạo'),
('MKT101', N'Marketing căn bản', 3, N'4P, hành vi khách hàng'),
('ECO101', N'Kinh tế học vi mô', 3, N'Cung cầu, cân bằng thị trường'),
('ECO102', N'Kinh tế học vĩ mô', 3, N'GDP, lạm phát'),
('LAW101', N'Pháp luật đại cương', 2, N'Hệ thống pháp luật VN'),
('SOC101', N'Xã hội học đại cương', 2, N'Cấu trúc xã hội'),
('AI101',  N'Nhập môn Trí tuệ nhân tạo', 3, N'Tìm kiếm, suy luận cơ bản'),
('ML201',  N'Học máy', 3, N'Regression, Classification'),
('DL301',  N'Học sâu', 3, N'Neural Network, CNN, RNN'),
('CV201',  N'Thị giác máy tính', 3, N'OpenCV, image processing'),
('NLP201', N'Xử lý ngôn ngữ tự nhiên', 3, N'Tokenization, Transformer'),
('BDA301', N'Phân tích dữ liệu lớn', 4, N'Hadoop, Spark, Kafka'),
('CLD301', N'Điện toán đám mây', 3, N'AWS, Azure, GCP'),
('SEC301', N'An ninh mạng nâng cao', 3, N'Pen testing, OWASP Top 10'),
('BLC301', N'Công nghệ chuỗi khối', 3, N'Ethereum, Smart Contract'),
('IOT201', N'Internet vạn vật', 3, N'Arduino, MQTT'),
('ROB201', N'Robotics cơ bản', 3, N'ROS, kinematics'),
('UXD201', N'Thiết kế UX/UI', 3, N'User research, wireframe'),
('PM201',  N'Quản lý dự án phần mềm', 3, N'Scrum, Kanban'),
('DEV301', N'DevOps và CI/CD', 3, N'Docker, Kubernetes, Jenkins'),
('MIC301', N'Kiến trúc Microservices', 3, N'API Gateway, Service Mesh'),
('GRA101', N'Đồ họa máy tính cơ bản', 3, N'OpenGL, rasterization'),
('ANI201', N'Hoạt hình 2D/3D', 3, N'Blender, Maya cơ bản'),
('GDE201', N'Thiết kế game cơ bản', 3, N'Unity, C# scripting'),
('VRA201', N'Thực tế ảo và Tăng cường', 3, N'Oculus SDK, ARKit'),
('MUS101', N'Âm nhạc đại cương', 2, N'Lý thuyết âm nhạc'),
('PHT101', N'Nhiếp ảnh kỹ thuật số', 2, N'Bố cục, ánh sáng'),
('FAD101', N'Thiết kế thời trang cơ bản', 3, N'Vải, màu sắc, phác thảo'),
('IND201', N'Thiết kế nội thất', 3, N'AutoCAD, SketchUp'),
('BIO101', N'Sinh học phân tử', 3, N'DNA, RNA, protein synthesis'),
('CHE201', N'Hóa hữu cơ', 3, N'Alkanes, alkenes, arenes'),
('FNT101', N'Công nghệ thực phẩm', 3, N'Bảo quản, chế biến thực phẩm'),
('ENV201', N'Khoa học môi trường', 3, N'Ô nhiễm, biến đổi khí hậu'),
('NUT101', N'Dinh dưỡng và sức khỏe', 2, N'Chất dinh dưỡng'),
('NRS101', N'Điều dưỡng cơ bản', 3, N'Chăm sóc bệnh nhân'),
('MED101', N'Giải phẫu học', 4, N'Hệ xương, hệ cơ, nội tạng'),
('PHA101', N'Dược học đại cương', 3, N'Phân loại thuốc'),
('JPT101', N'Tiếng Nhật N5', 3, N'Hiragana, Katakana'),
('JPT201', N'Tiếng Nhật N4', 3, N'Ngữ pháp trung cấp'),
('KRT101', N'Tiếng Hàn cơ bản', 3, N'Hangul, hội thoại đơn giản'),
('KRT201', N'Tiếng Hàn trung cấp', 3, N'TOPIK prep'),
('SPT101', N'Tiếng Tây Ban Nha A1', 3, N'Phát âm, từ vựng'),
('FRT101', N'Tiếng Pháp A1', 3, N'Greetings, numbers, colors'),
('DET101', N'Tiếng Đức A1', 3, N'Bảng chữ cái, từ vựng'),
('RUT101', N'Tiếng Nga A1', 3, N'Bảng chữ Cyrillic, chào hỏi'),
('ZHT101', N'Tiếng Trung HSK 1', 3, N'Bính âm, từ vựng 150 từ'),
('ZHT201', N'Tiếng Trung HSK 2', 3, N'Từ vựng 300 từ, hội thoại'),
('LOG201', N'Logistics và chuỗi cung ứng', 3, N'Quản lý kho, vận chuyển'),
('SCM301', N'Chuỗi cung ứng nâng cao', 3, N'JIT, lean, ERP'),
('ENT201', N'Khởi nghiệp và đổi mới', 3, N'Business model canvas'),
('TAX201', N'Thuế trong kinh doanh', 3, N'VAT, thuế thu nhập DN'),
('AUD201', N'Kiểm toán cơ bản', 3, N'Quy trình kiểm toán'),
('INS201', N'Bảo hiểm và quản lý rủi ro', 3, N'Bảo hiểm nhân thọ'),
('REL201', N'Bất động sản và pháp lý', 3, N'Thị trường BĐS'),
('BNK201', N'Nghiệp vụ ngân hàng', 3, N'Tín dụng, thanh toán quốc tế'),
('SPO101', N'Giáo dục thể chất 1', 1, N'Bóng đá, bóng rổ'),
('SPO102', N'Giáo dục thể chất 2', 1, N'Bơi lội, võ thuật'),
('HIS101', N'Lịch sử văn minh thế giới', 2, N'Các nền văn minh cổ đại'),
('GEO101', N'Địa lý kinh tế', 2, N'Phân bố tài nguyên'),
('PSY101', N'Tâm lý học đại cương', 3, N'Nhận thức, cảm xúc'),
('COM101', N'Kỹ năng giao tiếp', 2, N'Thuyết trình, đàm phán'),
('ETH101', N'Đạo đức nghề nghiệp', 2, N'Trách nhiệm xã hội'),
('RES201', N'Phương pháp nghiên cứu', 3, N'Thiết kế nghiên cứu'),
('CAP401', N'Đồ án tốt nghiệp', 10, N'Nghiên cứu và phát triển sản phẩm'),
('INT301', N'Thực tập doanh nghiệp', 4, N'Thực tập tại công ty'),
('STA301', N'Thống kê ứng dụng', 3, N'Phân phối xác suất'),
('OPT301', N'Nghiên cứu vận trù', 3, N'Quy hoạch tuyến tính'),
('CG201',  N'Đồ họa và xử lý ảnh', 3, N'Bộ lọc ảnh, phân đoạn'),
('HCI201', N'Tương tác người-máy', 3, N'Usability, UX testing');
GO

-- =====================================================
-- SEED: ClassSections (100 rows)
-- =====================================================
DECLARE @SP26Id2 INT = (SELECT SemesterId FROM dbo.Semesters WHERE SemesterCode = 'SP26');
DECLARE @FA25Id2 INT = (SELECT SemesterId FROM dbo.Semesters WHERE SemesterCode = 'FA25');
DECLARE @SP25Id2 INT = (SELECT SemesterId FROM dbo.Semesters WHERE SemesterCode = 'SP25');
DECLARE @FA24Id2 INT = (SELECT SemesterId FROM dbo.Semesters WHERE SemesterCode = 'FA24');

WITH SectionRows AS (
    SELECT ROW_NUMBER() OVER (ORDER BY c.CourseId, t.TeacherId) AS rn,
           c.CourseId, t.TeacherId,
           c.CourseCode,
           ROW_NUMBER() OVER (PARTITION BY c.CourseId ORDER BY t.TeacherId) AS sec_num
    FROM dbo.Courses c
    CROSS JOIN (SELECT TOP 6 TeacherId FROM dbo.Teachers ORDER BY TeacherId) t
    WHERE c.Credits <= 4
)
INSERT INTO dbo.ClassSections (SemesterId, CourseId, TeacherId, SectionCode, IsOpen, MaxCapacity, Room)
SELECT TOP 100
    CASE WHEN rn % 4 = 1 THEN @SP26Id2
         WHEN rn % 4 = 2 THEN @FA25Id2
         WHEN rn % 4 = 3 THEN @SP25Id2
         ELSE @FA24Id2 END,
    CourseId,
    TeacherId,
    CourseCode + '-S' + RIGHT('00' + CAST(sec_num AS VARCHAR(3)), 2),
    1,
    CASE WHEN rn % 3 = 0 THEN 25 WHEN rn % 3 = 1 THEN 30 ELSE 35 END,
    'Room-' + CAST((rn % 20) + 101 AS VARCHAR(5))
FROM SectionRows
WHERE sec_num <= 3;
GO

-- =====================================================
-- SEED: Enrollments (100 rows)
-- Dùng SELECT dynamic từ Students x ClassSections
-- =====================================================
-- Dùng CTE để đảm bảo mỗi (StudentId, CourseId, SemesterId) chỉ xuất hiện 1 lần
;WITH UniqueEnrollments AS (
    SELECT
        s.StudentId,
        cs.ClassSectionId,
        cs.SemesterId,
        cs.CourseId,
        CASE WHEN c.Credits > 4 THEN 4 ELSE c.Credits END AS CreditsSnapshot,
        ROW_NUMBER() OVER (PARTITION BY s.StudentId, cs.CourseId, cs.SemesterId ORDER BY cs.ClassSectionId) AS dup_rn,
        ROW_NUMBER() OVER (ORDER BY s.StudentId, cs.ClassSectionId) AS global_rn
    FROM dbo.Students s
    CROSS JOIN dbo.ClassSections cs
    JOIN dbo.Courses c ON c.CourseId = cs.CourseId
    WHERE cs.IsOpen = 1
      AND c.Credits <= 4
)
INSERT INTO dbo.Enrollments (StudentId, ClassSectionId, SemesterId, CourseId, CreditsSnapshot, Status)
SELECT TOP 100
    StudentId, ClassSectionId, SemesterId, CourseId, CreditsSnapshot,
    CASE WHEN global_rn % 6 = 0 THEN 'COMPLETED'
         WHEN global_rn % 6 = 1 THEN 'ENROLLED'
         WHEN global_rn % 6 = 2 THEN 'ENROLLED'
         WHEN global_rn % 6 = 3 THEN 'ENROLLED'
         WHEN global_rn % 6 = 4 THEN 'DROPPED'
         ELSE 'COMPLETED' END
FROM UniqueEnrollments
WHERE dup_rn = 1  -- chỉ lấy 1 section per Student-Course-Semester
ORDER BY StudentId, ClassSectionId;
GO

-- Update CurrentEnrollment counts
UPDATE cs SET cs.CurrentEnrollment = sub.cnt
FROM dbo.ClassSections cs
JOIN (
    SELECT ClassSectionId, COUNT(*) AS cnt
    FROM dbo.Enrollments
    WHERE Status IN ('ENROLLED','COMPLETED')
    GROUP BY ClassSectionId
) sub ON sub.ClassSectionId = cs.ClassSectionId;
GO

-- =====================================================
-- SEED: GradeBooks (100 rows) - 1 per ClassSection
-- =====================================================
INSERT INTO dbo.GradeBooks (ClassSectionId, Status, Version)
SELECT TOP 100
    ClassSectionId,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY ClassSectionId) % 4 = 0 THEN 'PUBLISHED'
         WHEN ROW_NUMBER() OVER (ORDER BY ClassSectionId) % 4 = 1 THEN 'DRAFT'
         WHEN ROW_NUMBER() OVER (ORDER BY ClassSectionId) % 4 = 2 THEN 'LOCKED'
         ELSE 'DRAFT' END,
    1
FROM dbo.ClassSections
WHERE ClassSectionId NOT IN (SELECT ClassSectionId FROM dbo.GradeBooks)
ORDER BY ClassSectionId;
GO

-- =====================================================
-- SEED: GradeItems (100 rows)
-- =====================================================
INSERT INTO dbo.GradeItems (GradeBookId, ItemName, MaxScore, Weight, IsRequired, SortOrder)
SELECT TOP 100
    gb.GradeBookId,
    CASE WHEN rn % 5 = 1 THEN N'Điểm danh'
         WHEN rn % 5 = 2 THEN N'Kiểm tra giữa kỳ'
         WHEN rn % 5 = 3 THEN N'Quiz 1'
         WHEN rn % 5 = 4 THEN N'Bài tập lớn'
         ELSE N'Thi cuối kỳ' END,
    CASE WHEN rn % 5 = 1 THEN 10
         WHEN rn % 5 = 2 THEN 10
         WHEN rn % 5 = 3 THEN 10
         WHEN rn % 5 = 4 THEN 10
         ELSE 10 END,
    CASE WHEN rn % 5 = 1 THEN 0.1
         WHEN rn % 5 = 2 THEN 0.3
         WHEN rn % 5 = 3 THEN 0.1
         WHEN rn % 5 = 4 THEN 0.1
         ELSE 0.4 END,
    CASE WHEN rn % 5 = 5 THEN 1 ELSE 0 END,
    rn % 5
FROM (
    SELECT GradeBookId, ROW_NUMBER() OVER (ORDER BY GradeBookId) AS rn
    FROM dbo.GradeBooks
) gb
ORDER BY gb.GradeBookId;
GO

-- =====================================================
-- SEED: GradeEntries (100 rows)
-- =====================================================
INSERT INTO dbo.GradeEntries (GradeItemId, EnrollmentId, Score)
SELECT TOP 100
    gi.GradeItemId,
    e.EnrollmentId,
    CAST((5 + (gi.GradeItemId * 13 + e.EnrollmentId * 7) % 50) / 10.0 AS DECIMAL(5,2))
FROM dbo.GradeItems gi
CROSS JOIN dbo.Enrollments e
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.GradeEntries ge2
    WHERE ge2.GradeItemId = gi.GradeItemId AND ge2.EnrollmentId = e.EnrollmentId
)
AND EXISTS (
    SELECT 1 FROM dbo.GradeBooks gb
    JOIN dbo.ClassSections cs ON cs.ClassSectionId = gb.ClassSectionId
    WHERE gb.GradeBookId = gi.GradeBookId AND cs.ClassSectionId = e.ClassSectionId
)
ORDER BY gi.GradeItemId, e.EnrollmentId;
GO

-- =====================================================
-- SEED: ChatRooms (100 rows)
-- =====================================================
DECLARE @AdminUserId INT = (SELECT TOP 1 UserId FROM dbo.Users WHERE Role = 'ADMIN');
INSERT INTO dbo.ChatRooms (RoomType, ClassSectionId, RoomName, Status, CreatedBy)
SELECT TOP 50
    'CLASS',
    ClassSectionId,
    N'Phòng chat - ' + SectionCode,
    'ACTIVE',
    @AdminUserId
FROM dbo.ClassSections
ORDER BY ClassSectionId;

INSERT INTO dbo.ChatRooms (RoomType, CourseId, RoomName, Status, CreatedBy)
SELECT TOP 50
    'COURSE',
    CourseId,
    N'Diễn đàn môn - ' + CourseName,
    'ACTIVE',
    @AdminUserId
FROM dbo.Courses
ORDER BY CourseId;
GO

-- =====================================================
-- SEED: ChatRoomMembers (100 rows)
-- =====================================================
INSERT INTO dbo.ChatRoomMembers (RoomId, UserId, RoleInRoom, MemberStatus)
SELECT TOP 100
    cr.RoomId,
    u.UserId,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY cr.RoomId, u.UserId) % 10 = 0 THEN 'OWNER'
         WHEN ROW_NUMBER() OVER (ORDER BY cr.RoomId, u.UserId) % 10 = 1 THEN 'MODERATOR'
         ELSE 'MEMBER' END,
    'JOINED'
FROM dbo.ChatRooms cr
CROSS JOIN (SELECT TOP 5 UserId FROM dbo.Users ORDER BY UserId) u
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.ChatRoomMembers m WHERE m.RoomId = cr.RoomId AND m.UserId = u.UserId
)
ORDER BY cr.RoomId, u.UserId;
GO

-- =====================================================
-- SEED: ChatMessages (100 rows)
-- =====================================================
INSERT INTO dbo.ChatMessages (RoomId, SenderId, MessageType, Content)
SELECT TOP 100
    cr.RoomId,
    u.UserId,
    'TEXT',
    N'Xin chào các bạn, đây là tin nhắn thứ ' + CAST(ROW_NUMBER() OVER (ORDER BY cr.RoomId, u.UserId) AS NVARCHAR(10)) + N' trong phòng chat!'
FROM dbo.ChatRooms cr
CROSS JOIN (SELECT TOP 5 UserId FROM dbo.Users ORDER BY UserId) u
ORDER BY cr.RoomId, u.UserId;
GO

-- =====================================================
-- SEED: Notifications (100 rows)
-- =====================================================
INSERT INTO dbo.Notifications (NotificationType, PayloadJson, Status)
SELECT TOP 100
    CASE WHEN rn % 4 = 0 THEN 'GRADE_PUBLISHED'
         WHEN rn % 4 = 1 THEN 'SCHEDULE_CHANGED'
         WHEN rn % 4 = 2 THEN 'CHAT_MENTION'
         ELSE 'SYSTEM_ALERT' END,
    '{"message":"Thông báo số ' + CAST(rn AS VARCHAR(10)) + '"}',
    CASE WHEN rn % 3 = 0 THEN 'DELIVERED' WHEN rn % 3 = 1 THEN 'SENT' ELSE 'PENDING' END
FROM (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn FROM dbo.Users) t
WHERE rn <= 100;
GO

-- NotificationRecipients (100 rows)
INSERT INTO dbo.NotificationRecipients (NotificationId, UserId)
SELECT TOP 100
    n.NotificationId,
    u.UserId
FROM dbo.Notifications n
CROSS JOIN (SELECT TOP 5 UserId FROM dbo.Users ORDER BY UserId) u
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.NotificationRecipients nr WHERE nr.NotificationId = n.NotificationId AND nr.UserId = u.UserId
)
ORDER BY n.NotificationId, u.UserId;
GO

-- =====================================================
-- SEED: StudentWallets (100 rows, 1 per student)
-- =====================================================
INSERT INTO dbo.StudentWallets (StudentId, Balance, WalletStatus)
SELECT StudentId,
       CAST((StudentId * 173 % 10000000) / 100.0 AS DECIMAL(18,2)),
       CASE WHEN StudentId % 10 = 0 THEN 'LOCKED' ELSE 'ACTIVE' END
FROM dbo.Students
WHERE StudentId NOT IN (SELECT StudentId FROM dbo.StudentWallets);
GO

-- =====================================================
-- SEED: TuitionFees (100 rows)
-- =====================================================
;WITH TuitionCTE AS (
    SELECT
        s.StudentId,
        sem.SemesterId,
        sem.StartDate,
        ROW_NUMBER() OVER (ORDER BY s.StudentId, sem.SemesterId) AS rn
    FROM dbo.Students s
    CROSS JOIN (SELECT TOP 5 SemesterId, StartDate FROM dbo.Semesters ORDER BY SemesterId) sem
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.TuitionFees tf WHERE tf.StudentId = s.StudentId AND tf.SemesterId = sem.SemesterId
    )
)
INSERT INTO dbo.TuitionFees (StudentId, SemesterId, TotalCredits, AmountPerCredit, TotalAmount, PaidAmount, Status, DueDate)
SELECT TOP 100
    StudentId,
    SemesterId,
    CASE WHEN rn % 4 = 0 THEN 12 WHEN rn % 4 = 1 THEN 15 WHEN rn % 4 = 2 THEN 16 ELSE 9 END,
    500000,
    CASE WHEN rn % 4 = 0 THEN 12 WHEN rn % 4 = 1 THEN 15 WHEN rn % 4 = 2 THEN 16 ELSE 9 END * 500000,
    CASE WHEN rn % 4 = 0 THEN (CASE WHEN rn % 4 = 0 THEN 12 WHEN rn % 4 = 1 THEN 15 WHEN rn % 4 = 2 THEN 16 ELSE 9 END) * 500000
         WHEN rn % 4 = 1 THEN 0
         ELSE (CASE WHEN rn % 4 = 0 THEN 12 WHEN rn % 4 = 1 THEN 15 WHEN rn % 4 = 2 THEN 16 ELSE 9 END) * 250000 END,
    CASE WHEN rn % 4 = 0 THEN 'PAID'
         WHEN rn % 4 = 1 THEN 'UNPAID'
         WHEN rn % 4 = 2 THEN 'PARTIAL'
         ELSE 'OVERDUE' END,
    DATEADD(DAY, 30, StartDate)
FROM TuitionCTE
ORDER BY StudentId, SemesterId;
GO

-- =====================================================
-- SEED: Quizzes (100 rows)
-- =====================================================
INSERT INTO dbo.Quizzes (ClassSectionId, CreatedBy, QuizTitle, Description, TotalQuestions, TimeLimitMin, ShuffleQuestions, ShuffleAnswers, Status)
SELECT TOP 100
    cs.ClassSectionId,
    t.TeacherId,
    N'Quiz ' + CAST(ROW_NUMBER() OVER (ORDER BY cs.ClassSectionId) AS NVARCHAR(10)) + N' - ' + c.CourseName,
    N'Kiểm tra kiến thức môn ' + c.CourseName,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY cs.ClassSectionId) % 3 = 0 THEN 10
         WHEN ROW_NUMBER() OVER (ORDER BY cs.ClassSectionId) % 3 = 1 THEN 20
         ELSE 30 END,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY cs.ClassSectionId) % 3 = 0 THEN 15
         WHEN ROW_NUMBER() OVER (ORDER BY cs.ClassSectionId) % 3 = 1 THEN 30
         ELSE 45 END,
    1, 1,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY cs.ClassSectionId) % 3 = 0 THEN 'PUBLISHED'
         WHEN ROW_NUMBER() OVER (ORDER BY cs.ClassSectionId) % 3 = 1 THEN 'DRAFT'
         ELSE 'CLOSED' END
FROM dbo.ClassSections cs
JOIN dbo.Courses c ON c.CourseId = cs.CourseId
JOIN dbo.Teachers t ON t.TeacherId = cs.TeacherId
ORDER BY cs.ClassSectionId;
GO

-- =====================================================
-- SEED: QuizQuestions (100 rows)
-- =====================================================
INSERT INTO dbo.QuizQuestions (QuizId, QuestionText, QuestionType, Points, SortOrder)
SELECT TOP 100
    q.QuizId,
    N'Câu hỏi số ' + CAST(ROW_NUMBER() OVER (ORDER BY q.QuizId) AS NVARCHAR(10)) + N': Nội dung kiến thức quan trọng về chủ đề?',
    CASE WHEN ROW_NUMBER() OVER (ORDER BY q.QuizId) % 3 = 0 THEN 'TRUE_FALSE' ELSE 'MCQ' END,
    1.0,
    ROW_NUMBER() OVER (PARTITION BY q.QuizId ORDER BY q.QuizId) - 1
FROM dbo.Quizzes q
CROSS JOIN (SELECT 1 AS x UNION ALL SELECT 2 UNION ALL SELECT 3) x
ORDER BY q.QuizId;
GO

-- =====================================================
-- SEED: QuizAnswers (100 rows)
-- =====================================================
INSERT INTO dbo.QuizAnswers (QuestionId, AnswerText, IsCorrect)
SELECT TOP 100
    qq.QuestionId,
    CASE WHEN rn2 % 4 = 0 THEN N'Đáp án A' WHEN rn2 % 4 = 1 THEN N'Đáp án B'
         WHEN rn2 % 4 = 2 THEN N'Đáp án C' ELSE N'Đáp án D' END,
    CASE WHEN rn2 % 4 = 0 THEN 1 ELSE 0 END
FROM (
    SELECT QuestionId, ROW_NUMBER() OVER (ORDER BY QuestionId) AS rn,
           ROW_NUMBER() OVER (PARTITION BY QuestionId ORDER BY QuestionId) AS rn2
    FROM dbo.QuizQuestions
) qq
CROSS JOIN (SELECT 1 AS x UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4) x
ORDER BY qq.QuestionId;
GO

-- =====================================================
-- SEED: AIChatSessions (100 rows)
-- =====================================================
INSERT INTO dbo.AIChatSessions (UserId, Purpose, ModelName, State, PromptVersion)
SELECT TOP 100
    u.UserId,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY u.UserId) % 3 = 0 THEN 'SCORE_SUMMARY'
         WHEN ROW_NUMBER() OVER (ORDER BY u.UserId) % 3 = 1 THEN 'STUDY_PLAN'
         ELSE 'COURSE_SUGGESTION' END,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY u.UserId) % 2 = 0 THEN 'gemini-1.5-flash' ELSE 'gemini-1.5-pro' END,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY u.UserId) % 3 = 0 THEN 'COMPLETED' ELSE 'ACTIVE' END,
    'v1.0'
FROM dbo.Users u
CROSS JOIN (SELECT 1 AS x UNION ALL SELECT 2) dup
ORDER BY u.UserId;
GO

-- =====================================================
-- SEED: AIChatMessages (100 rows)
-- =====================================================
INSERT INTO dbo.AIChatMessages (ChatSessionId, SenderType, Content)
SELECT TOP 100
    s.ChatSessionId,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY s.ChatSessionId) % 3 = 0 THEN 'ASSISTANT'
         WHEN ROW_NUMBER() OVER (ORDER BY s.ChatSessionId) % 3 = 1 THEN 'USER'
         ELSE 'SYSTEM' END,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY s.ChatSessionId) % 3 = 1 
         THEN N'Hãy tóm tắt điểm số học kỳ SP26 cho tôi'
         WHEN ROW_NUMBER() OVER (ORDER BY s.ChatSessionId) % 3 = 0 
         THEN N'Điểm của bạn học kỳ SP26: Trung bình 7.5, đã hoàn thành 12 tín chỉ.'
         ELSE N'[Khởi tạo phiên AI]' END
FROM dbo.AIChatSessions s
CROSS JOIN (SELECT 1 AS x UNION ALL SELECT 2) dup
ORDER BY s.ChatSessionId;
GO

-- =====================================================
-- SEED: Recurrences (100 rows) for ScheduleEvents
-- =====================================================
INSERT INTO dbo.Recurrences (RRule, StartDate, EndDate)
SELECT TOP 100
    CASE WHEN ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 3 = 0 
         THEN 'FREQ=WEEKLY;BYDAY=MO,WE;INTERVAL=1'
         WHEN ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 3 = 1 
         THEN 'FREQ=WEEKLY;BYDAY=TU,TH;INTERVAL=1'
         ELSE 'FREQ=WEEKLY;BYDAY=FR;INTERVAL=1' END,
    '2026-01-05',
    '2026-04-30'
FROM dbo.ClassSections
ORDER BY ClassSectionId;
GO

-- =====================================================
-- SEED: ScheduleEvents (100 rows)
-- =====================================================
INSERT INTO dbo.ScheduleEvents (ClassSectionId, Title, StartAt, EndAt, Location, Status, CreatedBy)
SELECT TOP 100
    cs.ClassSectionId,
    N'Buổi học ' + c.CourseName + N' - Tuần ' + CAST(ROW_NUMBER() OVER (ORDER BY cs.ClassSectionId) % 16 + 1 AS NVARCHAR(5)),
    DATEADD(DAY, (ROW_NUMBER() OVER (ORDER BY cs.ClassSectionId) % 90), '2026-01-05T07:30:00'),
    DATEADD(HOUR, 3, DATEADD(DAY, (ROW_NUMBER() OVER (ORDER BY cs.ClassSectionId) % 90), '2026-01-05T07:30:00')),
    cs.Room,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY cs.ClassSectionId) % 4 = 0 THEN 'COMPLETED'
         WHEN ROW_NUMBER() OVER (ORDER BY cs.ClassSectionId) % 4 = 1 THEN 'PUBLISHED'
         WHEN ROW_NUMBER() OVER (ORDER BY cs.ClassSectionId) % 4 = 2 THEN 'DRAFT'
         ELSE 'RESCHEDULED' END,
    (SELECT TOP 1 UserId FROM dbo.Users WHERE Role = 'ADMIN')
FROM dbo.ClassSections cs
JOIN dbo.Courses c ON c.CourseId = cs.CourseId
ORDER BY cs.ClassSectionId;
GO

-- =====================================================
-- SEED: GradeBookApprovals (100 rows)
-- =====================================================
INSERT INTO dbo.GradeBookApprovals (GradeBookId, RequestBy, RequestMessage, ResponseBy, ResponseMessage, Outcome, ResponseAt)
SELECT TOP 100
    gb.GradeBookId,
    t.TeacherId,
    N'Đề nghị duyệt sổ điểm cho lớp ' + cs.SectionCode,
    (SELECT TOP 1 UserId FROM dbo.Users WHERE Role = 'ADMIN'),
    CASE WHEN ROW_NUMBER() OVER (ORDER BY gb.GradeBookId) % 3 = 0 THEN N'Đã duyệt'
         WHEN ROW_NUMBER() OVER (ORDER BY gb.GradeBookId) % 3 = 1 THEN N'Cần bổ sung thông tin'
         ELSE NULL END,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY gb.GradeBookId) % 3 = 0 THEN 'APPROVED'
         WHEN ROW_NUMBER() OVER (ORDER BY gb.GradeBookId) % 3 = 1 THEN 'REJECTED'
         ELSE NULL END,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY gb.GradeBookId) % 3 = 2 THEN NULL
         ELSE SYSUTCDATETIME() END
FROM dbo.GradeBooks gb
JOIN dbo.ClassSections cs ON cs.ClassSectionId = gb.ClassSectionId
JOIN dbo.Teachers t ON t.TeacherId = cs.TeacherId
ORDER BY gb.GradeBookId;
GO

-- =====================================================
-- SEED: PaymentTransactions (100 rows)
-- =====================================================
INSERT INTO dbo.PaymentTransactions (StudentId, PaymentMethod, MoMoRequestId, MoMoOrderId, MoMoTransId, Amount, OrderInfo, Status, ErrorCode, PaymentDate)
SELECT TOP 100
    s.StudentId,
    'MOMO',
    'REQ-' + CAST(s.StudentId AS VARCHAR(10)) + '-' + CAST(ROW_NUMBER() OVER (ORDER BY s.StudentId) AS VARCHAR(10)),
    'ORD-' + CAST(s.StudentId * 100 + ROW_NUMBER() OVER (ORDER BY s.StudentId) AS VARCHAR(20)),
    CASE WHEN ROW_NUMBER() OVER (ORDER BY s.StudentId) % 4 = 0 THEN NULL
         ELSE CAST(s.StudentId * 1000 + ROW_NUMBER() OVER (ORDER BY s.StudentId) AS BIGINT) END,
    CAST((3 + ROW_NUMBER() OVER (ORDER BY s.StudentId) % 10) * 500000 AS DECIMAL(18,2)),
    N'Nạp tiền học phí kỳ SP26 - SV ' + u.FullName,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY s.StudentId) % 4 = 0 THEN 'FAILED'
         WHEN ROW_NUMBER() OVER (ORDER BY s.StudentId) % 4 = 1 THEN 'PENDING'
         ELSE 'SUCCESS' END,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY s.StudentId) % 4 = 0 THEN 9999
         WHEN ROW_NUMBER() OVER (ORDER BY s.StudentId) % 4 = 1 THEN NULL
         ELSE 0 END,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY s.StudentId) % 4 < 2 THEN NULL
         ELSE SYSUTCDATETIME() END
FROM dbo.Students s
JOIN dbo.Users u ON u.UserId = s.StudentId
CROSS JOIN (SELECT 1 AS x UNION ALL SELECT 2) dup
ORDER BY s.StudentId;
GO

-- =====================================================
-- SEED: WalletTransactions (100 rows)
-- =====================================================
INSERT INTO dbo.WalletTransactions (WalletId, Amount, TransactionType, Description)
SELECT TOP 100
    sw.WalletId,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY sw.WalletId) % 3 = 0 THEN -CAST((5 + ROW_NUMBER() OVER (ORDER BY sw.WalletId) % 10) * 500000 AS DECIMAL(18,2))
         WHEN ROW_NUMBER() OVER (ORDER BY sw.WalletId) % 3 = 1 THEN -CAST((3 + ROW_NUMBER() OVER (ORDER BY sw.WalletId) % 8) * 500000 AS DECIMAL(18,2))
         ELSE CAST((5 + ROW_NUMBER() OVER (ORDER BY sw.WalletId) % 20) * 500000 AS DECIMAL(18,2)) END,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY sw.WalletId) % 3 = 0 THEN 'TUITION_PAYMENT'
         WHEN ROW_NUMBER() OVER (ORDER BY sw.WalletId) % 3 = 1 THEN 'REFUND'
         ELSE 'DEPOSIT' END,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY sw.WalletId) % 3 = 0 THEN N'Thanh toán học phí kỳ SP26'
         WHEN ROW_NUMBER() OVER (ORDER BY sw.WalletId) % 3 = 1 THEN N'Hoàn tiền do huỷ đăng ký môn học'
         ELSE N'Nạp tiền qua MoMo' END
FROM dbo.StudentWallets sw
CROSS JOIN (SELECT 1 AS x UNION ALL SELECT 2) dup
ORDER BY sw.WalletId;
GO

PRINT 'Seed data inserted successfully!';
