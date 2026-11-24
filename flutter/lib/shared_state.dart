import "dart:convert";

import "package:http/http.dart" as http;

const sharedBinId = "vmLt3VdAtq_yKg";
const sharedBinKey = "RfgjQFGp558QVPLZ4XZhFzwGPecVhLaQ";

Uri get sharedBinUri => Uri.parse("https://jsonstorage.com/$sharedBinId");

Map<String, dynamic> emptySharedState() => {
  "counter": 0,
  "accounts": <Object?>[],
  "handovers": <Object?>[],
  "outbox": <Object?>[],
  "audit": <Object?>[],
};

Map<String, dynamic> asSharedState(Object? raw) {
  if (raw is! Map) return emptySharedState();
  return {
    "counter": (raw["counter"] as num?)?.toInt() ?? 0,
    "accounts": raw["accounts"] is List ? raw["accounts"] as List : <Object?>[],
    "handovers": raw["handovers"] is List
        ? raw["handovers"] as List
        : <Object?>[],
    "outbox": raw["outbox"] is List ? raw["outbox"] as List : <Object?>[],
    "audit": raw["audit"] is List ? raw["audit"] as List : <Object?>[],
  };
}

int _rank(String status) => switch (status) {
  "draft" => 1,
  "returned" => 2,
  "pending_acceptance" => 3,
  "pending_manager" => 4,
  "pending_hr" => 5,
  "approved" => 6,
  _ => 0,
};

int _progress(Map item) {
  var score = _rank("${item["status"]}") * 100;
  for (final task in item["tasks"] as List? ?? const []) {
    if (task is Map && task["status"] == "accepted") score += 1;
  }
  return score;
}

int _auditsFor(Map<String, dynamic> state, String id) {
  var count = 0;
  for (final item in state["audit"] as List) {
    if (item is Map && "${item["handoverId"]}" == id) count += 1;
  }
  return count;
}

Map<String, dynamic> _preferHandover(Map left, Map right) {
  final lp = _progress(left);
  final rp = _progress(right);
  if (lp != rp) return Map<String, dynamic>.from(lp > rp ? left : right);
  final lt =
      "${left["finalizedAt"] ?? left["submittedAt"] ?? left["createdAt"] ?? ""}";
  final rt =
      "${right["finalizedAt"] ?? right["submittedAt"] ?? right["createdAt"] ?? ""}";
  return Map<String, dynamic>.from(lt.compareTo(rt) >= 0 ? left : right);
}

Map<String, Map<String, dynamic>> _byId(List items) {
  final out = <String, Map<String, dynamic>>{};
  for (final item in items) {
    if (item is! Map) continue;
    final id = "${item["id"]}";
    if (id.isEmpty) continue;
    out[id] = Map<String, dynamic>.from(item);
  }
  return out;
}

/// Union of two browsers. A request opened on one device stays visible on the other.
Map<String, dynamic> mergeSharedState(
  Map<String, dynamic> left,
  Map<String, dynamic> right,
) {
  final a = asSharedState(left);
  final b = asSharedState(right);
  final accounts = <String, Map<String, dynamic>>{};
  void takeAccounts(List items) {
    for (final item in items) {
      if (item is! Map) continue;
      final id = "${item["id"]}";
      if (id.isEmpty) continue;
      final current = accounts[id];
      if (current == null ||
          (current["managerId"] == null && item["managerId"] != null) ||
          ("${current["email"]}".trim().isEmpty &&
              "${item["email"]}".trim().isNotEmpty)) {
        accounts[id] = Map<String, dynamic>.from(item);
      }
    }
  }

  takeAccounts(a["accounts"] as List);
  takeAccounts(b["accounts"] as List);

  final handovers = <String, Map<String, dynamic>>{};
  final handoverAudits = <String, int>{};
  void takeHandovers(Map<String, dynamic> state) {
    for (final item in state["handovers"] as List) {
      if (item is! Map) continue;
      final id = "${item["id"]}";
      if (id.isEmpty) continue;
      final audits = _auditsFor(state, id);
      final current = handovers[id];
      final known = handoverAudits[id] ?? -1;
      if (current == null || audits > known) {
        handovers[id] = Map<String, dynamic>.from(item);
        handoverAudits[id] = audits;
      } else if (audits == known) {
        handovers[id] = _preferHandover(current, item);
      }
    }
  }

  takeHandovers(a);
  takeHandovers(b);

  final outbox = {..._byId(a["outbox"] as List), ..._byId(b["outbox"] as List)};
  final audit = {..._byId(a["audit"] as List), ..._byId(b["audit"] as List)};
  final counters = [a["counter"] as int, b["counter"] as int];
  return {
    "counter": counters.reduce((x, y) => x > y ? x : y),
    "accounts": accounts.values.toList(),
    "handovers": handovers.values.toList(),
    "outbox": outbox.values.toList(),
    "audit": audit.values.toList(),
  };
}

String stateFingerprint(Map<String, dynamic> raw) {
  final state = asSharedState(raw);
  final accounts = [
    for (final item in state["accounts"] as List)
      if (item is Map)
        "${item["id"]}:${"${item["email"]}".trim().toLowerCase()}",
  ]..sort();
  final handovers = [
    for (final item in state["handovers"] as List)
      if (item is Map)
        "${item["id"]}|${item["status"]}|${[for (final task in item["tasks"] as List? ?? const [])
          if (task is Map) "${task["id"]}:${task["status"]}:${task["assigneeId"]}:${(task["rejections"] as List?)?.length ?? 0}"].join(",")}",
  ]..sort();
  final audit = [
    for (final item in state["audit"] as List)
      if (item is Map) "${item["id"]}",
  ]..sort();
  return "${state["counter"]}|${accounts.join(";")}||${handovers.join(";")}||${audit.join(";")}";
}

class SharedBin {
  /// Null means the read failed. Callers must not save over the bin in that case,
  /// or a new device's request gets wiped by an empty copy.
  ///
  /// The query string is the cache buster. Do not add request headers here:
  /// a header such as Cache-Control turns this into a CORS preflight that
  /// jsonstorage rejects, the read throws, and the request never leaves
  /// the browser that created it.
  Future<Map<String, dynamic>?> fetch() async {
    final uri = sharedBinUri.replace(
      queryParameters: {"v": "${DateTime.now().microsecondsSinceEpoch}"},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) return emptySharedState();
    if (response.statusCode != 200 || response.body.isEmpty) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    return asSharedState(decoded);
  }

  Future<bool> save(Map<String, dynamic> state) async {
    final response = await http
        .put(
          sharedBinUri,
          headers: {
            "Content-Type": "application/json",
            "X-Bin-Key": sharedBinKey,
          },
          body: jsonEncode(state),
        )
        .timeout(const Duration(seconds: 15));
    return response.statusCode < 400;
  }
}
