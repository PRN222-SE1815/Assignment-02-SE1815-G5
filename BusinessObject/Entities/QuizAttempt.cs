using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace BusinessObject.Entities;

[Index("QuizId", "EnrollmentId", Name = "UX_QuizAttempts_OnePerStudent", IsUnique = true)]
public partial class QuizAttempt
{
    [Key]
    public int AttemptId { get; set; }

    public int QuizId { get; set; }

    public int EnrollmentId { get; set; }

    public int ClassSectionId { get; set; }

    [Precision(0)]
    public DateTime StartedAt { get; set; }

    [Precision(0)]
    public DateTime? SubmittedAt { get; set; }

    [Column(TypeName = "decimal(5, 2)")]
    public decimal? Score { get; set; }

    [StringLength(20)]
    public string Status { get; set; } = null!;

    [ForeignKey("ClassSectionId")]
    [InverseProperty("QuizAttempts")]
    public virtual ClassSection ClassSection { get; set; } = null!;

    [ForeignKey("EnrollmentId")]
    [InverseProperty("QuizAttempts")]
    public virtual Enrollment Enrollment { get; set; } = null!;

    [ForeignKey("QuizId")]
    [InverseProperty("QuizAttempts")]
    public virtual Quiz Quiz { get; set; } = null!;

    [InverseProperty("Attempt")]
    public virtual ICollection<QuizAttemptAnswer> QuizAttemptAnswers { get; set; } = new List<QuizAttemptAnswer>();
}
