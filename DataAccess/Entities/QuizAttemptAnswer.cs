using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace BusinessObject.Entities;

public partial class QuizAttemptAnswer
{
    [Key]
    public int AttemptAnswerId { get; set; }

    public int AttemptId { get; set; }

    public int QuestionId { get; set; }

    public int? SelectedAnswerId { get; set; }

    public bool? IsCorrect { get; set; }

    [ForeignKey("AttemptId")]
    [InverseProperty("QuizAttemptAnswers")]
    public virtual QuizAttempt Attempt { get; set; } = null!;

    [ForeignKey("QuestionId")]
    [InverseProperty("QuizAttemptAnswers")]
    public virtual QuizQuestion Question { get; set; } = null!;

    [ForeignKey("SelectedAnswerId")]
    [InverseProperty("QuizAttemptAnswers")]
    public virtual QuizAnswer? SelectedAnswer { get; set; }
}
