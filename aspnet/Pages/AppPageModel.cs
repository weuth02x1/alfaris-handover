using Alfaris.Handover.Data;
using Alfaris.Handover.Models;
using Alfaris.Handover.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Alfaris.Handover.Pages;

public abstract class AppPageModel(HandoverStore store, LocaleService locale) : PageModel
{
    public HandoverStore Store { get; } = store;
    public LocaleService T { get; } = locale;

    public Employee? CurrentUser => Store.Person(Request.Cookies["alfaris_user"]);

    protected IActionResult RequireUser()
    {
        return CurrentUser is null ? RedirectToPage("/Login") : Page();
    }

    protected void SignIn(Employee employee)
    {
        Response.Cookies.Append("alfaris_user", employee.Id, SessionCookie());
    }

    protected void SignOutCookie()
    {
        Response.Cookies.Delete("alfaris_user");
    }

    protected void ToggleLang()
    {
        var next = T.IsAr ? "en" : "ar";
        Response.Cookies.Append("alfaris_lang", next, new CookieOptions
        {
            MaxAge = TimeSpan.FromDays(365),
            IsEssential = true,
            SameSite = SameSiteMode.Lax,
            Secure = Request.IsHttps
        });
    }

    CookieOptions SessionCookie() => new()
    {
        HttpOnly = true,
        SameSite = SameSiteMode.Lax,
        IsEssential = true,
        Secure = Request.IsHttps,
        MaxAge = TimeSpan.FromDays(7)
    };

    public string NameOf(Employee? e) => e is null ? T.Dash : T.Pick(e.NameAr, e.NameEn);
    public string NameSnap(EmployeeSnapshot e) => T.Pick(e.NameAr, e.NameEn);
}
