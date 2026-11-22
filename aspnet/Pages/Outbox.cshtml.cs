using Alfaris.Handover.Data;
using Alfaris.Handover.Models;
using Alfaris.Handover.Services;
using Microsoft.AspNetCore.Mvc;

namespace Alfaris.Handover.Pages;

public class OutboxModel(HandoverStore store, LocaleService locale) : AppPageModel(store, locale)
{
    public List<EmailMessage> Messages { get; set; } = [];

    public IActionResult OnGet()
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        Messages = Store.MailFor(CurrentUser);
        return Page();
    }
}
