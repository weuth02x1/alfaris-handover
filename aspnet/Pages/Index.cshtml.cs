using Alfaris.Handover.Data;
using Alfaris.Handover.Models;
using Alfaris.Handover.Services;
using Microsoft.AspNetCore.Mvc;

namespace Alfaris.Handover.Pages;

public class IndexModel(HandoverStore store, LocaleService locale) : AppPageModel(store, locale)
{
    public Inbox? Inbox { get; set; }
    public List<EmailMessage> Notices { get; set; } = [];

    public IActionResult OnGet()
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        Inbox = Store.InboxFor(CurrentUser);
        Notices = Store.MailFor(CurrentUser);
        return Page();
    }

    public IActionResult OnPostStart(string type, string lastWorkingDay, string? returnDate)
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        try
        {
            var id = Store.StartOwn(CurrentUser, type, lastWorkingDay, returnDate);
            return Redirect($"/Handovers/{id}");
        }
        catch (WorkflowException)
        {
            return RedirectToPage();
        }
    }

    public IActionResult OnPostLang()
    {
        ToggleLang();
        return RedirectToPage();
    }

    public IActionResult OnPostLogout()
    {
        SignOutCookie();
        return RedirectToPage("/Login");
    }
}
