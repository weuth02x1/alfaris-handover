using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Alfaris.Handover.Services;

public class SiteOptions
{
    public string SiteUrl { get; set; } = "https://handover.alfarisgrp.com";
    public string MailFrom { get; set; } = "Alfaris Group <noreply@alfarisgrp.com>";
    public string SupabaseUrl { get; set; } = AuthMail.ProjectUrl;
}

public class DomainReport
{
    public string Host { get; set; } = "";
    public string Ip { get; set; } = "";
    public string CertificateCn { get; set; } = "";
    public string CertificateSans { get; set; } = "";
    public bool CertificateMatches { get; set; }
    public bool PointsAtLegacyCpanel { get; set; }
    public bool Secure { get; set; }
    public string SummaryAr { get; set; } = "";
    public string SummaryEn { get; set; } = "";
}

public class SiteSettings
{
    public const string PublicUrl = "https://handover.alfarisgrp.com";
    static readonly JsonSerializerOptions JsonOpts = new() { WriteIndented = true };
    readonly object _gate = new();
    readonly string _path;
    readonly string _acmeDir;
    SiteOptions _current;

    public SiteSettings(IWebHostEnvironment env)
    {
        var dir = Path.Combine(env.ContentRootPath, "App_Data");
        Directory.CreateDirectory(dir);
        var webRoot = env.WebRootPath ?? Path.Combine(env.ContentRootPath, "wwwroot");
        _acmeDir = Path.Combine(webRoot, ".well-known", "acme-challenge");
        Directory.CreateDirectory(_acmeDir);
        _path = Path.Combine(dir, "settings.json");
        _current = Load() ?? new SiteOptions();
        Save(_current);
    }

    public SiteOptions Current
    {
        get { lock (_gate) return Clone(_current); }
    }

    public void Save(SiteOptions input)
    {
        var next = Normalize(input);
        lock (_gate)
        {
            _current = next;
            File.WriteAllText(_path, JsonSerializer.Serialize(next, JsonOpts));
        }
    }

    public static SiteOptions Normalize(SiteOptions input)
    {
        var site = PublicUrl;
        var raw = (input.SiteUrl ?? "").Trim().TrimEnd('/');
        if (Uri.TryCreate(raw, UriKind.Absolute, out var uri) &&
            uri.Scheme == "https" &&
            uri.Host.Equals("handover.alfarisgrp.com", StringComparison.OrdinalIgnoreCase))
            site = PublicUrl;

        var from = (input.MailFrom ?? "").Trim();
        if (string.IsNullOrWhiteSpace(from) || !from.Contains("@alfarisgrp.com", StringComparison.OrdinalIgnoreCase))
            from = "Alfaris Group <noreply@alfarisgrp.com>";

        var supabase = (input.SupabaseUrl ?? "").Trim().TrimEnd('/');
        if (!Uri.TryCreate(supabase, UriKind.Absolute, out var su) || su.Scheme != "https" || !su.Host.EndsWith("supabase.co", StringComparison.OrdinalIgnoreCase))
            supabase = AuthMail.ProjectUrl;

        return new SiteOptions { SiteUrl = site, MailFrom = from, SupabaseUrl = supabase };
    }

