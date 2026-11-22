import "package:flutter/foundation.dart";

import "directory.dart";
import "models.dart";

class AppStore extends ChangeNotifier {
  Employee? user;
  final List<Handover> handovers = [];
  int _counter = 0;

  String get loginHint => employees.map((e) => e.email).join("\n");

  void signIn(String email) {
    final person = byEmail(email);
    if (person == null) {
      throw "ما فيه موظف بهذا الإيميل في الدليل التجريبي.";
    }
    user = person;
    notifyListeners();
  }

  void signOut() {
    user = null;
    notifyListeners();
  }

  List<Handover> inboxFor(Employee me) {
    return handovers.where((h) {
      if (h.employeeId == me.id) return true;
      if (me.role == Role.hr) return true;
      if (byId(h.employeeId)?.managerId == me.id) return true;
      return h.tasks.any((t) => t.assigneeId == me.id);
    }).toList();
  }

  List<Employee> colleaguesOf(Employee me) {
    final sameDept = employees.where((e) => e.id != me.id && e.departmentId == me.departmentId).toList();
    if (sameDept.isNotEmpty) return sameDept;
    return employees.where((e) => e.id != me.id).toList();
  }

  Handover startClearance(ApprovedRequest request) {
    final me = user;
    if (me == null || me.role != Role.hr) throw "فقط الموارد البشرية تبدأ إخلاء الطرف.";
    if (handovers.any((h) => h.requestRef == request.ref)) {
      throw "هذا الطلب بدأ مسبقاً.";
    }
    _counter += 1;
    final handover = Handover(
      id: "h$_counter",
      number: "HO-2026-${_counter.toString().padLeft(4, "0")}",
      requestRef: request.ref,
      type: request.type,
      employeeId: request.employeeId,
      status: HandoverStatus.draft,
      createdAt: DateTime.now(),
    );
    handovers.insert(0, handover);
    notifyListeners();
    return handover;
  }

  Handover must(String id) => handovers.firstWhere((h) => h.id == id);

  void saveForm(String id, String notes, List<HandoverTask> tasks, {required bool submit}) {
    final me = user!;
    final h = must(id);
    if (h.employeeId != me.id) throw "هذا النموذج ليس لك.";
    if (h.status != HandoverStatus.draft && h.status != HandoverStatus.returned) {
      throw "ما عاد ينعدل.";
    }
    if (submit) {
      if (tasks.isEmpty) throw "أضف مهمة واحدة على الأقل.";
      for (final task in tasks) {
        if (task.title.trim().isEmpty) throw "كل مهمة تحتاج عنوان.";
        if (task.assigneeId.isEmpty) throw "كل مهمة تحتاج مستلم.";
        if (task.assigneeId == me.id) throw "ما تقدر تسند المهمة لنفسك.";
        task.status = TaskStatus.pending;
      }
      h.status = HandoverStatus.pendingAcceptance;
      h.returnComment = null;
    }
    h.generalNotes = notes;
    h.tasks
      ..clear()
      ..addAll(tasks);
    notifyListeners();
  }

  void acceptTask(String id, String taskId) {
    final me = user!;
    final task = must(id).tasks.firstWhere((t) => t.id == taskId);
    if (task.assigneeId != me.id) throw "هذه المهمة ليست لك.";
    task.status = TaskStatus.accepted;
    _advanceIfReady(must(id));
    notifyListeners();
  }

  void rejectTask(String id, String taskId, String comment) {
    final me = user!;
    final h = must(id);
    final task = h.tasks.firstWhere((t) => t.id == taskId);
    if (task.assigneeId != me.id) throw "هذه المهمة ليست لك.";
    if (comment.trim().length < 3) throw "اكتب سبب الرفض.";
    task.status = TaskStatus.rejected;
    task.rejectComment = comment.trim();
    h.status = HandoverStatus.returned;
    h.returnComment = "${me.nameAr} رفضت المهمة: ${comment.trim()}";
    notifyListeners();
  }

  void reassignTask(String id, String taskId, String assigneeId) {
    final me = user!;
    final h = must(id);
    if (h.employeeId != me.id) throw "هذا النموذج ليس لك.";
    final task = h.tasks.firstWhere((t) => t.id == taskId);
    if (assigneeId == me.id) throw "اختر زميلاً آخر.";
    task.assigneeId = assigneeId;
    task.status = TaskStatus.pending;
    task.rejectComment = "";
    h.status = HandoverStatus.pendingAcceptance;
    h.returnComment = null;
    notifyListeners();
  }

  void managerDecide(String id, {required bool approve, String comment = ""}) {
    final me = user!;
    final h = must(id);
    final owner = byId(h.employeeId)!;
    if (owner.managerId != me.id) throw "أنت لست مدير هذا الموظف.";
    if (h.status != HandoverStatus.pendingManager) throw "النموذج ليس عند المدير.";
    if (!approve && comment.trim().length < 3) throw "اكتب سبب الإعادة.";
    if (approve) {
      h.status = HandoverStatus.pendingHr;
    } else {
      h.status = HandoverStatus.returned;
      h.returnComment = comment.trim();
    }
    notifyListeners();
  }

  void hrDecide(String id, {required bool approve, String comment = ""}) {
    final me = user!;
    final h = must(id);
    if (me.role != Role.hr) throw "فقط الموارد البشرية تعتمد.";
    if (h.employeeId == me.id) throw "ما تقدر تعتمد طلبك.";
    if (h.status != HandoverStatus.pendingHr) throw "النموذج ليس عند الموارد البشرية.";
    if (!approve && comment.trim().length < 3) throw "اكتب سبب الإعادة.";
    if (approve) {
      h.status = HandoverStatus.approved;
    } else {
      h.status = HandoverStatus.returned;
      h.returnComment = comment.trim();
    }
    notifyListeners();
  }

  void _advanceIfReady(Handover h) {
    if (h.tasks.isEmpty || h.tasks.any((t) => t.status != TaskStatus.accepted)) return;
    h.status = HandoverStatus.pendingManager;
  }
}
