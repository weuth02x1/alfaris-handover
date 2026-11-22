import "dart:convert";

import "package:http/http.dart" as http;

const supabaseUrl = String.fromEnvironment("SUPABASE_URL");
const supabaseAnonKey = String.fromEnvironment("SUPABASE_ANON_KEY");

class AuthMail {
  static bool get enabled {
    final url = supabaseUrl.trim();
    final key = supabaseAnonKey.trim();
    return url.startsWith("https://") && key.isNotEmpty;
  }

  static Uri _uri(String path) {
    final base = supabaseUrl.trim().replaceAll(RegExp(r"/$"), "");
    return Uri.parse("$base$path");
  }

  static Map<String, String> get _headers => {
        "apikey": supabaseAnonKey.trim(),
        "Authorization": "Bearer ${supabaseAnonKey.trim()}",
        "Content-Type": "application/json",
      };

  static Future<void> send(String email) async {
    final response = await http
        .post(
          _uri("/auth/v1/otp"),
          headers: _headers,
          body: jsonEncode({"email": email, "create_user": true}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode >= 400) throw Exception("mailFailed");
  }

  static Future<void> verify(String email, String code) async {
    final response = await http
        .post(
          _uri("/auth/v1/verify"),
          headers: _headers,
          body: jsonEncode({"type": "email", "email": email, "token": code.trim()}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode >= 400) throw Exception("badCode");
  }
}
