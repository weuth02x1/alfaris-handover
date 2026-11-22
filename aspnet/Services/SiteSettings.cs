using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json;

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
    public bool CertificateMatches { get; set; }
    public bool PointsAtLegacyCpanel { get; set; }
    public string SummaryAr { get; set; } = "";
    public string SummaryEn { get; set; } = "";
}

public class SiteSettings
{
    static readonly JsonSerializerOptions JsonOpts = new() { WriteIndented = true };
    readonly object _gate = new();
    readonly string _path;
    SiteOptions _current;

    public SiteSettings(IWebHostEnvironment env)
    {
        var dir = Path.Combine(env.ContentRootPath, "App_Data");
        Directory.CreateDirectory(dir);
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
        var site = (input.SiteUrl ?? "").Trim().TrimEnd('/');
        if (!Uri.TryCreate(site, UriKind.Absolute, out var uri) || uri.Scheme != "https")
            site = "https://handover.alfarisgrp.com";
        else if (!uri.Host.EndsWith("alfarisgrp.com", StringComparison.OrdinalIgnoreCase))
            site = "https://handover.alfarisgrp.com";
        else
            site = $"https://{uri.Host}";

        var from = (input.MailFrom ?? "").Trim();
        if (string.IsNullOrWhiteSpace(from) || !from.Contains("@alfarisgrp.com", StringComparison.OrdinalIgnoreCase))
            from = "Alfaris Group <noreply@alfarisgrp.com>";

        var supabase = (input.SupabaseUrl ?? "").Trim().TrimEnd('/');
        if (!Uri.TryCreate(supabase, UriKind.Absolute, out var su) || su.Scheme != "https" || !su.Host.EndsWith("supabase.co", StringComparison.OrdinalIgnoreCase))
            supabase = AuthMail.ProjectUrl;

        return new SiteOptions { SiteUrl = site, MailFrom = from, SupabaseUrl = supabase };
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
                report.CertificateCn = cert.GetNameInfo(X509NameType.DnsName, false);
                if (string.IsNullOrWhiteSpace(report.CertificateCn)) report.CertificateCn = cert.Subject;
                report.CertificateMatches = HostMatches(cert, host);
            }
        }
        catch (Exception ex)
        {
            report.CertificateCn = ex.GetType().Name;
        }

        if (report.CertificateMatches && !report.PointsAtLegacyCpanel)
        {
            report.SummaryAr = "الشهادة تطابق الدومين. HTTPS آمن.";
            report.SummaryEn = "The certificate matches the domain. HTTPS is secure.";
        }
        else if (report.PointsAtLegacyCpanel)
        {
            report.SummaryAr = $"الدومين ما زال على cPanel ({report.Ip}). الشهادة {report.CertificateCn} لذلك كروم يقول غير آمن. وجّه DNS لسيرفر IIS وأصدر Let's Encrypt للاسم {host}.";
            report.SummaryEn = $"The domain still points at cPanel ({report.Ip}). Certificate {report.CertificateCn} so Chrome says Not Secure. Point DNS at IIS and issue Let's Encrypt for {host}.";
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

    static bool HostMatches(X509Certificate2 cert, string host)
    {
        var cn = cert.GetNameInfo(X509NameType.DnsName, false);
        if (DnsMatch(cn, host)) return true;
        foreach (var ext in cert.Extensions)
        {
            if (ext.Oid?.Value != "2.5.29.17") continue;
            foreach (var part in ext.Format(false).Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
            {
                var name = part.Replace("DNS Name:", "", StringComparison.OrdinalIgnoreCase)
                    .Replace("DNS:", "", StringComparison.OrdinalIgnoreCase)
                    .Trim();
                if (DnsMatch(name, host)) return true;
            }
        }
        return false;
    }

    static bool DnsMatch(string pattern, string host)
    {
        if (string.IsNullOrWhiteSpace(pattern)) return false;
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