    public IResult AcmeChallenge(string token)
    {
        if (!Regex.IsMatch(token, "^[A-Za-z0-9_-]{1,256}$")) return Results.NotFound();
        var path = Path.GetFullPath(Path.Combine(_acmeDir, token));
        var root = Path.GetFullPath(_acmeDir);
        if (!path.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.Ordinal) || !File.Exists(path))
            return Results.NotFound();
        return Results.File(path, "text/plain");
    }

    public async Task<DomainReport> ProbeAsync(CancellationToken ct = default)
    {
        var host = new Uri(Current.SiteUrl).Host;
        var report = new DomainReport { Host = host };
        try
        {
            var addresses = await Dns.GetHostAddressesAsync(host, ct);
            report.Ip = addresses.FirstOrDefault()?.ToString() ?? "";
            report.PointsAtLegacyCpanel = report.Ip == "192.185.30.74";
        }
        catch
        {
            report.Ip = "";
        }

        try
        {
            using var tcp = new TcpClient();
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeout.CancelAfter(TimeSpan.FromSeconds(8));
            await tcp.ConnectAsync(host, 443, timeout.Token);
            using var ssl = new SslStream(tcp.GetStream(), false, static (_, _, _, _) => true);
            await ssl.AuthenticateAsClientAsync(host);
            if (ssl.RemoteCertificate is not null)
            {
                using var cert = new X509Certificate2(ssl.RemoteCertificate);
                var names = SubjectNames(cert);
                report.CertificateCn = names.FirstOrDefault() ?? cert.Subject;
                report.CertificateSans = string.Join(", ", names);
                report.CertificateMatches = names.Any(name => DnsNameMatches(name, host));
            }
        }
        catch (Exception ex)
        {
            report.CertificateCn = ex.GetType().Name;
        }

        report.Secure = report.CertificateMatches;
        if (report.CertificateMatches)
        {
            report.SummaryAr = "الشهادة تطابق الدومين. HTTPS آمن.";
            report.SummaryEn = "The certificate matches the domain. HTTPS is secure.";
        }
        else if (DnsNameMatches("*.websitewelcome.com", report.CertificateCn) ||
                 report.CertificateSans.Contains("websitewelcome.com", StringComparison.OrdinalIgnoreCase))
        {
            report.SummaryAr =
                $"كروم يقول غير آمن لأن الشهادة {report.CertificateCn} لا تغطي {host}. شهادة Let's Encrypt على نفس السيرفر تغطي الموقع الرئيسي بدون اسم handover.";
            report.SummaryEn =
                $"Chrome says Not Secure because the certificate {report.CertificateCn} does not cover {host}. Let's Encrypt on the same server covers the main site, not handover.";
        }
        else
        {
            report.SummaryAr = $"الشهادة الحالية {report.CertificateCn} لا تطابق {host}.";
            report.SummaryEn = $"Current certificate {report.CertificateCn} does not match {host}.";
        }
        return report;
    }

    SiteOptions? Load()
    {
        try
        {
            if (!File.Exists(_path)) return null;
            return JsonSerializer.Deserialize<SiteOptions>(File.ReadAllText(_path));
        }
        catch
        {
            return null;
        }
    }

    public static IReadOnlyList<string> SubjectNames(X509Certificate2 cert)
    {
        var names = new List<string>();
        var cn = cert.GetNameInfo(X509NameType.DnsName, false);
        if (!string.IsNullOrWhiteSpace(cn)) names.Add(cn.Trim());
        foreach (var ext in cert.Extensions)
        {
            if (ext.Oid?.Value != "2.5.29.17") continue;
            foreach (var part in ext.Format(false).Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
            {
                var name = part.Replace("DNS Name:", "", StringComparison.OrdinalIgnoreCase)
                    .Replace("DNS:", "", StringComparison.OrdinalIgnoreCase)
                    .Trim();
                if (string.IsNullOrWhiteSpace(name)) continue;
                if (!names.Contains(name, StringComparer.OrdinalIgnoreCase)) names.Add(name);
            }
        }
        return names;
    }

    public static bool DnsNameMatches(string pattern, string host)
    {
        if (string.IsNullOrWhiteSpace(pattern) || string.IsNullOrWhiteSpace(host)) return false;
        if (pattern.Equals(host, StringComparison.OrdinalIgnoreCase)) return true;
        return pattern.StartsWith("*.", StringComparison.Ordinal) &&
               host.EndsWith(pattern[1..], StringComparison.OrdinalIgnoreCase) &&
               host.Count(c => c == '.') == pattern.Count(c => c == '.');
    }

    static SiteOptions Clone(SiteOptions o) => new()
    {
        SiteUrl = o.SiteUrl,
        MailFrom = o.MailFrom,
        SupabaseUrl = o.SupabaseUrl
    };
}
