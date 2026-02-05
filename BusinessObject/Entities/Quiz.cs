using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace BusinessObject.Entities;

public partial class Quiz
{
    [Key]
    public int QuizId { get; set; }

    public int ClassSectionId { get; set; }

    public int CreatedBy { get; set; }

    [StringLength(200)]
    public string QuizTitle { get; set; } = null!;

    public string? Description { get; set; }

    public int TotalQuestions { get; set; }

    public int? TimeLimitMin { get; set; }

    public bool ShuffleQuestions { get; set; }

    public bool ShuffleAnswers { get; set; }

    [Precision(0)]
    public DateTime? StartAt { get; set; }

    [Precision(0)]
    public DateTime? EndAt { get; set; }

    [StringLength(20)]
    public string Status { get; set; } = null!;

    [Precision(0)]
    public DateTime CreatedAt { get; set; }

    [ForeignKey("ClassSectionId")]
    [InverseProperty("Quizzes")]
    public virtual ClassSection ClassSection { get; set; } = null!;

    [ForeignKey("CreatedBy")]
    [InverseProperty("Quizzes")]
    public virtual User CreatedByNavigation { get; set; } = null!;

    [InverseProperty("Quiz")]
    public virtual ICollection<QuizAttempt> QuizAttempts { get; set; } = new List<QuizAttempt>();

    [InverseProperty("Quiz")]
    public virtual ICollection<QuizQuestion> QuizQuestions { get; set; } = new List<QuizQuestion>();
}
