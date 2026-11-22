using Alfaris.Handover.Data;
using Alfaris.Handover.Services;
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
builder.Services.AddRazorPages();
builder.Services.AddSingleton<HandoverStore>();
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
}
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
app.MapRazorPages();
app.Run();
