using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace BusinessObject.Entities;

public partial class GradeBookApproval
{
    [Key]
    public int ApprovalId { get; set; }

    public int GradeBookId { get; set; }

    public int RequestBy { get; set; }

    [Precision(0)]
    public DateTime? RequestAt { get; set; }

    [StringLength(500)]
    public string? RequestMessage { get; set; }

    public int? ResponseBy { get; set; }

    [Precision(0)]
    public DateTime? ResponseAt { get; set; }

    [StringLength(500)]
    public string? ResponseMessage { get; set; }

    [StringLength(20)]
    public string? Outcome { get; set; }
}
