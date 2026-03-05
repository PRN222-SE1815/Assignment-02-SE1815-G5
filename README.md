# School Management System

<div align="center">

![Language](https://img.shields.io/badge/Language-C%23-blue?style=flat-square)
![Framework](https://img.shields.io/badge/Framework-.NET%208-purple?style=flat-square)
![Database](https://img.shields.io/badge/Database-SQL%20Server-red?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

A comprehensive **Student Management System** built with a strict 3-layer architecture, featuring course registration, real-time chat, gradebook management, online quizzes, and AI-powered academic assistance.

[Features](#features) • [Architecture](#architecture) • [Prerequisites](#prerequisites) • [Installation](#installation) • [Configuration](#configuration) • [Running](#running) • [Module Guide](#module-guide) • [Database Schema](#database-schema)

</div>

---

## 📋 Overview

This is a professional-grade educational platform developed for **TPF University** as part of **PRN222 course (Assignment-02)** by **Group 5**. The system manages student enrollment, course registration with payment integration, gradebook workflows, real-time communication, online quizzes with auto-grading, scheduling, and AI-assisted academic planning.

**Key Statistics:**
- **Architecture:** 3-layer (Presentation → BusinessLogic → DataAccess → BusinessObject)
- **.NET Version:** .NET 8.0
- **Database:** SQL Server (Database-First approach with EF Core)
- **UI Framework:** ASP.NET Core Razor Pages
- **Real-time:** SignalR
- **AI Integration:** Google Gemini API

---

## ✨ Features

### 🎓 Core Academic Features

| Feature | Description | Status |
|---------|-------------|--------|
| **Course Registration** | Students register for courses with prerequisite validation and capacity checking | ✅ Complete |
| **Wallet & Payment** | Built-in wallet system with MoMo payment gateway integration | ✅ Complete |
| **Gradebook Management** | Admin defines structure, teachers input grades, approval workflow with audit logs | ✅ Complete |
| **Online Quizzes** | Teacher-created quizzes with auto-grading and Gradebook sync | ✅ Complete |
| **Schedule/Calendar** | Course timetable management with conflict detection | ✅ Complete |
| **Real-time Chat** | SignalR-based chat by course/class with message persistence | ✅ Complete |
| **AI Assistant** | Gemini-powered academic advisor for students & teachers | ✅ Complete |

### 👥 Role-Based Features

**Student:**
- View available courses and register with payment
- Check wallet balance and make deposits
- View grades and GPA
- Attempt quizzes and track scores
- Join course chat rooms
- Access AI academic advisor

**Teacher:**
- Manage class sections and schedule
- Create and publish quizzes
- Input and manage grades
- Access class chat rooms
- View student performance analytics
- Interact with AI assistant for teaching insights

**Admin:**
- User & course management
- Define gradebook structure and weights
- Approve/publish/lock grades
- Manage enrollment approvals
- System configuration and monitoring

---

## 🏗️ Architecture

### 3-Layer Design Pattern

```
┌─────────────────────────────────────────┐
│         PRESENTATION LAYER              │
│  (Razor Pages, SignalR Hubs, UI Logic)  │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│       BUSINESS LOGIC LAYER              │
│  (Services, DTOs, Business Rules)       │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│       DATA ACCESS LAYER                 │
│  (Repositories, EF Core, DbContext)     │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│       BUSINESS OBJECT LAYER             │
│  (Entities, Enums, DTOs)                │
└─────────────────────────────────────────┘
```

### Project Structure

```
Assignment-02-SE1815-G5/
├── Presentation/                 # ASP.NET Core Razor Pages
│   ├── Pages/                    # Shared pages (Login, Chat, Notifications)
│   ├── Areas/
│   │   ├── Admin/               # Admin dashboard & management
│   │   ├── Student/             # Student features
│   │   └── Teacher/             # Teacher features
│   ├── Hubs/                    # SignalR hubs for real-time
│   ├── Middleware/              # Custom middleware
│   ├── wwwroot/                 # Static assets (CSS, JS, Bootstrap)
│   └── Program.cs               # Dependency injection & configuration
│
├── BusinessLogic/               # Business rules & orchestration
│   ├── Services/
│   │   ├── Interfaces/          # Service contracts
│   │   └── Implements/          # Service implementations
│   ├── DTOs/
│   │   ├── Request/             # Input DTOs
│   │   └── Response/            # Output DTOs
│   └── Settings/                # Configuration models (MoMo, Gemini, etc.)
│
├── DataAccess/                  # Data persistence layer
│   ├── Repositories/
│   │   ├── Interfaces/          # Repository contracts
│   │   └── Implements/          # Repository implementations
│   ├── SchoolManagementDbContext.cs  # EF Core DbContext
│   └── Migrations/              # EF Core migrations
│
├── BusinessObject/              # Shared entities & enums
│   ├── Entities/                # EF Core entities (DB-first)
│   ├── Enums/                   # Status enums (Role, Status, etc.)
│   └── Constants/               # Application constants
│
└── PRN222_G5.sql               # Database schema (source of truth)
```

### Dependency Rules

```
✅ ALLOWED                       ❌ NOT ALLOWED
─────────────────────────────────────────────
Presentation → BusinessLogic     Presentation → DataAccess
BusinessLogic → DataAccess       DataAccess → Presentation
DataAccess → BusinessObject      BusinessObject → (any upper layer)
Any → BusinessObject
```

---

## 📋 Prerequisites

### System Requirements

- **Operating System:** Windows 10+ or Windows Server 2019+
- **RAM:** 4 GB minimum (8 GB recommended)
- **.NET SDK:** .NET 8.0 or higher
- **SQL Server:** SQL Server 2019+ (or SQL Server Express)
- **Visual Studio:** 2022 (Community, Professional, or Enterprise)

### Required Software

| Software | Version | Purpose |
|----------|---------|---------|
| .NET SDK | 8.0+ | Framework & build tools |
| SQL Server | 2019+ | Database server |
| SQL Server Management Studio (SSMS) | 19.0+ | Database management (optional but recommended) |
| Visual Studio | 2022 | IDE & development tools |
| Git | Latest | Version control |

### Required NuGet Packages (auto-installed)

- `Microsoft.EntityFrameworkCore.SqlServer` (v8.0.23)
- `Microsoft.EntityFrameworkCore.Tools` (v8.0.23)
- `Microsoft.AspNetCore.SignalR` (v8.0+)
- `Google.Api.Gax.Grpc` (for Gemini integration)

---

## 🚀 Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/PRN222-SE1815/Assignment-02-SE1815-G5.git
cd Assignment-02-SE1815-G5
```

### Step 2: Verify SQL Server Installation

Ensure SQL Server is running on your machine. The default connection uses:
- **Server:** `.` (local)
- **Authentication:** SQL Server authentication (sa user)

```cmd
# Verify SQL Server is running
sqlcmd -S . -U sa -P 12345
```

If SQL Server isn't installed or configured, download and install:
- [SQL Server 2022 Express](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)
- [SQL Server Management Studio](https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms)

### Step 3: Restore Dependencies

```bash
# Restore NuGet packages for all projects
dotnet restore
```

### Step 4: Create Database

Execute the database schema script:

**Option A: Using SQL Server Management Studio (GUI)**

1. Open **SSMS**
2. Connect to `.` (local server) with login `sa` / password `12345`
3. Open `PRN222_G5.sql` from the project root
4. Execute the script (F5)
5. Verify database **SchoolManagementDb** is created

**Option B: Using Command Line**

```bash
sqlcmd -S . -U sa -P 12345 -i PRN222_G5.sql
```

### Step 5: Open in Visual Studio

1. Open **Visual Studio 2022**
2. File → Open → Project/Solution → Select `Assignment-02-SE1815-G5` folder
3. Wait for solution to load and NuGet packages to restore
4. Set **Presentation** as startup project (right-click → Set as Startup Project)

---

## ⚙️ Configuration

### appsettings.json

The main configuration file is located at `Presentation/appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=.;Database=SchoolManagementDb;User Id=sa;Password=12345;TrustServerCertificate=True;Encrypt=True;"
  },
  "MoMo": {
    "PartnerCode": "MOMO",
    "AccessKey": "[YOUR_KEY]",
    "SecretKey": "[YOUR_SECRET]",
    "Endpoint": "https://test-payment.momo.vn/v2/gateway/api/create",
    "ReturnUrl": "https://localhost:7000/Payment/MoMoReturn",
    "NotifyUrl": "https://localhost:7000/Payment/MoMoNotify"
  },
  "Gemini": {
    "Model": "gemini-2.5-flash",
    "ApiKey": "[YOUR_GEMINI_API_KEY]"
  }
}
```

### Configuration Guide

#### 1. Database Connection String

**Current (Development):**
```
Server=.;Database=SchoolManagementDb;User Id=sa;Password=12345;TrustServerCertificate=True;Encrypt=True;
```

**Customize for your environment:**
- `Server`: Replace `.` with your SQL Server instance name or IP
- `Database`: Database name (default: SchoolManagementDb)
- `User Id`: SQL Server login username (default: sa)
- `Password`: SQL Server login password (default: 12345)

#### 2. MoMo Payment Gateway

The system integrates with **MoMo** for student wallet deposits:

1. Register at [MoMo Developer Portal](https://developers.momo.vn/)
2. Create a MoMo business account
3. Get your credentials:
   - `PartnerCode`
   - `AccessKey`
   - `SecretKey`
4. Update `Presentation/appsettings.json`:

```json
"MoMo": {
  "PartnerCode": "YOUR_PARTNER_CODE",
  "AccessKey": "YOUR_ACCESS_KEY",
  "SecretKey": "YOUR_SECRET_KEY",
  "Endpoint": "https://test-payment.momo.vn/v2/gateway/api/create",
  "ReturnUrl": "https://localhost:7000/Payment/MoMoReturn",
  "NotifyUrl": "https://localhost:7000/Payment/MoMoNotify"
}
```

**For development testing:** Leave empty to skip actual payment processing.

#### 3. Google Gemini API

The AI Assistant features require a Gemini API key:

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Create a new API key
3. Update `Presentation/appsettings.json`:

```json
"Gemini": {
  "Model": "gemini-2.5-flash",
  "ApiKey": "YOUR_GEMINI_API_KEY"
}
```

**For development without AI:** Leave `ApiKey` empty to disable AI features.

#### 4. Database-First EF Core

The project uses **Database-First** approach. If you modify the database schema:

```bash
# Re-scaffold EF Core entities from database
cd Presentation
dotnet ef dbcontext scaffold "Server=.;Database=SchoolManagementDb;User Id=sa;Password=12345;TrustServerCertificate=True;Encrypt=True;" Microsoft.EntityFrameworkCore.SqlServer -o ..\BusinessObject\Entities -f
```

---

## ▶️ Running the Application

### Method 1: Using Visual Studio (Recommended)

1. **Open the solution** in Visual Studio 2022
2. **Ensure Presentation is set as startup project**
3. **Press F5** or click **Debug → Start Debugging**
4. The application will open at `https://localhost:7000`

### Method 2: Using Command Line

```bash
cd Presentation
dotnet run
```

The application will be available at:
- **HTTPS:** https://localhost:7000
- **HTTP:** http://localhost:5000

### Verify Installation

After starting, you should see:
- ✅ Connection to SchoolManagementDb successful
- ✅ Razor Pages loaded without errors
- ✅ Login page displays

---

## 🔐 Default Login Credentials

The database includes pre-seeded accounts:

| Role | Username | Password | Purpose |
|------|----------|----------|---------|
| Admin | `admin1` | `Abc@1234` | Full system control |
| Teacher | `teacher1` | `Abc@1234` | Course & grade management |
| Student | `student1` | `Abc@1234` | Course enrollment & learning |

⚠️ **Security Note:** Change these passwords in production!

---

## 📚 Module Guide

### 1️⃣ Course Registration & Wallet

**Located:** Student → Course Registration, Wallet

**Features:**
- Browse available courses for current semester
- Check prerequisites and capacity
- Register with automatic fee deduction
- Wallet management with MoMo payment integration
- Transaction history

**Key Files:**
- `Presentation/Areas/Student/Pages/CourseRegistration/`
- `BusinessLogic/Services/IEnrollmentService.cs`
- `BusinessLogic/Services/IPaymentService.cs`

**Business Rules:**
- Course capacity checking
- Prerequisite validation
- Credit limit enforcement (min/max credits per semester)
- Time conflict detection
- Wallet balance validation before registration

---

### 2️⃣ Real-time Chat

**Located:** Chat (navigation menu)

**Features:**
- Course-based chat rooms
- Real-time messaging with SignalR
- User presence indicators
- Message persistence
- Read receipts

**Key Files:**
- `Presentation/Pages/Chat/`
- `Presentation/Hubs/ChatHub.cs`
- `BusinessLogic/Services/IChatService.cs`

**Business Rules:**
- Only room members can participate
- Messages are permanently stored
- Soft deletes (no hard deletion)
- Moderation audit trail

---

### 3️⃣ Gradebook Management

**Located:** 
- Teacher → Manage Grades
- Admin → Gradebook Management
- Student → View Grades

**Features:**
- **Admin:** Define grade items, weights, and structure
- **Teacher:** Input student grades with audit trail
- **Approval workflow:** Request → Review → Publish → Lock
- **Student:** View their grades and calculated GPA
- **Grade audit:** Track all grade changes with timestamps

**Key Files:**
- `Presentation/Areas/Teacher/Pages/TeacherGrade/`
- `Presentation/Areas/Admin/Pages/GradebookManagement/`
- `Presentation/Areas/Student/Pages/StudentGrade/`
- `BusinessLogic/Services/IGradebookService.cs`

**Business Rules:**
- Weights must sum to 1.0
- Only admins define structure
- Grade changes require audit logging
- Approval workflow enforced
- No grade entry without matching grade item

---

### 4️⃣ Online Quizzes

**Located:**
- Student → Quiz
- Teacher → Quiz Management

**Features:**
- **Teacher:** Create quizzes, set time windows, manage questions
- **Student:** Take quizzes during allowed window
- **Auto-grading:** Immediate score calculation
- **Gradebook sync:** Scores synced to gradebook
- **Question types:** Multiple choice, True/False
- **Analytics:** Teacher can view attempt statistics

**Key Files:**
- `Presentation/Areas/Student/Pages/Quiz/`
- `Presentation/Areas/Teacher/Pages/Quiz/`
- `BusinessLogic/Services/IQuizService.cs`
- `BusinessLogic/Services/IGradebookSyncService.cs`

**Business Rules:**
- Only one attempt per student per quiz
- Can only attempt during `StartAt` to `EndAt` window
- Auto-grade on submission (MCQ only)
- One-to-one enrollment sync to gradebook

---

### 5️⃣ Schedule & Calendar

**Located:** 
- Student → Schedule
- Teacher → Schedule
- Admin → Schedule Management

**Features:**
- View class timetables
- Conflict detection
- Calendar interface (day/week/month views)
- Recurring events support
- Date range filtering

**Key Files:**
- `Presentation/Areas/Student/Pages/StudentSchedule/`
- `Presentation/Areas/Teacher/Pages/TeacherSchedule/`
- `Presentation/Areas/Admin/Pages/ScheduleManagement/`
- `BusinessLogic/Services/IStudentScheduleService.cs`

---

### 6️⃣ AI Assistant

**Located:** Student/Teacher → AI Assistant

**Features:**
- Conversational AI powered by Google Gemini
- Academic advice and planning
- Course recommendations
- Quiz question explanation
- Study tips and resources

**Key Files:**
- `Presentation/Areas/Student/Pages/AI/`
- `BusinessLogic/Services/IAIChatService.cs`
- `BusinessLogic/Services/IGeminiClientService.cs`

**Important:** AI does **not** access the database directly. It works through carefully aggregated snapshots to maintain data privacy.

---

## 💾 Database Schema

The database consists of the following major table groups:

### Identity & Catalog
- `Users` - User accounts with roles
- `Programs` - Academic programs
- `Semesters` - Academic periods
- `Students` - Student profiles
- `Teachers` - Teacher profiles

### Course Management
- `Courses` - Course definitions
- `CoursePrerequisites` - Prerequisite relationships
- `ClassSections` - Course instances with schedule
- `Enrollments` - Student-Class relationships

### Gradebook
- `GradeBooks` - Gradebook instances per class
- `GradeItems` - Grade components (exams, assignments, etc.)
- `GradeEntries` - Individual student scores
- `GradeAuditLogs` - Grade change history
- `GradeBookApprovals` - Approval workflow

### Chat
- `ChatRooms` - Chat channels
- `ChatRoomMembers` - Room membership
- `ChatMessages` - Message content
- `ChatModerationLogs` - Moderation actions

### Quiz
- `Quizzes` - Quiz definitions
- `QuizQuestions` - Quiz questions
- `QuizAnswers` - Answer options
- `QuizAttempts` - Student attempts
- `QuizAttemptAnswers` - Submitted answers

### Finance
- `StudentWallets` - Student account balances
- `PaymentTransactions` - MoMo payment records
- `WalletTransactions` - Wallet debit/credit entries
- `TuitionFees` - Tuition charges

For complete schema details, see `PRN222_G5.sql`.

---

## 🛠️ Development Notes

### Key Technical Decisions

1. **Database-First with EF Core**
   - Schema is source of truth in `PRN222_G5.sql`
   - Entities are scaffolded from database
   - Extend entities with partial classes, don't modify generated code

2. **Async/Await First**
   - All data access is async
   - No `.Result` or `.Wait()` calls
   - Better scalability and responsiveness

3. **Transaction Handling**
   - Critical operations (enrollment + payment) use `IsolationLevel.Serializable`
   - Prevents race conditions and double-charges

4. **Service Layer Pattern**
   - Business logic isolated in services
   - Repositories handle data access only
   - Clear separation of concerns

5. **DTO Mapping**
   - Entities never exposed directly to Presentation
   - DTOs provide explicit contracts
   - Changes to database don't affect API

### Common Tasks

#### Add a New Database Table

1. Update `PRN222_G5.sql`
2. Run the script to create table
3. Re-scaffold EF entities:
   ```bash
   cd Presentation
   dotnet ef dbcontext scaffold "Server=.;Database=SchoolManagementDb;..." Microsoft.EntityFrameworkCore.SqlServer -o ..\BusinessObject\Entities -f
   ```
4. Create repository interface/implementation
5. Create service interface/implementation
6. Wire up dependency injection in `Program.cs`

#### Add a New Page

1. Create `.cshtml.cs` file in appropriate Area (Admin/Student/Teacher)
2. Inherit from `PageModel`
3. Inject required services via constructor
4. Create corresponding `.cshtml` view
5. Add route in `_ViewStart.cshtml` or via `@page` attribute

#### Add Authentication to a Page

```csharp
[Authorize(Roles = "ADMIN,TEACHER")]
public class ManagePage : PageModel
{
    // Page code
}
```

#### Create a New Service

1. Create interface: `IMyService` in `BusinessLogic/Services/Interfaces/`
2. Create implementation: `MyService` in `BusinessLogic/Services/Implements/`
3. Register in `Program.cs`:
   ```csharp
   builder.Services.AddScoped<IMyService, MyService>();
   ```

---

## 🐛 Troubleshooting

### Issue: "Cannot connect to database"

**Solution:**
```bash
# Verify SQL Server is running
sqlcmd -S . -U sa -P 12345

# Verify database exists
sqlcmd -S . -U sa -P 12345 -Q "SELECT name FROM sys.databases WHERE name='SchoolManagementDb'"

# Check connection string in appsettings.json
```

### Issue: "Port 7000 already in use"

**Solution:**
```bash
# Find process using port 7000
netstat -ano | findstr :7000

# Kill the process (replace PID)
taskkill /PID [PID] /F
```

### Issue: "Gemini API errors"

**Solution:**
- Verify API key is correct in `appsettings.json`
- Check internet connection
- Visit [Google AI Studio](https://aistudio.google.com/) to verify key is active

### Issue: "SignalR connection fails"

**Solution:**
- Ensure app is running in HTTPS (required for WebSockets)
- Check browser console for errors
- Verify firewall allows WebSocket connections

### Issue: "EF Core migration fails"

**Solution:**
```bash
# Reset and re-scaffold
cd Presentation
dotnet ef dbcontext scaffold "YOUR_CONNECTION_STRING" Microsoft.EntityFrameworkCore.SqlServer -o ..\BusinessObject\Entities -f
```

---

## 📊 Performance Optimization Tips

1. **Asynchronous Operations**
   - Use `ToListAsync()`, `FirstOrDefaultAsync()` instead of sync versions
   - Improves scalability for concurrent users

2. **Query Optimization**
   - Use `AsNoTracking()` for read-only queries
   - Use `Include()` and `ThenInclude()` to avoid N+1 problems
   - Add database indexes for frequently filtered columns

3. **Caching**
   - Cache program/course catalogs (rarely change)
   - Cache user role/permissions
   - Consider distributed cache (Redis) for multi-server deployments

4. **Pagination**
   - Always paginate large result sets
   - Support `pageIndex` and `pageSize` parameters
   - Use stable sorting

---

## 👥 Team Members (Group 5, PRN222)

This project was developed as an academic assignment by students in PRN222 course at TPF University. 

---

## 📝 License

This project is provided as-is for educational purposes. All rights reserved.

---

## 📞 Support & Contact

For issues, questions, or contributions, please:
- Create an issue on [GitHub](https://github.com/PRN222-SE1815/Assignment-02-SE1815-G5/issues)
- Check the [documentation](https://github.com/PRN222-SE1815/Assignment-02-SE1815-G5/wiki)
- Review the database schema in `PRN222_G5.sql`

---

<div align="center">

**Built with ❤️ using .NET 8, EF Core, and Razor Pages**

© 2024 TPF University | PRN222 Group 5

</div>