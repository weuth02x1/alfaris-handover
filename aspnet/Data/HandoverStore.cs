using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Alfaris.Handover.Models;

namespace Alfaris.Handover.Data;

public class HandoverStore
{
    readonly object _gate = new();
    readonly List<Employee> _accounts = StaffDirectory.Seed();
    readonly List<HandoverForm> _handovers = [];
    readonly List<AuditEntry> _audit = [];
    readonly List<EmailMessage> _outbox = [];
    int _counter;

    public IReadOnlyList<Employee> People { get { lock (_gate) return _accounts.ToList(); } }
    public IReadOnlyList<HandoverForm> Handovers { get { lock (_gate) return _handovers.ToList(); } }

    public Employee? Person(string? id)
    {
        if (id is null) return null;
        lock (_gate) return _accounts.FirstOrDefault(e => e.Id == id);
    }

    public Employee? FindByEmail(string email)
    {
        var target = email.Trim().ToLowerInvariant();
        lock (_gate) return _accounts.FirstOrDefault(e => e.Email.Equals(target, StringComparison.OrdinalIgnoreCase));
    }

    public List<Employee> ColleaguesFor(string employeeId)
    {
        var me = Person(employeeId);
        if (me is null) return [];
        lock (_gate)
        {
            var sameDept = _accounts.Where(p => p.Id != me.Id && p.DepartmentId == me.DepartmentId).ToList();
            return sameDept.Count > 0 ? sameDept : _accounts.Where(p => p.Id != me.Id && p.BranchId == me.BranchId).ToList();
        }
    }

    public List<Employee> HrUsers { get { lock (_gate) return _accounts.Where(e => e.IsHr).ToList(); } }

    public HandoverForm? Handover(string id)
    {
        lock (_gate) return _handovers.FirstOrDefault(h => h.Id == id);
    }

    public void Register(string email, string name, string employeeNo, string jobTitle, string departmentId)
    {
        var mail = email.Trim().ToLowerInvariant();
        var n = name.Trim();
        var no = employeeNo.Trim();
        var job = jobTitle.Trim();
        var dept = departmentId switch
        {
            "D-HR" => StaffDirectory.HrDept,
            "D-TA" => StaffDirectory.Talent,
            "D-ITD" => StaffDirectory.ItDev,
            _ => null
        };
        if (!IsEmail(mail) || n.Length is < 2 or > 80) throw new WorkflowException("invalid");
        if (!System.Text.RegularExpressions.Regex.IsMatch(no, @"^\d{3,10}$")) throw new WorkflowException("invalid");
        if (job.Length is < 2 or > 80 || dept is null) throw new WorkflowException("invalid");
        lock (_gate)
        {
            if (_accounts.Any(p => p.Email.Equals(mail, StringComparison.OrdinalIgnoreCase))) throw new WorkflowException("emailTaken");
            if (_accounts.Any(p => p.Id == no || p.StaffNumber == no)) throw new WorkflowException("idTaken");
            _accounts.Add(new Employee("local-" + Id(), n, n, job, job, dept["departmentId"], dept["departmentAr"], dept["departmentEn"], dept["sectionAr"], dept["sectionEn"], "B-RUH", mail, "employee", null, no));
        }
    }

    public Inbox InboxFor(Employee me)
    {
        lock (_gate)
        {
            var inbox = new Inbox { Mine = _handovers.Where(h => h.Employee.Id == me.Id).ToList() };
            foreach (var h in _handovers)
            {
                foreach (var task in h.Tasks)
                {
                    if (task.AssigneeId != me.Id) continue;
                    if (task.Status == "pending" && h.Status == "pending_acceptance") inbox.ToAccept.Add(new InboxItem(h, task));
                    else if (task.Status == "accepted") inbox.Accepted.Add(new InboxItem(h, task));
                }
            }
            inbox.ManagerQueue = _handovers.Where(h => h.Status == "pending_manager" && h.Employee.ManagerId == me.Id).ToList();
            inbox.HrQueue = me.IsHr ? _handovers.Where(h => h.Status == "pending_hr").ToList() : [];
            return inbox;
        }
    }

