using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace BusinessObject.Entities;

public partial class QuizAnswer
{
    [Key]
    public int AnswerId { get; set; }

    public int QuestionId { get; set; }

    [StringLength(1000)]
    public string AnswerText { get; set; } = null!;

    public bool IsCorrect { get; set; }

    [ForeignKey("QuestionId")]
    [InverseProperty("QuizAnswers")]
    public virtual QuizQuestion Question { get; set; } = null!;

    [InverseProperty("SelectedAnswer")]
    public virtual ICollection<QuizAttemptAnswer> QuizAttemptAnswers { get; set; } = new List<QuizAttemptAnswer>();
}
