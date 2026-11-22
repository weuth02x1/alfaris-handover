using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Alfaris.Handover.Models;

namespace Alfaris.Handover.Services;

public class AuthMail(HttpClient http, IConfiguration config)
{
    public const string ProjectUrl = "https://sfshhcfjowiptefesqgp.supabase.co";

    public bool Enabled
    {
        get
        {
            var key = Key;
            return !string.IsNullOrWhiteSpace(key);
        }
    }

    string Key =>
        (Environment.GetEnvironmentVariable("SUPABASE_ANON_KEY") ?? config["Supabase:AnonKey"] ?? "").Trim();

    string Url
    {
        get
        {
            var url = (Environment.GetEnvironmentVariable("SUPABASE_URL") ?? config["Supabase:Url"] ?? ProjectUrl).Trim().TrimEnd('/');
            return url.StartsWith("https://", StringComparison.OrdinalIgnoreCase) ? url : ProjectUrl;
        }
    }

    public async Task SendAsync(string email, CancellationToken ct = default)
    {
        if (!Enabled) throw new WorkflowException("mailFailed");
        using var req = new HttpRequestMessage(HttpMethod.Post, $"{Url}/auth/v1/otp");
        req.Headers.Add("apikey", Key);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", Key);
        req.Content = new StringContent(JsonSerializer.Serialize(new { email, create_user = true }), Encoding.UTF8, "application/json");
        using var res = await http.SendAsync(req, ct);
        if ((int)res.StatusCode >= 400) throw new WorkflowException("mailFailed");
    }

    public async Task VerifyAsync(string email, string code, CancellationToken ct = default)
    {
        if (!Enabled) throw new WorkflowException("badCode");
        using var req = new HttpRequestMessage(HttpMethod.Post, $"{Url}/auth/v1/verify");
        req.Headers.Add("apikey", Key);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", Key);
        req.Content = new StringContent(JsonSerializer.Serialize(new { type = "email", email, token = code.Trim() }), Encoding.UTF8, "application/json");
        using var res = await http.SendAsync(req, ct);
        if ((int)res.StatusCode >= 400) throw new WorkflowException("badCode");
    }
}
