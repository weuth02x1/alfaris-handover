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
          body: jsonEncode({"email": email.trim().toLowerCase(), "create_user": true}),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode >= 400) throw WorkflowException(_mailError(response));
  }

  static Future<void> verify(String email, String code) async {
    if (!enabled) throw WorkflowException("badCode");
    final response = await http
        .post(
          _uri("/auth/v1/verify"),
          headers: _headers,
          body: jsonEncode({
            "type": "email",
            "email": email.trim().toLowerCase(),
            "token": code.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 429) throw WorkflowException("slow");
    if (response.statusCode >= 400) throw WorkflowException("badCode");
  }

  static String _mailError(http.Response response) {
    if (response.statusCode == 429) return "slow";
    try {
      final body = jsonDecode(response.body);
      final code = "${body["error_code"] ?? ""}".toLowerCase();
      final msg = "${body["msg"] ?? body["message"] ?? ""}".toLowerCase();
      if (code == "unexpected_failure" || msg.contains("confirmation email") || msg.contains("error sending")) {
        return "mailerDown";
      }
    } catch (_) {}
    return "mailFailed";
  }
}
