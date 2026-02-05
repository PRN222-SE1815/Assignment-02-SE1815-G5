using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace BusinessObject.Entities;

[Index("StudentId", "SemesterId", Name = "UQ_TuitionFees_Student_Semester", IsUnique = true)]
public partial class TuitionFee
{
    [Key]
    public int FeeId { get; set; }

    public int StudentId { get; set; }

    public int SemesterId { get; set; }

    public int TotalCredits { get; set; }

    [Column(TypeName = "decimal(18, 2)")]
    public decimal AmountPerCredit { get; set; }

    [Column(TypeName = "decimal(18, 2)")]
    public decimal TotalAmount { get; set; }

    [Column(TypeName = "decimal(18, 2)")]
    public decimal PaidAmount { get; set; }

    [StringLength(20)]
    public string Status { get; set; } = null!;

    public DateOnly? DueDate { get; set; }

    [Precision(0)]
    public DateTime CreatedAt { get; set; }

    [Precision(0)]
    public DateTime? UpdatedAt { get; set; }

    [ForeignKey("SemesterId")]
    [InverseProperty("TuitionFees")]
    public virtual Semester Semester { get; set; } = null!;

    [ForeignKey("StudentId")]
    [InverseProperty("TuitionFees")]
    public virtual Student Student { get; set; } = null!;

    [InverseProperty("RelatedFee")]
    public virtual ICollection<WalletTransaction> WalletTransactions { get; set; } = new List<WalletTransaction>();
}
