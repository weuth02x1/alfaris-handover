import "dart:convert";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;

const definedUrl = String.fromEnvironment("SUPABASE_URL");
const definedKey = String.fromEnvironment("SUPABASE_ANON_KEY");
const projectUrl = "https://sfshhcfjowiptefesqgp.supabase.co";

class AuthMail {
  static String _url = definedUrl.trim();
  static String _key = definedKey.trim();

  static bool get enabled {
    final url = _resolvedUrl;
    return url.startsWith("https://") && _key.isNotEmpty;
  }

  static String get _resolvedUrl {
    if (_url.startsWith("https://")) return _url.replaceAll(RegExp(r"/$"), "");
    return projectUrl;
  }

  static Uri _uri(String path) => Uri.parse("${_resolvedUrl}$path");

  static Map<String, String> get _headers => {
        "apikey": _key,
        "Authorization": "Bearer $_key",
        "Content-Type": "application/json",
      };

  static Future<void> bootstrap() async {
    if (_key.isNotEmpty) return;
    if (!kIsWeb) return;
    final candidates = <Uri>[
      Uri.base.resolve("supabase.json"),
      Uri.parse("https://employee-handover-ac0d.apps.grok.bot/api/public-supabase"),
    ];
    for (final uri in candidates) {
      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 8));
        if (response.statusCode >= 400) continue;
        final body = jsonDecode(response.body);
        if (body is! Map) continue;
        final url = "${body["url"] ?? ""}".trim();
        final key = "${body["anonKey"] ?? body["anon_key"] ?? ""}".trim();
        if (key.isEmpty) continue;
        if (url.startsWith("https://")) _url = url;
        _key = key;
        return;
      } catch (_) {}
    }
  }

  static Future<void> send(String email) async {
    await bootstrap();
    if (!enabled) throw Exception("mailFailed");
    final response = await http
        .post(
          _uri("/auth/v1/otp"),
          headers: _headers,
          body: jsonEncode({"email": email, "create_user": true}),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode >= 400) throw Exception("mailFailed");
  }

  static Future<void> verify(String email, String code) async {
    await bootstrap();
    if (!enabled) throw Exception("badCode");
    final response = await http
        .post(
          _uri("/auth/v1/verify"),
          headers: _headers,
          body: jsonEncode({"type": "email", "email": email, "token": code.trim()}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 400) throw Exception("badCode");
  }
}
