import "dart:convert";

import "package:http/http.dart" as http;

import "config.dart";

class MailSendResult {
  const MailSendResult({required this.challenge});
  final String challenge;
}

class MailApi {
  static bool get enabled => mailApiUrl.trim().isNotEmpty;

  static Uri get _uri {
    final base = mailApiUrl.trim().replaceAll(RegExp(r"/$"), "");
    return Uri.parse(base.endsWith("/otp") ? base : "$base/api/otp");
  }

  static Future<MailSendResult> request(String email) async {
    final response = await http
        .post(_uri, headers: {"Content-Type": "application/json"}, body: jsonEncode({"action": "send", "email": email}))
        .timeout(const Duration(seconds: 8));
    final body = _decode(response.body);
    if (response.statusCode >= 400 || body["ok"] != true) {
      throw Exception(body["error"] ?? "mailFailed");
    }
    final challenge = body["challenge"];
    if (challenge is! String || challenge.isEmpty) throw Exception("mailFailed");
    return MailSendResult(challenge: challenge);
  }

  static Future<void> verify(String email, String code, String challenge) async {
    final response = await http
        .post(
          _uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"action": "verify", "email": email, "code": code, "challenge": challenge}),
        )
        .timeout(const Duration(seconds: 8));
    final body = _decode(response.body);
    if (response.statusCode >= 400 || body["ok"] != true) {
      throw Exception(body["error"] ?? "badCode");
    }
  }

  static Map<String, dynamic> _decode(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
