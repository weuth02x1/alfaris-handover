using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Mail;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Alfaris.Handover.Models;

namespace Alfaris.Handover.Services;

public class OtpBox
{
    readonly ConcurrentDictionary<string, (string Hash, DateTimeOffset Expires)> _codes = new();

    public void Remember(string email, string hash, DateTimeOffset expires) =>
        _codes[email] = (hash, expires);

    public bool Match(string email, string hash)
    {
        if (!_codes.TryGetValue(email, out var row)) return false;
        if (row.Expires < DateTimeOffset.UtcNow)
        {
            _codes.TryRemove(email, out _);
            throw new WorkflowException("expired");
        }
        var ok = CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(row.Hash),
            Encoding.UTF8.GetBytes(hash));
        if (ok) _codes.TryRemove(email, out _);
        return ok;
    }
}

public class AuthMail(HttpClient http, IConfiguration config, OtpBox otps, ILogger<AuthMail> log, SiteSettings settings)
{
    public const string ProjectUrl = "https://sfshhcfjowiptefesqgp.supabase.co";
    public const string SiteUrl = SiteSettings.PublicUrl;

    public bool Enabled => HasSupabase || HasResend || HasSmtp;
    public string Channel => HasSupabase ? "supabase" : HasResend ? "resend" : HasSmtp ? "smtp" : "none";

    bool HasSupabase => !string.IsNullOrWhiteSpace(AnonKey);
    bool HasResend => !string.IsNullOrWhiteSpace(ResendKey);
    bool HasSmtp => !string.IsNullOrWhiteSpace(SmtpHost) && !string.IsNullOrWhiteSpace(SmtpUser) && !string.IsNullOrWhiteSpace(SmtpPass);

    string AnonKey => Env("SUPABASE_ANON_KEY", "Supabase:AnonKey");
    string Url
    {
        get
        {
            var url = Env("SUPABASE_URL", "Supabase:Url");
            if (string.IsNullOrWhiteSpace(url)) url = settings.Current.SupabaseUrl;
            if (string.IsNullOrWhiteSpace(url)) url = ProjectUrl;
            url = url.Trim().TrimEnd('/');
            return url.StartsWith("https://", StringComparison.OrdinalIgnoreCase) ? url : ProjectUrl;
        }
    }
    string ResendKey => Env("RESEND_API_KEY");
    string SmtpHost => Env("SMTP_HOST");
    string SmtpUser => Env("SMTP_USER");
    string SmtpPass => Env("SMTP_PASS");
    string From =>
        First(Env("RESEND_FROM"), Env("SMTP_FROM"), settings.Current.MailFrom, config["Mail:From"], "Alfaris Group <noreply@alfarisgrp.com>");
    string Redirect => First(settings.Current.SiteUrl, config["Mail:SiteUrl"], SiteUrl);

    public async Task SendAsync(string email, CancellationToken ct = default)
    {
        email = email.Trim().ToLowerInvariant();
        if (HasSupabase && await TrySupabaseOtpAsync(email, ct)) return;
        if (HasResend || HasSmtp)
        {
            await SendLocalCodeAsync(email, ct);
            return;
        }
        throw new WorkflowException("mailFailed");
    }

    public async Task VerifyAsync(string email, string code, CancellationToken ct = default)
    {
        email = email.Trim().ToLowerInvariant();
        var given = (code ?? "").Replace(" ", "", StringComparison.Ordinal);
        if (!System.Text.RegularExpressions.Regex.IsMatch(given, @"^\d{6}$")) throw new WorkflowException("badCode");

        if (HasSupabase && await TrySupabaseVerifyAsync(email, given, ct)) return;
        if (otps.Match(email, HashCode(email, given))) return;
        throw new WorkflowException("badCode");
    }

    async Task<bool> TrySupabaseOtpAsync(string email, CancellationToken ct)
    {
        var target = $"{Url}/auth/v1/otp?redirect_to={Uri.EscapeDataString(Redirect)}";
        using var req = new HttpRequestMessage(HttpMethod.Post, target);
        ApplySupabase(req);
        req.Content = Json(new { email, create_user = true });
        using var res = await http.SendAsync(req, ct);
        log.LogInformation("Supabase OTP status {Status}", (int)res.StatusCode);
        return (int)res.StatusCode < 400;
    }

    async Task<bool> TrySupabaseVerifyAsync(string email, string token, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Post, $"{Url}/auth/v1/verify");
        ApplySupabase(req);
        req.Content = Json(new { type = "email", email, token });
        using var res = await http.SendAsync(req, ct);
        log.LogInformation("Supabase verify status {Status}", (int)res.StatusCode);
        return (int)res.StatusCode < 400;
    }

    async Task SendLocalCodeAsync(string email, CancellationToken ct)
    {
        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        otps.Remember(email, HashCode(email, code), DateTimeOffset.UtcNow.AddMinutes(10));
        var subject = "رمز الدخول لنظام تسليم المهام";
        var text =
            $"رمز الدخول: {code}\nصالح لمدة 10 دقائق. لا تشاركه مع أحد.\n\nYour sign-in code: {code}\nIt expires in 10 minutes.";
        if (HasResend && await TryResendAsync(email, subject, text, ct)) return;
        if (HasSmtp && TrySmtp(email, subject, text)) return;
        otps.Match(email, HashCode(email, code));
        throw new WorkflowException("mailFailed");
    }

    async Task<bool> TryResendAsync(string to, string subject, string text, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Post, "https://api.resend.com/emails");
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", ResendKey);
        req.Content = Json(new { from = From, to = new[] { to }, subject, text });
        using var res = await http.SendAsync(req, ct);
        log.LogInformation("Resend status {Status}", (int)res.StatusCode);
        return res.IsSuccessStatusCode;
    }

    bool TrySmtp(string to, string subject, string text)
    {
        var port = int.TryParse(Env("SMTP_PORT"), out var p) ? p : (SmtpHost.Contains("resend.com", StringComparison.OrdinalIgnoreCase) ? 465 : 587);
        try
        {
            using var client = new SmtpClient(SmtpHost, port)
            {
                EnableSsl = true,
                Credentials = new NetworkCredential(SmtpUser, SmtpPass),
                Timeout = 12_000
            };
            client.Send(new MailMessage(From, to, subject, text));
            log.LogInformation("SMTP accepted for handover sign-in");
            return true;
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "SMTP send failed");
            return false;
        }
    }

    void ApplySupabase(HttpRequestMessage req)
    {
        req.Headers.TryAddWithoutValidation("apikey", AnonKey);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", AnonKey);
    }

    static StringContent Json(object body) =>
        new(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");

    string HashCode(string email, string code)
    {
        var salt = Env("SESSION_SECRET", "Mail:Salt");
        if (string.IsNullOrWhiteSpace(salt)) salt = "alfaris-handover";
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes($"{email}.{code}.{salt}")));
    }

    string Env(string name, string? configKey = null) =>
        (Environment.GetEnvironmentVariable(name) ?? (configKey is null ? null : config[configKey]) ?? "").Trim();

    static string First(params string?[] values) =>
        values.FirstOrDefault(v => !string.IsNullOrWhiteSpace(v))?.Trim() ?? "";
}
