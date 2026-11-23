import "dart:convert";

import "package:http/http.dart" as http;

import "models.dart";

const projectUrl = "https://sfshhcfjowiptefesqgp.supabase.co";
const supabaseAnonKey = String.fromEnvironment("SUPABASE_ANON_KEY");

/// Sign-in mail goes only to this project's Auth endpoint. Custom SMTP in
/// that project (Resend) delivers the message. The anon key is a publishable
/// client key, baked in at build time — never fetched from another host.
class AuthMail {
  static bool get enabled => supabaseAnonKey.trim().isNotEmpty;

  static Uri _uri(String path) => Uri.parse("$projectUrl$path");

  static Map<String, String> get _headers => {
        "apikey": supabaseAnonKey.trim(),
        "Authorization": "Bearer ${supabaseAnonKey.trim()}",
        "Content-Type": "application/json",
      };

  static Future<void> send(String email) async {
    if (!enabled) throw WorkflowException("mailFailed");
    final response = await http
        .post(
          _uri("/auth/v1/otp"),
          headers: _headers,
          body: jsonEncode({"email": email.trim().toLowerCase(), "create_user": true}),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode == 429) throw WorkflowException("slow");
    if (response.statusCode >= 400) throw WorkflowException("mailFailed");
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
}
