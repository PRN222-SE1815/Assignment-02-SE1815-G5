using BusinessLogic.Services.Implements;
using BusinessLogic.Services.Interfaces;
using BusinessLogic.Settings;
using DataAccess;
using DataAccess.Repositories.Implements;
using DataAccess.Repositories.Interfaces;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Presentation.Hubs;
using Presentation.Realtime;

var builder = WebApplication.CreateBuilder(args);

// ==================== Database ====================
builder.Services.AddDbContext<SchoolManagementDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Settings
builder.Services.Configure<MoMoSettings>(builder.Configuration.GetSection(MoMoSettings.SectionName));
builder.Services.Configure<ReliabilitySettings>(builder.Configuration.GetSection(ReliabilitySettings.SectionName));
builder.Services.AddHttpClient();

// DI for services
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IEnrollmentService, EnrollmentService>();
builder.Services.AddScoped<IPaymentService, PaymentService>();
builder.Services.AddScoped<IQuizService, QuizService>();
builder.Services.AddScoped<IChatService, ChatService>();
builder.Services.AddScoped<IStudentScheduleService, StudentScheduleService>();
builder.Services.AddScoped<ITeacherScheduleService, TeacherScheduleService>();
builder.Services.AddScoped<IAdminScheduleService, AdminScheduleService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<INotificationRealtimePublisher, SignalRNotificationRealtimePublisher>();
builder.Services.AddScoped<IGradebookService, GradebookService>();
builder.Services.AddScoped<IGradebookSyncService, GradebookSyncService>();

// DI for repositories
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IEnrollmentRepository, EnrollmentRepository>();
builder.Services.AddScoped<IClassSectionRepository, ClassSectionRepository>();
builder.Services.AddScoped<IQuizRepository, QuizRepository>();
builder.Services.AddScoped<IStudentRepository, StudentRepository>();
builder.Services.AddScoped<IWalletRepository, WalletRepository>();
builder.Services.AddScoped<ITuitionFeeRepository, TuitionFeeRepository>();
builder.Services.AddScoped<ICourseRepository, CourseRepository>();
builder.Services.AddScoped<ISemesterRepository, SemesterRepository>();
builder.Services.AddScoped<IPaymentTransactionRepository, PaymentTransactionRepository>();
builder.Services.AddScoped<IChatRoomRepository, ChatRoomRepository>();
builder.Services.AddScoped<IChatRoomMemberRepository, ChatRoomMemberRepository>();
builder.Services.AddScoped<IChatMessageRepository, ChatMessageRepository>();
builder.Services.AddScoped<IChatMessageAttachmentRepository, ChatMessageAttachmentRepository>();
builder.Services.AddScoped<IChatModerationLogRepository, ChatModerationLogRepository>();
builder.Services.AddScoped<IScheduleRepository, ScheduleRepository>();
builder.Services.AddScoped<INotificationRepository, NotificationRepository>();
builder.Services.AddScoped<IGradeBookRepository, GradeBookRepository>();


// ==================== Razor Pages ====================
builder.Services.AddRazorPages().AddRazorPagesOptions(options =>
{
    options.Conventions.AddPageRoute("/Account/Login", "");
});

// ==================== Cookie Authentication ====================
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.AccessDeniedPath = "/Account/AccessDenied";
        options.Cookie.Name = "SchoolManagement.Auth";
        options.SlidingExpiration = true;
    });

builder.Services.AddAuthorization();

// ==================== SignalR ====================
builder.Services.AddSignalR();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapRazorPages();
app.MapHub<ChatHub>("/chatHub");
app.MapHub<NotificationHub>("/notificationHub");

app.Run();