    public List<EmailMessage> MailFor(Employee me)
    {
        lock (_gate) return _outbox.Where(m => m.Kind != "otp" && m.ToEmployeeId == me.Id).Reverse().ToList();
    }

    public List<AuditEntry> AuditFor(string handoverId)
    {
        lock (_gate) return _audit.Where(a => a.HandoverId == handoverId).Reverse().ToList();
    }

    public string InitiateClearance(Employee actor, string requestRef, string? reason = null)
    {
        if (!actor.IsHr) throw new WorkflowException("notAllowed");
        var req = StaffDirectory.ApprovedRequests.FirstOrDefault(r => r.Ref == requestRef) ?? throw new WorkflowException("notFound");
        lock (_gate)
        {
            var existing = _handovers.FirstOrDefault(h => h.RequestRef == req.Ref);
            if (existing is not null) return existing.Id;
            var emp = _accounts.FirstOrDefault(e => e.Id == req.EmployeeId) ?? throw new WorkflowException("notFound");
            var manager = emp.ManagerId is null ? null : _accounts.FirstOrDefault(e => e.Id == emp.ManagerId);
            _counter++;
            var h = new HandoverForm
            {
                Id = Id(),
                Number = $"HO-{DateTime.UtcNow.Year}-{_counter.ToString().PadLeft(4, '0')}",
                RequestRef = req.Ref,
                Type = reason is not null && StaffDirectory.ExitReasons.Contains(reason) ? reason : req.Type,
                LastWorkingDay = req.StartDate,
                ReturnDate = req.EndDate,
                Employee = new EmployeeSnapshot(emp.Id, emp.NameAr, emp.NameEn, emp.JobTitleAr, emp.JobTitleEn, emp.DepartmentAr, emp.DepartmentEn, emp.SectionAr, emp.SectionEn, emp.ManagerId, manager?.NameAr ?? "", manager?.NameEn ?? ""),
                Status = "draft",
                InitiatedById = actor.Id,
                CreatedAt = Now()
            };
            _handovers.Add(h);
            Audit(h, actor.Id, "clearance_initiated", req.Ref);
            Notify(h, emp, $"مطلوب: تعبئة نموذج تسليم المهام {h.Number} | Action required: handover form",
                $"بدأت الموارد البشرية إخلاء الطرف للطلب {req.Ref}. افتح الرابط وعبّئ النموذج.\n\nHR started clearance for {req.Ref}.");
            Audit(h, "system", "link_sent", emp.Email);
            return h.Id;
        }
    }

    public string StartOwn(Employee actor, string type, string lastWorkingDay, string? returnDate)
    {
        if (!StaffDirectory.ExitReasons.Contains(type)) throw new WorkflowException("invalid");
        if (string.IsNullOrWhiteSpace(lastWorkingDay)) throw new WorkflowException("invalid");
        lock (_gate)
        {
            var manager = actor.ManagerId is null ? null : _accounts.FirstOrDefault(e => e.Id == actor.ManagerId);
            _counter++;
            var h = new HandoverForm
            {
                Id = Id(),
                Number = $"HO-{DateTime.UtcNow.Year}-{_counter.ToString().PadLeft(4, '0')}",
                RequestRef = $"SELF-{actor.DisplayId}-{_counter}",
                Type = type,
                LastWorkingDay = lastWorkingDay,
                ReturnDate = string.IsNullOrWhiteSpace(returnDate) ? null : returnDate,
                Employee = new EmployeeSnapshot(actor.Id, actor.NameAr, actor.NameEn, actor.JobTitleAr, actor.JobTitleEn, actor.DepartmentAr, actor.DepartmentEn, actor.SectionAr, actor.SectionEn, actor.ManagerId, manager?.NameAr ?? "", manager?.NameEn ?? ""),
                Status = "draft",
                InitiatedById = actor.Id,
                CreatedAt = Now()
            };
            _handovers.Add(h);
            Audit(h, actor.Id, "clearance_initiated", h.RequestRef);
            return h.Id;
        }
    }

