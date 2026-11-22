using Alfaris.Handover.Data;
using Alfaris.Handover.Models;
using Alfaris.Handover.Services;
using Microsoft.AspNetCore.Mvc;

namespace Alfaris.Handover.Pages;

public class HrModel(HandoverStore store, LocaleService locale) : AppPageModel(store, locale)
{
    public string? Error { get; set; }
    public List<ApprovedRequest> Requests { get; set; } = [];
    public List<HandoverForm> All { get; set; } = [];

    public IActionResult OnGet()
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        if (!CurrentUser.IsHr) return RedirectToPage("/Index");
        Requests = StaffDirectory.ApprovedRequests.ToList();
        All = Store.Handovers.ToList();
        return Page();
    }

    public IActionResult OnPostStart(string requestRef)
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        try
        {
            var id = Store.InitiateClearance(CurrentUser, requestRef);
            return Redirect($"/Handovers/{id}");
        }
        catch (WorkflowException ex)
        {
            Error = T.Error(ex.Code);
            return OnGet();
        }
    }
}
