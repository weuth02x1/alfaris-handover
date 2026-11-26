import "dart:convert";

import "package:http/http.dart" as http;

import "auth_mail.dart";
import "models.dart";

/// One suggested handover task. The person still edits it and picks who
/// receives it. Nothing here is sent until they press send.
class TaskSuggestion {
  const TaskSuggestion({required this.title, required this.details});

  final String title;
  final String details;

  /// Keeps short, plain tasks and drops anything the model padded in.
  static List<TaskSuggestion> fromBody(Object? body) {
    if (body is! Map) return [];
    final raw = body["tasks"];
    if (raw is! List) return [];
    final out = <TaskSuggestion>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final title = "${item["title"] ?? ""}".trim();
      var details = "${item["details"] ?? ""}".trim();
      if (title.length < 3 || title.length > 120) continue;
      if (details.length > 400) details = details.substring(0, 400);
      out.add(TaskSuggestion(title: title, details: details));
      if (out.length == 5) break;
    }
    return out;
  }
}

/// Task suggestions go through the project's edge function. The model key
/// stays in the function secret GEMINI_API_KEY and never reaches the browser.
class Assist {
  static Future<List<TaskSuggestion>> suggestTasks({
    required String type,
    required String job,
    required String department,
    required String lastWorkingDay,
    required String notes,
    required List<String> existing,
  }) async {
    if (!AuthMail.enabled) throw WorkflowException("assistFailed");
    final response = await http
        .post(
          Uri.parse("$projectUrl/functions/v1/assist"),
          headers: {
            "apikey": supabaseAnonKey.trim(),
            "Authorization": "Bearer ${supabaseAnonKey.trim()}",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "type": type,
            "job": job,
            "department": department,
            "lastWorkingDay": lastWorkingDay,
            "notes": notes,
            "existing": existing,
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode >= 400) throw WorkflowException("assistFailed");
    try {
      return TaskSuggestion.fromBody(jsonDecode(response.body));
    } catch (_) {
      throw WorkflowException("assistFailed");
    }
  }
}
