using Alfaris.Handover.Data;
using Alfaris.Handover.Services;
using Microsoft.AspNetCore.CookiePolicy;
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);
var hostedByIis = !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ASPNETCORE_IIS_PHYSICAL_PATH"));
if (!hostedByIis)
{
    builder.WebHost.UseUrls(Environment.GetEnvironmentVariable("ASPNETCORE_URLS") ?? "http://127.0.0.1:4521");
}

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});
builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(365);
    options.IncludeSubDomains = false;
    options.Preload = false;
});
builder.Services.AddHttpsRedirection(options =>
{
    options.RedirectStatusCode = StatusCodes.Status308PermanentRedirect;
    options.HttpsPort = 443;
});
builder.Services.Configure<CookiePolicyOptions>(options =>
{
    options.HttpOnly = HttpOnlyPolicy.Always;
    options.Secure = CookieSecurePolicy.SameAsRequest;
    options.MinimumSameSitePolicy = SameSiteMode.Lax;
});
builder.Services.AddRazorPages();
builder.Services.AddSingleton<HandoverStore>();
builder.Services.AddSingleton<OtpBox>();
builder.Services.AddSingleton<SiteSettings>();
builder.Services.AddHttpClient<AuthMail>(client =>
{
    client.Timeout = TimeSpan.FromSeconds(20);
});
builder.Services.AddScoped<LocaleService>();

var app = builder.Build();
app.UseForwardedHeaders();
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // Only redirect HTTP→443 when IIS (or a TLS proxy) is terminating HTTPS.
    // A blind redirect sends browsers to handover.alfarisgrp.com:443, which
    // currently serves *.websitewelcome.com and Chrome flags as Not Secure.
    if (hostedByIis)
    {
        app.UseHsts();
        app.UseHttpsRedirection();
    }
}
app.UseCookiePolicy();
app.Use(async (ctx, next) =>
{
    ctx.Response.OnStarting(() =>
    {
        var headers = ctx.Response.Headers;
        headers["X-Content-Type-Options"] = "nosniff";
        headers["X-Frame-Options"] = "SAMEORIGIN";
        headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
        headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
        headers["Content-Security-Policy"] =
            "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; form-action 'self'; frame-ancestors 'self'; base-uri 'self'";
        if (ctx.Request.IsHttps)
            headers["Strict-Transport-Security"] = "max-age=31536000";
        return Task.CompletedTask;
    });
    await next();
});
app.UseStaticFiles();
app.UseRouting();
app.Use(async (ctx, next) =>
{
    var locale = ctx.Request.Cookies["alfaris_lang"];
    if (locale is not ("ar" or "en")) locale = "ar";
    ctx.RequestServices.GetRequiredService<LocaleService>().Locale = locale;
    ctx.Items["locale"] = locale;
    await next();
});
app.MapGet("/healthz", () => Results.Text("ok"));
app.MapGet("/.well-known/acme-challenge/{token}", (string token, SiteSettings settings) =>
    settings.AcmeChallenge(token));
app.MapRazorPages();
app.Run();