    public void SaveForm(Employee actor, string id, string generalNotes, List<HandoverTask> tasks, bool submit)
    {
        lock (_gate)
        {
            var h = _handovers.FirstOrDefault(x => x.Id == id) ?? throw new WorkflowException("notFound");
            if (h.Employee.Id != actor.Id) throw new WorkflowException("notAllowed");
            if (h.Status is not ("draft" or "returned")) throw new WorkflowException("notAllowed");
            var colleagueIds = ColleaguesUnlocked(actor.Id).Select(c => c.Id).ToHashSet();
            foreach (var task in tasks)
            {
                if (submit && string.IsNullOrWhiteSpace(task.Title)) throw new WorkflowException("titleRequired");
                if (submit && string.IsNullOrWhiteSpace(task.AssigneeId)) throw new WorkflowException("assigneeRequired");
                if (!string.IsNullOrEmpty(task.AssigneeId) && !colleagueIds.Contains(task.AssigneeId)) throw new WorkflowException("notAllowed");
            }
            if (submit && tasks.Count == 0) throw new WorkflowException("noTasks");
            var previous = h.Tasks.Where(t => !string.IsNullOrEmpty(t.Id)).ToDictionary(t => t.Id);
            h.GeneralNotes = generalNotes;
            h.Tasks = tasks.Select(ti =>
            {
                var title = (ti.Title ?? "").Trim();
                var details = (ti.Details ?? "").Trim();
                var assignee = ti.AssigneeId ?? "";
                previous.TryGetValue(ti.Id ?? "", out var prev);
                if (prev is not null && prev.Title == title && prev.Details == details && prev.DueDate == ti.DueDate && prev.AssigneeId == assignee && prev.Status == "accepted")
                    return prev;
                return new HandoverTask
                {
                    Id = prev?.Id ?? (string.IsNullOrEmpty(ti.Id) ? Id() : ti.Id),
                    Title = title,
                    Details = details,
                    DueDate = string.IsNullOrEmpty(ti.DueDate) ? null : ti.DueDate,
                    AssigneeId = assignee,
                    Status = "draft",
                    Rejections = prev?.Rejections ?? []
                };
            }).ToList();
            if (!submit)
            {
                Audit(h, actor.Id, "form_saved");
                return;
            }
            h.SubmittedAt = Now();
            h.LastReturn = null;
            h.ManagerApproval = null;
            h.HrApproval = null;
            Audit(h, actor.Id, "form_submitted", h.Tasks.Count.ToString());
            foreach (var task in h.Tasks)
            {
                if (task.Status == "accepted") continue;
                task.Status = "pending";
                var recipient = ColleaguesUnlocked(actor.Id).First(c => c.Id == task.AssigneeId);
                Audit(h, actor.Id, "task_assigned", $"{task.Title} → {recipient.NameAr}");
                NotifyRecipient(h, task, recipient, actor);
            }
            AdvanceIfAllAccepted(h);
        }
    }

    public void AcceptTask(Employee actor, string id, string taskId, string? note)
    {
        lock (_gate)
        {
            var h = _handovers.FirstOrDefault(x => x.Id == id) ?? throw new WorkflowException("notFound");
            var task = h.Tasks.FirstOrDefault(t => t.Id == taskId);
            if (task is null || task.AssigneeId != actor.Id || task.Status != "pending" || h.Status != "pending_acceptance") throw new WorkflowException("notAllowed");
            task.Status = "accepted";
            task.AcceptedAt = Now();
            task.AcceptNote = string.IsNullOrWhiteSpace(note) ? null : note.Trim();
            Audit(h, actor.Id, "task_accepted", task.Title);
            AdvanceIfAllAccepted(h);
        }
    }

