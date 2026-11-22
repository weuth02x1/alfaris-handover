using Alfaris.Handover.Data;
using Alfaris.Handover.Models;
using Alfaris.Handover.Services;
using Microsoft.AspNetCore.Mvc;

namespace Alfaris.Handover.Pages.Handovers;

public class ReportModel(HandoverStore store, LocaleService locale) : AppPageModel(store, locale)
{
    public HandoverForm? Item { get; set; }

    public IActionResult OnGet(string id)
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        Item = Store.Handover(id);
        if (Item is null) return NotFound();
        if (Item.Status != "approved") return Redirect($"/Handovers/{id}");
        return Page();
    }
}
