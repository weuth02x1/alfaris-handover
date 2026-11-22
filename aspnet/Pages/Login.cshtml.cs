using Alfaris.Handover.Data;
using Alfaris.Handover.Models;
using Alfaris.Handover.Services;
using Microsoft.AspNetCore.Mvc;

namespace Alfaris.Handover.Pages;

public class LoginModel(HandoverStore store, LocaleService locale, AuthMail mail, IWebHostEnvironment env) : AppPageModel(store, locale)
{
    [BindProperty] public string Email { get; set; } = "";
    [BindProperty] public string Code { get; set; } = "";
    [BindProperty] public string Name { get; set; } = "";
    [BindProperty] public string EmployeeNo { get; set; } = "";
    [BindProperty] public string JobTitle { get; set; } = "";
    [BindProperty] public string DepartmentId { get; set; } = "D-HR";
    [BindProperty] public bool Signup { get; set; }
    [BindProperty] public bool CodeStep { get; set; }
    public string? Error { get; set; }
    public bool MailReady => mail.Enabled;
    public string MailChannel => mail.Channel;
    public bool AllowSampleLogin => env.IsDevelopment() && !mail.Enabled;
    public IReadOnlyList<Employee> SampleStaff => Store.People;

    public IActionResult OnGet()
    {
        if (CurrentUser is not null) return RedirectToPage("/Index");
        return Page();
    }

    public IActionResult OnPostLang()
    {
        ToggleLang();
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostSendAsync()
    {
        try
        {
            if (Store.FindByEmail(Email) is null)
            {
                Signup = true;
                Error = T.Error("notFoundEmail");
                return Page();
            }
            await mail.SendAsync(Email);
            CodeStep = true;
        }
        catch (WorkflowException ex) { Error = T.Error(ex.Code); }
        catch { Error = T.Error("mailFailed"); }
        return Page();
    }

    public async Task<IActionResult> OnPostRegisterAsync()
    {
        Signup = true;
        try
        {
            Store.Register(Email, Name, EmployeeNo, JobTitle, DepartmentId);
            await mail.SendAsync(Email);
            CodeStep = true;
        }
        catch (WorkflowException ex) { Error = T.Error(ex.Code); }
        catch { Error = T.Error("mailFailed"); }
        return Page();
    }

    public async Task<IActionResult> OnPostVerifyAsync()
    {
        CodeStep = true;
        try
        {
            var emp = Store.FindByEmail(Email);
            if (emp is null) throw new WorkflowException("notFoundEmail");
            await mail.VerifyAsync(emp.Email, Code);
            SignIn(emp);
            return RedirectToPage("/Index");
        }
        catch (WorkflowException ex) { Error = T.Error(ex.Code); }
        catch { Error = T.Error("badCode"); }
        return Page();
    }

    public IActionResult OnPostSignupToggle()
    {
        Signup = !Signup;
        CodeStep = false;
        return Page();
    }

    public IActionResult OnPostSample(string employeeId)
    {
        if (!AllowSampleLogin) return RedirectToPage();
        var emp = Store.Person(employeeId);
        if (emp is null)
        {
            Error = T.Error("notFound");
            return Page();
        }
        SignIn(emp);
        return RedirectToPage("/Index");
    }
}
