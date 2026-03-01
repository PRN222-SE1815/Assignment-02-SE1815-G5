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
ADD CONSTRAINT CK_Enrollments_Status CHECK (Status IN (N'PENDING_APPROVAL',N'REJECTED', N'ENROLLED', N'WAITLIST', N'DROPPED', N'WITHDRAWN', N'COMPLETED', N'CANCELED'));
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
