# Copilot Instructions — TPFUniversity / SchoolManagement (PRN222_G5)

> **Goal:** Build a “Student Management System” using a strict 3-layer architecture (**.NET + EF Core DB-First + SQL Server**) with these modules:  
> **Course registration + Wallet/MoMo**, **Chat (SignalR)**, **Gradebook + approval/publishing**, **Online quiz + auto-grading**, **Schedule/Calendar**, **AI Assistant (Gemini tool-calling)**.

---

## 0) Non‑negotiable rules

1. **Respect the 3‑layer architecture**
   - `Presentation` handles **UI only**: binding, authorization attributes, calling services, showing errors/notifications.
   - `BusinessLogic` holds **business rules**, validation, orchestration, and transaction boundaries.
   - `DataAccess` does **data access only** (EF Core queries + repository pattern). No business rules.
   - `BusinessObject` holds **Entities + Enums/Constants** shared across layers.

2. **Database‑First is the source of truth**
   - `PRN222_G5.sql` is the **single source of truth**.
   - If you need new fields/statuses/constraints → **update SQL first**, then re‑scaffold EF Core.
   - Do **not** hand‑edit scaffolded entity files in ways that break re‑scaffolding. Extend via **partial classes**, **extension methods**, and **DTO mapping**.

3. **No business logic in Razor**
   - Do not query `DbContext` in `.cshtml` or PageModel/Controller for business workflows.
   - PageModel/Controller should do: get user context → call service → render.

4. **Async‑first**
   - Repos/services use `async/await` (`ToListAsync`, `FirstOrDefaultAsync`, …).
   - Avoid `.Result` / `.Wait()`.

---

## 1) Solution context & folder boundaries

**Recommended structure**
- `Presentation/` (ASP.NET Core Razor Pages + Areas, SignalR Hubs, wwwroot)
- `BusinessLogic/Services/Interfaces|Implements/`
- `BusinessLogic/DTOs/Request|Response/`
- `DataAccess/Repositories/Interfaces|Implements/`
- `DataAccess/SchoolManagementDbContext.cs`
- `BusinessObject/Entities/` (EF Core DB‑first entities)
- `BusinessObject/Enum/` (Role, Status, …)

**Dependency rules**
- Presentation → BusinessLogic → DataAccess → BusinessObject
- BusinessLogic can reference BusinessObject (Entities/Enums/Constants)
- Presentation must **not** reference DataAccess directly.

---

## 2) Coding standards & conventions

### 2.1 Naming
- Interface: `IStudentService`, `IEnrollmentRepository`
- Implementation: `StudentService`, `EnrollmentRepository`
- DTO:
  - Request: `CreateEnrollmentRequest`, `DepositWalletRequest`, `SendChatMessageRequest`
  - Response: `EnrollmentResponse`, `WalletBalanceResponse`, `PagedResult<T>`
- Enum: `EnrollmentStatus`, `GradeBookStatus`, `ChatRoomStatus`, `QuizStatus`

### 2.2 Errors & result pattern
- Prefer structured results from services:
  - `ServiceResult<T>`: `IsSuccess`, `ErrorCode`, `Message`, `Data`
- Do not throw for normal business errors (validation/rule violations). Throw only for system errors.

### 2.3 Logging
- Use `ILogger<T>` in services and repositories:
  - `Information`: key flows (Approve/Reject, Payment success/fail).
  - `Warning`: rule violations (insufficient funds, time conflict).
  - `Error`: exceptions/system failures.

### 2.4 Validation
- UI-level: DataAnnotations in ViewModels/DTOs.
- Business-level: validate in services (especially complex constraints like time conflict, prerequisites, credit limits).

### 2.5 Query performance
- Read-only queries: `AsNoTracking()`.
- Avoid N+1: use `Include/ThenInclude` where necessary.
- Pagination: always support `pageIndex/pageSize` with stable sorting.

---

## 3) Authentication / Authorization

- Auth: **Cookie-based**.
- Roles stored in `Users.Role`: `STUDENT | TEACHER | ADMIN` (enforced by DB CHECK).
- Presentation:
  - `[Authorize(Roles="ADMIN")]` for admin areas.
  - Separate routes/layout/menus by Areas (Admin/Teacher/Student).
- Always derive `UserId` from claims and map to `Users` / `Students` / `Teachers`.

---

## 4) Database model cheat‑sheet (use the real SQL schema)

> When implementing, always match tables/columns/constraints from the SQL script.