    public void RejectTask(Employee actor, string id, string taskId, string? comment)
    {
        if (string.IsNullOrWhiteSpace(comment)) throw new WorkflowException("commentRequired");
        lock (_gate)
        {
            var h = _handovers.FirstOrDefault(x => x.Id == id) ?? throw new WorkflowException("notFound");
            var task = h.Tasks.FirstOrDefault(t => t.Id == taskId);
            if (task is null || task.AssigneeId != actor.Id || task.Status != "pending" || h.Status != "pending_acceptance") throw new WorkflowException("notAllowed");
            var owner = _accounts.FirstOrDefault(e => e.Id == h.Employee.Id) ?? throw new WorkflowException("notFound");
            task.Status = "rejected";
            task.Rejections.Add(new TaskRejection { RecipientId = actor.Id, Comment = comment.Trim(), At = Now() });
            Audit(h, actor.Id, "task_rejected", $"{task.Title}: {comment.Trim()}");
            Notify(h, owner, $"رفض {actor.NameAr} استلام مهمة | {actor.NameEn} declined a task", $"{actor.NameAr} رفض المهمة \"{task.Title}\". السبب: {comment.Trim()}");
        }
    }

    public void ReassignTask(Employee actor, string id, string taskId, string newAssigneeId)
    {
        lock (_gate)
        {
            var h = _handovers.FirstOrDefault(x => x.Id == id) ?? throw new WorkflowException("notFound");
            if (h.Employee.Id != actor.Id || h.Status != "pending_acceptance") throw new WorkflowException("notAllowed");
            var task = h.Tasks.FirstOrDefault(t => t.Id == taskId);
            if (task is null || task.Status != "rejected") throw new WorkflowException("notAllowed");
            if (task.Rejections.Any(r => r.RecipientId == newAssigneeId)) throw new WorkflowException("sameAssignee");
            var recipient = ColleaguesUnlocked(actor.Id).FirstOrDefault(c => c.Id == newAssigneeId) ?? throw new WorkflowException("assigneeRequired");
            task.AssigneeId = newAssigneeId;
            task.Status = "pending";
            Audit(h, actor.Id, "task_reassigned", $"{task.Title} → {recipient.NameAr}");
            NotifyRecipient(h, task, recipient, actor);
        }
    }

    public void ManagerDecision(Employee actor, string id, bool approve, string? comment)
    {
        var note = comment?.Trim() ?? "";
        if (!approve && note.Length == 0) throw new WorkflowException("commentRequired");
        lock (_gate)
        {
            var h = _handovers.FirstOrDefault(x => x.Id == id) ?? throw new WorkflowException("notFound");
            if (h.Employee.Id == actor.Id || h.Status != "pending_manager" || h.Employee.ManagerId != actor.Id) throw new WorkflowException("notAllowed");
            var owner = _accounts.FirstOrDefault(e => e.Id == h.Employee.Id) ?? throw new WorkflowException("notFound");
            if (approve)
            {
                h.ManagerApproval = new Approval(actor.Id, Now(), note.Length == 0 ? null : note);
                Audit(h, actor.Id, "manager_approved", note);
                MoveToHr(h);
            }
            else ReturnToEmployee(h, owner, actor, "manager", note);
        }
    }

