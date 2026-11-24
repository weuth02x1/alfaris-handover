import "dart:convert";

import "package:http/http.dart" as http;

import "models.dart";

const projectUrl = "https://sfshhcfjowiptefesqgp.supabase.co";
const supabaseAnonKey = String.fromEnvironment("SUPABASE_ANON_KEY");
const siteUrl = String.fromEnvironment(
  "SITE_URL",
  defaultValue: "https://weuth02x1.github.io/alfaris-handover/",
);

/// Sign-in mail goes only to this project's Auth endpoint. Custom SMTP in
/// that project (Resend) delivers the message. The anon key is a publishable
/// client key, baked in at build time — never fetched from another host.
class AuthMail {
  static bool get enabled => supabaseAnonKey.trim().isNotEmpty;

  static Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse("$projectUrl$path");
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  static Uri otpUri() => _uri("/auth/v1/otp", {"redirect_to": siteUrl});

  static Map<String, String> get _headers => {
    "apikey": supabaseAnonKey.trim(),
    "Authorization": "Bearer ${supabaseAnonKey.trim()}",
    "Content-Type": "application/json",
  };

  static Future<void> send(String email) async {
    if (!enabled) throw WorkflowException("mailFailed");
    final response = await http
        .post(
          otpUri(),
          headers: _headers,
          body: jsonEncode({
            "email": email.trim().toLowerCase(),
            "create_user": true,
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode >= 400)
      throw WorkflowException(_mailError(response));
  }

  /// Arabic and Persian digits count as the code the person sees.
  static String digits(String raw) {
    const eastern = "٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹";
    final out = StringBuffer();
    for (final rune in raw.runes) {
      final ch = String.fromCharCode(rune);
      final easternAt = eastern.indexOf(ch);
      if (easternAt >= 0) {
        out.write(easternAt % 10);
        continue;
      }
      if (rune >= 48 && rune <= 57) out.writeCharCode(rune);
    }
    return out.toString();
  }

  /// Gmail delivers plus-addresses and dotted locals to one inbox.
  static String inboxKey(String email) {
    final mail = email.trim().toLowerCase();
    final at = mail.lastIndexOf("@");
    if (at <= 0) return mail;
    var local = mail.substring(0, at);
    var domain = mail.substring(at + 1);
    final plus = local.indexOf("+");
    if (plus >= 0) local = local.substring(0, plus);
    if (domain == "googlemail.com") domain = "gmail.com";
    if (domain == "gmail.com") local = local.replaceAll(".", "");
    return "$local@$domain";
  }

  static Future<void> verify(String email, String code) async {
    if (!enabled) throw WorkflowException("badCode");
    final token = digits(code);
    if (token.length < 6) throw WorkflowException("badCode");
    final response = await http
        .post(
          _uri("/auth/v1/verify"),
          headers: _headers,
          body: jsonEncode({
            "type": "email",
            "email": email.trim().toLowerCase(),
            "token": token,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 400) return;
    if (response.statusCode == 429) throw WorkflowException("slow");
    throw WorkflowException(_verifyError(response));
  }

  static String _verifyError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      final code = "${body["error_code"] ?? body["code"] ?? ""}".toLowerCase();
      final msg = "${body["msg"] ?? body["message"] ?? ""}".toLowerCase();
      if (code.contains("expired") ||
          msg.contains("expired") ||
          msg.contains("invalid")) {
        return "expired";
      }
    } catch (_) {}
    return "badCode";
  }

  static String _mailError(http.Response response) {
    if (response.statusCode == 429) return "slow";
    try {
      final body = jsonDecode(response.body);
      final code = "${body["error_code"] ?? ""}".toLowerCase();
      final msg = "${body["msg"] ?? body["message"] ?? ""}".toLowerCase();
      if (code == "unexpected_failure" ||
          msg.contains("confirmation email") ||
          msg.contains("error sending")) {
        return "mailerDown";
      }
    } catch (_) {}
    return "mailFailed";
  }
}

/// Workflow notices use the same project mailer as the sign-in code.
/// The browser never holds the SMTP password. A missing function keeps the
/// in-app notice and does not pretend the email left.
class WorkflowMail {
  static Future<void> send({
    required String to,
    required String subject,
    required String body,
  }) async {
    final address = to.trim().toLowerCase();
    if (!AuthMail.enabled || address.endsWith(".example") || address.isEmpty)
      return;
    try {
      await http
          .post(
            AuthMail._uri("/functions/v1/send-notice"),
            headers: AuthMail._headers,
            body: jsonEncode({"to": address, "subject": subject, "body": body}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {}
  }
}
