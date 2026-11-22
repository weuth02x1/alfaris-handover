using Alfaris.Handover.Data;
using Alfaris.Handover.Services;
using Microsoft.AspNetCore.Mvc;

namespace Alfaris.Handover.Pages;

public class SettingsModel(HandoverStore store, LocaleService locale, SiteSettings settings, AuthMail mail) : AppPageModel(store, locale)
{
    [BindProperty] public string SiteUrl { get; set; } = "";
    [BindProperty] public string MailFrom { get; set; } = "";
    [BindProperty] public string SupabaseUrl { get; set; } = "";
    public DomainReport? Domain { get; set; }
    public bool MailReady { get; set; }
    public string MailChannel { get; set; } = "none";
    public bool Saved { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        if (!CurrentUser.IsHr) return RedirectToPage("/Index");
        var pinned = settings.Current;
        settings.Save(new SiteOptions
        {
            SiteUrl = SiteSettings.PublicUrl,
            MailFrom = string.IsNullOrWhiteSpace(MailFrom) ? pinned.MailFrom : MailFrom,
            SupabaseUrl = string.IsNullOrWhiteSpace(SupabaseUrl) ? pinned.SupabaseUrl : SupabaseUrl
        });
        var current = settings.Current;
        SiteUrl = current.SiteUrl;
        MailFrom = current.MailFrom;
        SupabaseUrl = current.SupabaseUrl;
        MailReady = mail.Enabled;
        MailChannel = mail.Channel;
        Domain = await settings.ProbeAsync();
        return Page();
    }

    public async Task<IActionResult> OnPostSaveAsync()
    {
        if (CurrentUser is null) return RedirectToPage("/Login");
        if (!CurrentUser.IsHr) return RedirectToPage("/Index");
        settings.Save(new SiteOptions
        {
            SiteUrl = SiteUrl,
            MailFrom = MailFrom,
            SupabaseUrl = SupabaseUrl
        });
        Saved = true;
        return await OnGetAsync();
    }
}