### Identity & catalog
- `Users(UserId, Username, PasswordHash, Role, IsActive, …)`
- `Students(StudentId PK/FK Users, StudentCode, ProgramId, CurrentSemesterId, …)`
- `Teachers(TeacherId PK/FK Users, TeacherCode, Department, …)`
- `Programs`, `Semesters`, `Courses`, `CoursePrerequisites`

### Classes & enrollment
- `ClassSections(ClassSectionId, SemesterId, CourseId, TeacherId, SectionCode, MaxCapacity, CurrentEnrollment, IsOpen, …)`
- `Enrollments(EnrollmentId, StudentId, ClassSectionId, SemesterId, CourseId, CreditsSnapshot, Status, …)`
  - Current CHECK statuses: `ENROLLED|WAITLIST|DROPPED|WITHDRAWN|COMPLETED|CANCELED`
  - Unique filtered index prevents duplicate active enrollments: `ENROLLED|WITHDRAWN`

### Gradebook
- `GradeBooks(GradeBookId, ClassSectionId UNIQUE, Status=DRAFT|PUBLISHED|LOCKED|ARCHIVED, Version, …)`
- `GradeBookApprovals` (approval request history)
- `GradeItems(GradeItemId, GradeBookId, ItemName, MaxScore, Weight[0..1], SortOrder, …)`
- `GradeEntries(GradeEntryId, GradeItemId, EnrollmentId, Score[0..10], UpdatedBy, …)`
- `GradeAuditLogs` (trace grade changes)

### Chat (SignalR)
- `ChatRooms(RoomId, RoomType=COURSE|CLASS|GROUP|DM, Status=ACTIVE|LOCKED|ARCHIVED|DELETED, …)`
- `ChatRoomMembers(RoomId, UserId, RoleInRoom, MemberStatus, LastReadMessageId, …)`
- `ChatMessages(MessageId, RoomId, SenderId, MessageType=TEXT|SYSTEM, …)`
- `ChatMessageAttachments`, `ChatModerationLogs`

### Quiz
- `Quizzes(Status=DRAFT|PUBLISHED|CLOSED, TotalQuestions IN (10,20,30), Shuffle*, StartAt/EndAt, …)`
- `QuizQuestions(Type=MCQ|TRUE_FALSE)`
- `QuizAnswers(IsCorrect)`
- `QuizAttempts(Status=IN_PROGRESS|SUBMITTED|GRADED, UNIQUE(QuizId, EnrollmentId))`
- `QuizAttemptAnswers`

### Finance / MoMo / Wallet
- `StudentWallets(StudentId UNIQUE, Balance, WalletStatus=ACTIVE|LOCKED)`
- `PaymentTransactions` (MoMo requestId/orderId/transId, Status=PENDING|SUCCESS|FAILED|CANCELLED)
- `WalletTransactions` (DEPOSIT|TUITION_PAYMENT|REFUND, Amount +/-, links Payment/TuitionFee)
- `TuitionFees` (Status=UNPAID|PARTIAL|PAID|OVERDUE)

---

## 5) Module implementation rules (business invariants)

### 5.1 Course registration + Wallet + MoMo deposit
**When registering a class (Student “Register & Pay”):**
- Must run inside a **DB transaction**.
- Minimum flow:
  1) Validate: semester window, duplicate enrollment, prerequisites, credit max, time conflict (service-level).
  2) Validate capacity: `CurrentEnrollment < MaxCapacity` and `IsOpen = 1`.
  3) Validate wallet: `StudentWallets.Balance >= tuitionFee`.
  4) Atomic updates:
     - Deduct wallet (Balance -= fee)
     - Insert `WalletTransactions` (TUITION_PAYMENT, negative amount)
     - Insert `Enrollments` with the correct status
     - Increment `ClassSections.CurrentEnrollment += 1`
- **Concurrency:** prevent overbooking & double-spend.
  - Prefer `BeginTransaction(IsolationLevel.Serializable)` **or** row-level locking (`UPDLOCK, HOLDLOCK`) when reading `ClassSections` and `StudentWallets`.
- **Idempotency (MoMo):** enforce uniqueness by `MoMoOrderId` (unique index) to avoid duplicate deposits.

**Important note about “Approve/Reject enrollment”:**
- The functional spec mentions statuses like `PENDING_APPROVAL`, `REJECTED` + refund/release slot.
- If the DB CHECK constraint does not include these statuses, you must:
  - Update SQL CHECK + re-scaffold, **or**
  - Implement “pending” via a separate table/flag until schema is updated.

### 5.2 Gradebook (Admin defines structure, Teacher inputs, Admin approves/publishes/locks)
- **Admin**
  - Only Admin can CRUD `GradeItems` and change grade structure (weights sum to 1.0 / 100%).
  - Approve/Reject and Lock.
