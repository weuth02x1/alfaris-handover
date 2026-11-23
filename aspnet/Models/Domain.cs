namespace Alfaris.Handover.Models;

public record Employee(
    string Id,
    string NameAr,
    string NameEn,
    string JobTitleAr,
    string JobTitleEn,
    string DepartmentId,
    string DepartmentAr,
    string DepartmentEn,
    string SectionAr,
    string SectionEn,
    string BranchId,
    string Email,
    string Role,
    string? ManagerId = null,
    string? StaffNumber = null)
{
    public string DisplayId => StaffNumber ?? Id;
    public bool IsHr => Role == "hr";
}

public record ApprovedRequest(string Ref, string EmployeeId, string Type, string StartDate, string? EndDate);

public class TaskRejection
{
    public required string RecipientId { get; set; }
    public required string Comment { get; set; }
    public required string At { get; set; }
}

public class HandoverTask
{
    public string Id { get; set; } = "";
    public string Title { get; set; } = "";
    public string Details { get; set; } = "";
    public string? DueDate { get; set; }
    public string AssigneeId { get; set; } = "";
    public string Status { get; set; } = "draft";
    public string? AcceptedAt { get; set; }
    public string? AcceptNote { get; set; }
    public List<TaskRejection> Rejections { get; set; } = [];
}

public record EmployeeSnapshot(
    string Id,
    string NameAr,
    string NameEn,
    string JobTitleAr,
    string JobTitleEn,
    string DepartmentAr,
    string DepartmentEn,
    string SectionAr,
    string SectionEn,
    string? ManagerId,
    string ManagerNameAr,
    string ManagerNameEn);

public record ReturnInfo(string Stage, string ById, string Comment, string At);
public record Approval(string ById, string At, string? Comment);

public class HandoverForm
{
    public required string Id { get; set; }
    public required string Number { get; set; }
    public required string RequestRef { get; set; }
    public required string Type { get; set; }
    public required string LastWorkingDay { get; set; }
    public string? ReturnDate { get; set; }
    public required EmployeeSnapshot Employee { get; set; }
    public required string Status { get; set; }
    public string GeneralNotes { get; set; } = "";
    public List<HandoverTask> Tasks { get; set; } = [];
    public ReturnInfo? LastReturn { get; set; }
    public Approval? ManagerApproval { get; set; }
    public Approval? HrApproval { get; set; }
    public required string InitiatedById { get; set; }
    public required string CreatedAt { get; set; }
    public string? SubmittedAt { get; set; }
    public string? FinalizedAt { get; set; }
    public string? DocumentHash { get; set; }
    public string? HrmsDocumentId { get; set; }
}

public record AuditEntry(string Id, string HandoverId, string At, string ActorId, string Action, string Details);
public record EmailMessage(string Id, string To, string ToEmployeeId, string Subject, string Body, string At, string Kind, string? Link = null);
public record InboxItem(HandoverForm Handover, HandoverTask? Task);
public class Inbox
{
    public List<HandoverForm> Mine { get; set; } = [];
    public List<InboxItem> ToAccept { get; set; } = [];
    public List<InboxItem> Accepted { get; set; } = [];
    public List<HandoverForm> ManagerQueue { get; set; } = [];
    public List<HandoverForm> HrQueue { get; set; } = [];
    public List<HandoverForm> Raised { get; set; } = [];
    public bool IsEmpty => Mine.Count + ToAccept.Count + Accepted.Count + ManagerQueue.Count + HrQueue.Count + Raised.Count == 0;
}

public class WorkflowException(string code) : Exception(code)
{
    public string Code { get; } = code;
}