    public void HrDecision(Employee actor, string id, bool approve, string? comment)
    {
        var note = comment?.Trim() ?? "";
        if (!actor.IsHr) throw new WorkflowException("notAllowed");
        if (!approve && note.Length == 0) throw new WorkflowException("commentRequired");
        lock (_gate)
        {
            var h = _handovers.FirstOrDefault(x => x.Id == id) ?? throw new WorkflowException("notFound");
            if (h.Employee.Id == actor.Id || h.Status != "pending_hr") throw new WorkflowException("notAllowed");
            var owner = _accounts.FirstOrDefault(e => e.Id == h.Employee.Id) ?? throw new WorkflowException("notFound");
            if (!approve)
            {
                ReturnToEmployee(h, owner, actor, "hr", note);
                return;
            }
            h.HrApproval = new Approval(actor.Id, Now(), note.Length == 0 ? null : note);
            h.Status = "approved";
            h.FinalizedAt = Now();
            h.DocumentHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(Canonical(h))))).ToLowerInvariant();
            Audit(h, actor.Id, "hr_approved", note);
            Audit(h, "system", "document_generated", h.DocumentHash[..16]);
            Notify(h, owner, $"اكتمل تسليم المهام {h.Number} | Handover completed", "تم الاعتماد النهائي لنموذج تسليم المهام.");
            h.HrmsDocumentId = $"MENA-{h.Number}";
            Audit(h, "system", "document_uploaded", h.HrmsDocumentId);
        }
    }

    List<Employee> ColleaguesUnlocked(string employeeId)
    {
        var me = _accounts.FirstOrDefault(e => e.Id == employeeId);
        if (me is null) return [];
        var key = StaffDirectory.DepartmentKey(me);
        return _accounts.Where(p => p.Id != me.Id && StaffDirectory.DepartmentKey(p) == key).ToList();
    }

    void NotifyRecipient(HandoverForm h, HandoverTask task, Employee recipient, Employee from) =>
        Notify(h, recipient, $"{from.NameAr} أسند لك مهام، ادخل للموافقة", $"{from.NameAr} أسند لك المهمة: {task.Title}");

    void AdvanceIfAllAccepted(HandoverForm h)
    {
        if (!h.Tasks.All(t => t.Status == "accepted"))
        {
            h.Status = "pending_acceptance";
            return;
        }
        var manager = h.Employee.ManagerId is null ? null : _accounts.FirstOrDefault(e => e.Id == h.Employee.ManagerId);
        if (manager is not null)
        {
            h.Status = "pending_manager";
            Notify(h, manager, $"بانتظار اعتمادك: نموذج تسليم {h.Employee.NameAr}", $"قبل جميع المستلمين مهام {h.Employee.NameAr} في {h.Number}.");
        }
        else MoveToHr(h);
    }

    void MoveToHr(HandoverForm h)
    {
        h.Status = "pending_hr";
        foreach (var u in _accounts.Where(e => e.IsHr))
            Notify(h, u, $"اعتماد نهائي مطلوب: {h.Number}", $"{h.Number} for {h.Employee.NameAr} جاهز للاعتماد النهائي.");
    }

    void ReturnToEmployee(HandoverForm h, Employee owner, Employee actor, string stage, string comment)
    {
        h.Status = "returned";
        h.LastReturn = new ReturnInfo(stage, actor.Id, comment, Now());
        Audit(h, actor.Id, stage == "manager" ? "manager_rejected" : "hr_rejected", comment);
        Notify(h, owner, $"أُعيد نموذج التسليم {h.Number} للتعديل", $"أعاد {actor.NameAr} النموذج. السبب: {comment}");
    }

    void Notify(HandoverForm h, Employee to, string subject, string body)
    {
        _outbox.Add(new EmailMessage(Id(), to.Email, to.Id, subject, body, Now(), "workflow", $"/Handovers/{h.Id}"));
        if (_outbox.Count > 100) _outbox.RemoveRange(0, _outbox.Count - 100);
    }

    void Audit(HandoverForm h, string actorId, string action, string details = "") =>
        _audit.Add(new AuditEntry(Id(), h.Id, Now(), actorId, action, details));

    static bool IsEmail(string value) => System.Text.RegularExpressions.Regex.IsMatch(value, @"^[^\s@]+@[^\s@]+\.[^\s@]+$") && value.Length <= 160;
    static string Now() => DateTime.UtcNow.ToString("o");
    static string Id() => $"{DateTime.UtcNow.Ticks}-{Random.Shared.Next()}";

    static object Canonical(HandoverForm h) => new
    {
        h.Number,
        h.RequestRef,
        h.Type,
        h.LastWorkingDay,
        h.ReturnDate,
        employee = new { h.Employee.Id, h.Employee.NameAr, h.Employee.NameEn },
        h.GeneralNotes,
        tasks = h.Tasks.Select(t => new { t.Title, t.Details, t.DueDate, t.AssigneeId, t.AcceptedAt, t.AcceptNote }),
        managerApproval = h.ManagerApproval,
        hrApproval = h.HrApproval,
        h.FinalizedAt
    };
}