- **Teacher**
  - Can edit `GradeEntries` only when gradebook is editable.
- **Audit is mandatory**
  - Every grade change must write to `GradeAuditLogs` (old/new values + actor + timestamp + optional reason).
- **Approval flow**
  - Use `GradeBookApprovals` for request/approve/reject history.
  - If the spec needs `PENDING_APPROVAL`/`REJECTED` but DB status CHECK doesn’t support it, update SQL first.

### 5.3 Chat (SignalR real-time)
- Hub group name: `room:{roomId}`.
- Rules:
  - Only members can connect/read.
  - Only members in an `ACTIVE` room can send.
  - If a member is `READ_ONLY`, they cannot send.
- Persist message first, then broadcast.
- Update `LastReadMessageId` when user reads.
- Soft-delete messages (`DeletedAt`), no hard deletes.
- Moderation actions must be logged to `ChatModerationLogs`.

### 5.4 Quiz (authoring, attempt, auto-grading, Gradebook sync)
- Teacher workflow: `DRAFT` → add questions/answers → `PUBLISHED`.
- Student attempt:
  - Allowed only in `StartAt..EndAt` window and when quiz is `PUBLISHED`.
  - Enforce 1 attempt per enrollment: unique `(QuizId, EnrollmentId)`.
- Auto-grade:
  - Compute raw score by correct answers/points.
  - Convert to 10‑point scale if required: `FinalScore = (RawScore / TotalMaxPoints) * 10`.
- Gradebook sync:
  - Create or map a `GradeItem` like `Quiz: {QuizTitle}`.
  - Upsert `GradeEntry` for the enrollment.
  - Never return `IsCorrect` to clients.

### 5.5 Calendar / Schedule
- Schedule events should link to `ClassSectionId`.
- Optional recurrence via `Recurrences(RRule)`.
- Backend supports querying events by date range; UI renders day/week/month.

### 5.6 AI Assistant (Gemini)
- **Gemini must not access the DB directly.**
- Create `IAiAssistantService` that:
  - Accepts UI requests (student/teacher).
  - Builds a minimal “academic snapshot” (aggregated and sanitized) and sends it to Gemini.
  - Exposes internal tool-calling methods, e.g.:
    - `GetStudentAcademicSnapshot(studentId, semesterId)`
    - `GetCurrentEnrollments(studentId, semesterId)`
    - `GetCourseCatalog(programId, semesterId)`
    - `SimulatePlan(studentId, courseIds[])`
- **Data minimization:** never send unnecessary PII (email, password hash, etc.).
- **Guardrails:** the AI can recommend/advise, but must not mutate DB state without explicit UI confirmation.

---

## 6) Repository & service contracts (shape guidance)

### Repository
- Read:
  - `Task<Student?> GetStudentByUserIdAsync(int userId)`
  - `Task<ClassSection?> GetClassSectionForUpdateAsync(int classSectionId)` (row lock)
- Write:
  - `Task AddEnrollmentAsync(Enrollment entity)`
  - `Task UpdateWalletBalanceAsync(int walletId, decimal delta, …)`

### Service
- `IEnrollmentService.RegisterAndPayAsync(userId, classSectionId)`
- `IEnrollmentService.ApproveEnrollmentAsync(adminUserId, enrollmentId)` / `RejectEnrollmentAsync(...)`
- `IGradebookService.RequestApprovalAsync(teacherUserId, classSectionId, message)`
- `IChatService.SendMessageAsync(userId, roomId, content, attachments)`
- `IQuizService.SubmitAttemptAsync(userId, quizId, answers)`
- `IAiAssistantService.ChatAsync(userId, sessionId, userMessage)`

**Services are responsible for**
- Business authorization (role/ownership).
- Transactions & consistency.
- Mapping Entities → DTOs.

---

## 7) Copilot generation checklist (must follow)

1) Put files in the correct layer with correct namespaces.  
2) Never bypass services/repositories.  
3) Do not hardcode secrets/connection strings; use configuration.  
4) Add validation, null-handling, and explicit error codes.  
5) Use async; consider cancellation tokens where relevant.  
6) Write audit logs where required (grade/chat moderation/payment).  
7) If you change workflow/status, update `PRN222_G5.sql`, update enums, and re‑scaffold EF Core.

---

## 8) Expected response format (Copilot chat output)

- Use: **Plan → Files to change → Code blocks → Notes**.
- If multiple files: list paths + why.
- If DB changes: include SQL snippets + remind to re-scaffold.

