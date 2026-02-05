using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace BusinessObject.Entities;

public partial class WalletTransaction
{
    [Key]
    public long WalletTransId { get; set; }

    public int WalletId { get; set; }

    [Column(TypeName = "decimal(18, 2)")]
    public decimal Amount { get; set; }

    [StringLength(50)]
    public string TransactionType { get; set; } = null!;

    public long? RelatedPaymentId { get; set; }

    public int? RelatedFeeId { get; set; }

    [StringLength(500)]
    public string? Description { get; set; }

    [Precision(0)]
    public DateTime CreatedAt { get; set; }

    [ForeignKey("RelatedFeeId")]
    [InverseProperty("WalletTransactions")]
    public virtual TuitionFee? RelatedFee { get; set; }

    [ForeignKey("RelatedPaymentId")]
    [InverseProperty("WalletTransactions")]
    public virtual PaymentTransaction? RelatedPayment { get; set; }

    [ForeignKey("WalletId")]
    [InverseProperty("WalletTransactions")]
    public virtual StudentWallet Wallet { get; set; } = null!;
}
