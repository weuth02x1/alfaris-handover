using Alfaris.Handover.Data;
using Alfaris.Handover.Models;
using Alfaris.Handover.Services;
using Microsoft.AspNetCore.Mvc;

namespace Alfaris.Handover.Pages.Handovers;

public class DetailsModel(HandoverStore store, LocaleService locale) : AppPageModel(store, locale)
{
    public HandoverForm? Item { get; set; }
    public string? Error { get; set; }
    public List<Employee> Colleagues { get; set; } = [];
    public bool CanEdit { get; set; }
    public bool CanManage { get; set; }
    public bool CanHr { get; set; }

    [BindProperty] public string GeneralNotes { get; set; } = "";
    [BindProperty] public List<string> TaskIds { get; set; } = [];
    [BindProperty] public List<string> Titles { get; set; } = [];
    [BindProperty] public List<string> DetailsText { get; set; } = [];
    [BindProperty] public List<string> Assignees { get; set; } = [];
    [BindProperty] public List<string> DueDates { get; set; } = [];
    public List<AuditEntry> Audit { get; set; } = [];
    public string[] Steps { get; } = ["draft", "pending_acceptance", "pending_manager", "pending_hr", "approved"];
    [BindProperty] public string? Note { get; set; }
    [BindProperty] public string? Comment { get; set; }
    [BindProperty] public string NewAssigneeId { get; set; } = "";

    public IActionResult OnGet(string id)
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        Load(id);
        if (Item is null) return NotFound();
        if (!CanAccess(Item)) return RedirectToPage("/Index");
        if (CanEdit && Item.Tasks.Count == 0) Item.Tasks.Add(new HandoverTask());
        return Page();
    }

    public IActionResult OnPostSave(string id, bool submit)
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        try
        {
            Store.SaveForm(CurrentUser, id, GeneralNotes, PostedTasks(), submit);
            return RedirectToPage(new { id });
        }
        catch (WorkflowException ex)
        {
            Error = T.Error(ex.Code);
            Load(id);
            return Page();
        }
    }

    public IActionResult OnPostAddTask(string id)
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        try
        {
            var tasks = PostedTasks();
            tasks.Add(new HandoverTask());
            Store.SaveForm(CurrentUser, id, GeneralNotes, tasks, false);
            return RedirectToPage(new { id });
        }
        catch (WorkflowException ex)
        {
            Error = T.Error(ex.Code);
            Load(id);
            return Page();
        }
    }

    public IActionResult OnPostRemoveTask(string id, int index)
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        try
        {
            var tasks = PostedTasks();
            if (index >= 0 && index < tasks.Count) tasks.RemoveAt(index);
            Store.SaveForm(CurrentUser, id, GeneralNotes, tasks, false);
            return RedirectToPage(new { id });
        }
        catch (WorkflowException ex)
        {
            Error = T.Error(ex.Code);
            Load(id);
            return Page();
        }
    }

    public IActionResult OnPostAccept(string id, string taskId)
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        try { Store.AcceptTask(CurrentUser, id, taskId, Note); }
        catch (WorkflowException ex) { Error = T.Error(ex.Code); Load(id); return Page(); }
        return RedirectToPage(new { id });
    }

    public IActionResult OnPostReject(string id, string taskId)
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        try { Store.RejectTask(CurrentUser, id, taskId, Comment); }
        catch (WorkflowException ex) { Error = T.Error(ex.Code); Load(id); return Page(); }
        return RedirectToPage(new { id });
    }

    public IActionResult OnPostReassign(string id, string taskId)
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        try { Store.ReassignTask(CurrentUser, id, taskId, NewAssigneeId); }
        catch (WorkflowException ex) { Error = T.Error(ex.Code); Load(id); return Page(); }
        return RedirectToPage(new { id });
    }

    public IActionResult OnPostManager(string id, bool approve)
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        try { Store.ManagerDecision(CurrentUser, id, approve, Comment); }
        catch (WorkflowException ex) { Error = T.Error(ex.Code); Load(id); return Page(); }
        return RedirectToPage(new { id });
    }

    public IActionResult OnPostHr(string id, bool approve)
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        try { Store.HrDecision(CurrentUser, id, approve, Comment); }
        catch (WorkflowException ex) { Error = T.Error(ex.Code); Load(id); return Page(); }
        return RedirectToPage(new { id });
    }

    List<HandoverTask> PostedTasks()
    {
        var tasks = new List<HandoverTask>();
        for (var i = 0; i < Titles.Count; i++)
        {
            tasks.Add(new HandoverTask
            {
                Id = i < TaskIds.Count ? TaskIds[i] : "",
                Title = Titles[i],
                Details = i < DetailsText.Count ? DetailsText[i] : "",
                AssigneeId = i < Assignees.Count ? Assignees[i] : "",
                DueDate = i < DueDates.Count && !string.IsNullOrWhiteSpace(DueDates[i]) ? DueDates[i] : null
            });
        }
        return tasks;
    }

    void Load(string id)
    {
        Item = Store.Handover(id);
        if (Item is null || CurrentUser is null) return;
        GeneralNotes = Item.GeneralNotes;
        Colleagues = Store.ColleaguesFor(Item.Employee.Id);
        CanEdit = CurrentUser.Id == Item.Employee.Id && Item.Status is "draft" or "returned";
        CanManage = CurrentUser.Id == Item.Employee.ManagerId && Item.Status == "pending_manager";
        CanHr = CurrentUser.IsHr && Item.Status == "pending_hr" && CurrentUser.Id != Item.Employee.Id;
        Audit = Store.AuditFor(Item.Id);
        if (CanEdit && Item.Tasks.Count == 0) Item.Tasks.Add(new HandoverTask());
    }
}
