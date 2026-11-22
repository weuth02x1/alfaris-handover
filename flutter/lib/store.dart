import "dart:convert";
import "dart:math";

import "package:crypto/crypto.dart";
import "package:material_ui/material_ui.dart";

import "directory.dart";
import "i18n.dart";
import "mail_api.dart";
import "models.dart";

class InboxItem {
  InboxItem({required this.handover, this.task});
  final Handover handover;
  final HandoverTask? task;
}

class Inbox {
  Inbox({
    required this.mine,
    required this.toAccept,
    required this.accepted,
    required this.managerQueue,
    required this.hrQueue,
  });
  final List<Handover> mine;
  final List<InboxItem> toAccept;
  final List<InboxItem> accepted;
  final List<Handover> managerQueue;
  final List<Handover> hrQueue;
  bool get isEmpty =>
      mine.isEmpty && toAccept.isEmpty && accepted.isEmpty && managerQueue.isEmpty && hrQueue.isEmpty;
}

class Access {
  Access({
    required this.isOwner,
    required this.isManager,
    required this.isHr,
    required this.isRecipient,
  });
  final bool isOwner;
  final bool isManager;
  final bool isHr;
  final bool isRecipient;
}

class AppStore extends ChangeNotifier {
  AppStore() {
    accounts = List.of(mockEmployees);
  }

  final _rng = Random();
  String locale = "ar";
  I18n get t => I18n(locale);

  Employee? user;
  String? lastOtpEmail;
  String? lastOtpCode;
  String? otpChallenge;
  bool otpDelivered = false;

  late List<Employee> accounts;
  final handovers = <Handover>[];
  final auditLog = <AuditEntry>[];
  final outbox = <EmailMessage>[];
  final otps = <OtpChallenge>[];
  int counter = 0;

  List<Employee> get people => accounts;
  Employee? person(String? id) {
    if (id == null) return null;
    for (final e in accounts) {
      if (e.id == id) return e;
    }
    return null;
  }

  String nameOf(Employee? e) {
    if (e == null) return t.dash;
    return t.pick(e.nameAr, e.nameEn);
  }

  String nameSnap(EmployeeSnapshot e) => t.pick(e.nameAr, e.nameEn);

  void toggleLocale() {
    locale = locale == "ar" ? "en" : "ar";
    notifyListeners();
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
  // Bit shifts of 32 are 0 on the web (JS), so keep this under 2^31.
  String _id() =>
      "${DateTime.now().microsecondsSinceEpoch}-${_rng.nextInt(0x7fffffff)}-${_rng.nextInt(0x7fffffff)}";
  String _code() => (_rng.nextInt(900000) + 100000).toString();

  Employee? findByEmail(String email) {
    final target = email.trim().toLowerCase();
    for (final e in accounts) {
      if (e.email.toLowerCase() == target) return e;
    }
    return null;
  }

  List<Employee> colleaguesFor(String employeeId) {
    final me = person(employeeId);
    if (me == null) return [];
    final sameDept = accounts.where((p) => p.id != me.id && p.departmentId == me.departmentId).toList();
    if (sameDept.isNotEmpty) return sameDept;
    return accounts.where((p) => p.id != me.id && p.branchId == me.branchId).toList();
  }

  List<Employee> get hrUsers => accounts.where((e) => e.isHr).toList();

  Future<void> requestOtp(String email) async {
    final emp = findByEmail(email);
    if (emp == null) throw WorkflowException("notFoundEmail");
    if (MailApi.enabled) {
      try {
        final sent = await MailApi.request(emp.email);
        otpChallenge = sent.challenge;
        lastOtpEmail = emp.email;
        lastOtpCode = null;
        otpDelivered = true;
        notifyListeners();
        return;
      } catch (error) {
        final code = error.toString().replaceFirst("Exception: ", "");
        if (code == "slow" || code == "invalid") throw WorkflowException(code);
        _issueOtp(emp);
        throw WorkflowException("mailFailed");
      }
    }
    _issueOtp(emp);
  }

  Future<void> register({
    required String email,
    required String name,
    required String employeeNo,
    required String jobTitle,
    required String departmentId,
  }) async {
    final mail = email.trim().toLowerCase();
    final n = name.trim();
    final no = employeeNo.trim();
    final job = jobTitle.trim();
    final dept = switch (departmentId) {
      "D-HR" => hrDept,
      "D-TA" => talent,
      "D-ITD" => itDev,
      _ => null,
    };
    if (!_isEmail(mail) || n.length < 2 || n.length > 80) throw WorkflowException("invalid");
    if (!RegExp(r"^\d{3,10}$").hasMatch(no)) throw WorkflowException("invalid");
    if (job.length < 2 || job.length > 80) throw WorkflowException("invalid");
    if (dept == null) throw WorkflowException("invalid");
    if (accounts.any((p) => p.email.toLowerCase() == mail)) throw WorkflowException("emailTaken");
    if (accounts.any((p) => p.id == no || p.staffNumber == no)) throw WorkflowException("idTaken");

    final emp = Employee(
      id: "local-$_id()",
      staffNumber: no,
      nameAr: n,
      nameEn: n,
      jobTitleAr: job,
      jobTitleEn: job,
      departmentId: dept["departmentId"]!,
      departmentAr: dept["departmentAr"]!,
      departmentEn: dept["departmentEn"]!,
      sectionAr: dept["sectionAr"]!,
      sectionEn: dept["sectionEn"]!,
      branchId: "B-RUH",
      managerId: null,
      email: mail,
      role: "employee",
    );
    accounts.add(emp);
    await requestOtp(emp.email);
  }

  bool _isEmail(String value) => RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$").hasMatch(value) && value.length <= 160;

  String _issueOtp(Employee emp) {
    final code = _code();
    otps.removeWhere((o) => o.email == emp.email.toLowerCase());
    otps.add(
      OtpChallenge(
        employeeId: emp.id,
        email: emp.email.toLowerCase(),
        code: code,
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String(),
      ),
    );
    lastOtpEmail = emp.email;
    lastOtpCode = code;
    otpChallenge = null;
    otpDelivered = false;
    outbox.add(
      EmailMessage(
        id: _id(),
        to: emp.email,
        toEmployeeId: emp.id,
        subject: locale == "ar" ? "رمز الدخول | Sign-in code" : "Sign-in code | رمز الدخول",
        body: "رمز الدخول: $code\nYour sign-in code: $code",
        at: _now(),
        kind: "otp",
        otpCode: code,
      ),
    );
    notifyListeners();
    return code;
  }

  Future<void> verifyOtp(String email, String code) async {
    final emp = findByEmail(email);
    if (emp == null) throw WorkflowException("notFoundEmail");
    if (MailApi.enabled && otpChallenge != null) {
      try {
        await MailApi.verify(emp.email, code.trim(), otpChallenge!);
      } catch (error) {
        final mapped = error.toString().replaceFirst("Exception: ", "");
        throw WorkflowException(["badCode", "expired", "slow", "mailFailed"].contains(mapped) ? mapped : "badCode");
      }
      user = emp;
      lastOtpCode = null;
      otpChallenge = null;
      notifyListeners();
      return;
    }
    OtpChallenge? otp;
    for (final o in otps) {
      if (o.email == emp.email.toLowerCase()) otp = o;
    }
    if (otp == null) throw WorkflowException("expired");
    if (DateTime.parse(otp.expiresAt).isBefore(DateTime.now().toUtc())) throw WorkflowException("expired");
    if (otp.code != code.trim()) throw WorkflowException("badCode");
    otps.remove(otp);
    user = emp;
    lastOtpCode = null;
    notifyListeners();
  }

  void logout() {
    user = null;
    notifyListeners();
  }

  Inbox inboxFor(Employee me) {
    final mine = handovers.where((h) => h.employee.id == me.id).toList();
    final toAccept = <InboxItem>[];
    final accepted = <InboxItem>[];
    for (final h in handovers) {
      for (final task in h.tasks) {
        if (task.assigneeId != me.id) continue;
        if (task.status == "pending" && h.status == "pending_acceptance") {
          toAccept.add(InboxItem(handover: h, task: task));
        } else if (task.status == "accepted") {
          accepted.add(InboxItem(handover: h, task: task));
        }
      }
    }
    final managerQueue = handovers.where((h) => h.status == "pending_manager" && h.employee.managerId == me.id).toList();
    final hrQueue = me.isHr ? handovers.where((h) => h.status == "pending_hr").toList() : <Handover>[];
    return Inbox(mine: mine, toAccept: toAccept, accepted: accepted, managerQueue: managerQueue, hrQueue: hrQueue);
  }

  Access access(Employee me, Handover h) {
    final isOwner = h.employee.id == me.id;
    final isManager = h.employee.managerId == me.id;
    final isHr = me.isHr;
    final isRecipient = h.tasks.any((t) => t.assigneeId == me.id || t.rejections.any((r) => r.recipientId == me.id));
    return Access(isOwner: isOwner, isManager: isManager, isHr: isHr, isRecipient: isRecipient);
  }

  Handover? handover(String id) {
    for (final h in handovers) {
      if (h.id == id) return h;
    }
    return null;
  }

  List<AuditEntry> auditFor(String handoverId) =>
      auditLog.where((a) => a.handoverId == handoverId).toList().reversed.toList();

  List<EmailMessage> mailFor(Employee me) =>
      outbox.where((m) => m.kind != "otp" && m.toEmployeeId == me.id).toList().reversed.toList();

  String initiateClearance(Employee actor, String requestRef, {String? reason}) {
    if (!actor.isHr) throw WorkflowException("notAllowed");
    ApprovedRequest? req;
    for (final r in mockApprovedRequests) {
      if (r.ref == requestRef) req = r;
    }
    if (req == null) throw WorkflowException("notFound");
    Handover? existing;
    for (final h in handovers) {
      if (h.requestRef == req.ref) existing = h;
    }
    if (existing != null) return existing.id;
    final emp = person(req.employeeId);
    if (emp == null) throw WorkflowException("notFound");
    final manager = person(emp.managerId);
    counter += 1;
    final h = Handover(
      id: _id(),
      number: "HO-${DateTime.now().year}-${counter.toString().padLeft(4, "0")}",
      requestRef: req.ref,
      type: reason != null && exitReasons.contains(reason) ? reason : req.type,
      lastWorkingDay: req.startDate,
      returnDate: req.endDate,
      employee: EmployeeSnapshot(
        id: emp.id,
        nameAr: emp.nameAr,
        nameEn: emp.nameEn,
        jobTitleAr: emp.jobTitleAr,
        jobTitleEn: emp.jobTitleEn,
        departmentAr: emp.departmentAr,
        departmentEn: emp.departmentEn,
        sectionAr: emp.sectionAr,
        sectionEn: emp.sectionEn,
        managerId: emp.managerId,
        managerNameAr: manager?.nameAr ?? "",
        managerNameEn: manager?.nameEn ?? "",
      ),
      status: "draft",
      initiatedById: actor.id,
      createdAt: _now(),
    );
    handovers.add(h);
    _audit(h, actor.id, "clearance_initiated", req.ref);
    _notify(
      h,
      emp,
      "مطلوب: تعبئة نموذج تسليم المهام ${h.number} | Action required: handover form",
      "بدأت الموارد البشرية إخلاء الطرف للطلب ${req.ref}. افتح الرابط الآمن، سجّل الدخول، وعبّئ نموذج تسليم المهام وحدد مستلم كل مهمة.\n\nHR has started clearance for ${req.ref}. Open the secure link, sign in, fill in your handover form and assign each task.",
    );
    _audit(h, "system", "link_sent", emp.email);
    notifyListeners();
    return h.id;
  }

  void saveForm(Employee actor, String id, {required String generalNotes, required List<HandoverTask> tasks, required bool submit}) {
    final h = handover(id) ?? (throw WorkflowException("notFound"));
    if (h.employee.id != actor.id) throw WorkflowException("notAllowed");
    if (h.status != "draft" && h.status != "returned") throw WorkflowException("notAllowed");
    if (tasks.length > 40 || generalNotes.length > 4000) throw WorkflowException("notAllowed");
    final colleagueIds = colleaguesFor(actor.id).map((c) => c.id).toSet();
    for (final task in tasks) {
      if (task.title.length > 160 || task.details.length > 2000) throw WorkflowException("notAllowed");
      if (submit && task.title.trim().isEmpty) throw WorkflowException("titleRequired");
      if (submit && task.assigneeId.isEmpty) throw WorkflowException("assigneeRequired");
      if (task.assigneeId.isNotEmpty && !colleagueIds.contains(task.assigneeId)) throw WorkflowException("notAllowed");
    }
    if (submit && tasks.isEmpty) throw WorkflowException("noTasks");

    final previous = {for (final t in h.tasks) t.id: t};
    h.generalNotes = generalNotes;
    h.tasks = tasks.map((ti) {
      final prev = previous[ti.id];
      final unchanged = prev != null &&
          prev.title == ti.title &&
          prev.details == ti.details &&
          prev.dueDate == ti.dueDate &&
          prev.assigneeId == ti.assigneeId;
      if (prev != null && unchanged && prev.status == "accepted") return prev;
      return HandoverTask(
        id: prev?.id ?? (ti.id.isEmpty ? _id() : ti.id),
        title: ti.title.trim(),
        details: ti.details.trim(),
        dueDate: (ti.dueDate == null || ti.dueDate!.isEmpty) ? null : ti.dueDate,
        assigneeId: ti.assigneeId,
        status: "draft",
        rejections: prev?.rejections ?? [],
      );
    }).toList();

    if (!submit) {
      _audit(h, actor.id, "form_saved");
      notifyListeners();
      return;
    }

    h.submittedAt = _now();
    h.lastReturn = null;
    h.managerApproval = null;
    h.hrApproval = null;
    _audit(h, actor.id, "form_submitted", "${h.tasks.length}");
    for (final task in h.tasks) {
      if (task.status == "accepted") continue;
      task.status = "pending";
      final recipient = colleaguesFor(actor.id).firstWhere((c) => c.id == task.assigneeId);
      _audit(h, actor.id, "task_assigned", "${task.title} → ${recipient.nameAr}");
      _notifyRecipient(h, task, recipient, actor);
    }
    _advanceIfAllAccepted(h);
    notifyListeners();
  }

  void acceptTask(Employee actor, String id, String taskId, String note) {
    final h = handover(id) ?? (throw WorkflowException("notFound"));
    final task = _task(h, taskId);
    if (task == null || task.assigneeId != actor.id || task.status != "pending" || h.status != "pending_acceptance") {
      throw WorkflowException("notAllowed");
    }
    task.status = "accepted";
    task.acceptedAt = _now();
    task.acceptNote = note.trim().isEmpty ? null : note.trim();
    _audit(h, actor.id, "task_accepted", task.title);
    _advanceIfAllAccepted(h);
    notifyListeners();
  }

  void rejectTask(Employee actor, String id, String taskId, String comment) {
    if (comment.trim().isEmpty) throw WorkflowException("commentRequired");
    final h = handover(id) ?? (throw WorkflowException("notFound"));
    final task = _task(h, taskId);
    if (task == null || task.assigneeId != actor.id || task.status != "pending" || h.status != "pending_acceptance") {
      throw WorkflowException("notAllowed");
    }
    final owner = person(h.employee.id) ?? (throw WorkflowException("notFound"));
    task.status = "rejected";
    task.rejections.add(TaskRejection(recipientId: actor.id, comment: comment.trim(), at: _now()));
    _audit(h, actor.id, "task_rejected", "${task.title}: ${comment.trim()}");
    _notify(
      h,
      owner,
      "رفض ${actor.nameAr} استلام مهمة | ${actor.nameEn} declined a task",
      "رفض ${actor.nameAr} استلام المهمة \"${task.title}\".\nالسبب: ${comment.trim()}\nافتح النموذج واختر موظفاً آخر لهذه المهمة.\n\n${actor.nameEn} declined \"${task.title}\". Reason: ${comment.trim()}\nOpen the form and pick another employee.",
    );
    notifyListeners();
  }

  void reassignTask(Employee actor, String id, String taskId, String newAssigneeId) {
    final h = handover(id) ?? (throw WorkflowException("notFound"));
    if (h.employee.id != actor.id || h.status != "pending_acceptance") throw WorkflowException("notAllowed");
    final task = _task(h, taskId);
    if (task == null || task.status != "rejected") throw WorkflowException("notAllowed");
    if (task.rejections.any((r) => r.recipientId == newAssigneeId)) throw WorkflowException("sameAssignee");
    Employee? recipient;
    for (final c in colleaguesFor(actor.id)) {
      if (c.id == newAssigneeId) recipient = c;
    }
    if (recipient == null) throw WorkflowException("assigneeRequired");
    task.assigneeId = newAssigneeId;
    task.status = "pending";
    _audit(h, actor.id, "task_reassigned", "${task.title} → ${recipient.nameAr}");
    _notifyRecipient(h, task, recipient, actor);
    notifyListeners();
  }

  void managerDecision(Employee actor, String id, bool approve, String comment) {
    if (!approve && comment.trim().isEmpty) throw WorkflowException("commentRequired");
    final h = handover(id) ?? (throw WorkflowException("notFound"));
    if (h.employee.id == actor.id) throw WorkflowException("notAllowed");
    if (h.status != "pending_manager" || h.employee.managerId != actor.id) throw WorkflowException("notAllowed");
    final owner = person(h.employee.id) ?? (throw WorkflowException("notFound"));
    if (approve) {
      h.managerApproval = Approval(byId: actor.id, at: _now(), comment: comment.trim().isEmpty ? null : comment.trim());
      _audit(h, actor.id, "manager_approved", comment.trim());
      _moveToHr(h);
    } else {
      _returnToEmployee(h, owner, actor, "manager", comment.trim());
    }
    notifyListeners();
  }

  void hrDecision(Employee actor, String id, bool approve, String comment) {
    if (!actor.isHr) throw WorkflowException("notAllowed");
    if (!approve && comment.trim().isEmpty) throw WorkflowException("commentRequired");
    final h = handover(id) ?? (throw WorkflowException("notFound"));
    if (h.employee.id == actor.id) throw WorkflowException("notAllowed");
    if (h.status != "pending_hr") throw WorkflowException("notAllowed");
    final owner = person(h.employee.id) ?? (throw WorkflowException("notFound"));
    if (!approve) {
      _returnToEmployee(h, owner, actor, "hr", comment.trim());
      notifyListeners();
      return;
    }
    h.hrApproval = Approval(byId: actor.id, at: _now(), comment: comment.trim().isEmpty ? null : comment.trim());
    h.status = "approved";
    h.finalizedAt = _now();
    h.documentHash = sha256.convert(utf8.encode(jsonEncode(_canonical(h)))).toString();
    _audit(h, actor.id, "hr_approved", comment.trim());
    _audit(h, "system", "document_generated", h.documentHash!.substring(0, 16));
    _notify(
      h,
      owner,
      "اكتمل تسليم المهام ${h.number} | Handover completed",
      "تم الاعتماد النهائي لنموذج تسليم المهام وإصدار التقرير وحفظه في ملفك بنظام الموارد البشرية.\n\nYour handover was approved and the final report is filed on your HR record.",
    );
    h.hrmsDocumentId = "MENA-${h.number}";
    _audit(h, "system", "document_uploaded", h.hrmsDocumentId!);
    notifyListeners();
  }

  void _notifyRecipient(Handover h, HandoverTask task, Employee recipient, Employee from) {
    _notify(
      h,
      recipient,
      "${from.nameAr} أسند لك مهام، ادخل للموافقة",
      "${from.nameAr} أسند لك مهام وتحتاج موافقتك.\nالمهمة: ${task.title}${task.details.isNotEmpty ? "\n${task.details}" : ""}\n\nادخل عبر الرابط للموافقة أو الرفض. الموقع ما يرسل إشعارات داخل المتصفح، والاعتماد يصير من الرابط في هذا الإيميل.\n\n${from.nameEn} assigned you a task and needs your approval: ${task.title}",
    );
  }

  void _advanceIfAllAccepted(Handover h) {
    if (!h.tasks.every((t) => t.status == "accepted")) {
      h.status = "pending_acceptance";
      return;
    }
    final manager = person(h.employee.managerId);
    if (manager != null) {
      h.status = "pending_manager";
      _notify(
        h,
        manager,
        "بانتظار اعتمادك: نموذج تسليم ${h.employee.nameAr} | Approval needed",
        "قبل جميع المستلمين مهام ${h.employee.nameAr} في النموذج ${h.number}. راجع النموذج واعتمده أو أعده مع ذكر السبب.\n\nAll recipients accepted ${h.employee.nameEn}'s tasks (${h.number}). Please review and approve or return it.",
      );
    } else {
      _moveToHr(h);
    }
  }

  void _moveToHr(Handover h) {
    h.status = "pending_hr";
    for (final u in hrUsers) {
      _notify(
        h,
        u,
        "اعتماد نهائي مطلوب: ${h.number} | Final HR approval needed",
        "اعتمد المدير المباشر نموذج تسليم ${h.employee.nameAr} (${h.number}). الاعتماد النهائي يصدر التقرير ويرفعه لملف الموظف.\n\n${h.number} for ${h.employee.nameEn} is ready for final HR approval.",
      );
    }
  }

  void _returnToEmployee(Handover h, Employee owner, Employee actor, String stage, String comment) {
    h.status = "returned";
    h.lastReturn = ReturnInfo(stage: stage, byId: actor.id, comment: comment, at: _now());
    _audit(h, actor.id, stage == "manager" ? "manager_rejected" : "hr_rejected", comment);
    _notify(
      h,
      owner,
      "أُعيد نموذج التسليم ${h.number} للتعديل | Handover returned for correction",
      "أعاد ${actor.nameAr} نموذج التسليم إليك.\nالسبب: $comment\nعدّل النموذج وأعد إرساله.\n\n${actor.nameEn} returned your handover form. Reason: $comment",
    );
  }

  void _notify(Handover h, Employee to, String subject, String body) {
    outbox.add(
      EmailMessage(
        id: _id(),
        to: to.email,
        toEmployeeId: to.id,
        subject: subject,
        body: body,
        link: "/handovers/${h.id}",
        at: _now(),
        kind: "workflow",
      ),
    );
    if (outbox.length > 100) outbox.removeRange(0, outbox.length - 100);
  }

  void _audit(Handover h, String actorId, String action, [String details = ""]) {
    auditLog.add(AuditEntry(id: _id(), handoverId: h.id, at: _now(), actorId: actorId, action: action, details: details));
  }

  HandoverTask? _task(Handover h, String taskId) {
    for (final t in h.tasks) {
      if (t.id == taskId) return t;
    }
    return null;
  }

  Map<String, Object?> _canonical(Handover h) => {
        "number": h.number,
        "requestRef": h.requestRef,
        "type": h.type,
        "lastWorkingDay": h.lastWorkingDay,
        "returnDate": h.returnDate,
        "employee": {
          "id": h.employee.id,
          "nameAr": h.employee.nameAr,
          "nameEn": h.employee.nameEn,
        },
        "generalNotes": h.generalNotes,
        "tasks": [
          for (final t in h.tasks)
            {
              "title": t.title,
              "details": t.details,
              "dueDate": t.dueDate,
              "assigneeId": t.assigneeId,
              "acceptedAt": t.acceptedAt,
              "acceptNote": t.acceptNote,
            },
        ],
        "managerApproval": h.managerApproval == null
            ? null
            : {"byId": h.managerApproval!.byId, "at": h.managerApproval!.at, "comment": h.managerApproval!.comment},
        "hrApproval": h.hrApproval == null
            ? null
            : {"byId": h.hrApproval!.byId, "at": h.hrApproval!.at, "comment": h.hrApproval!.comment},
        "finalizedAt": h.finalizedAt,
      };
}

class StoreScope extends InheritedWidget {
  const StoreScope({super.key, required this.store, required super.child});
  final AppStore store;

  static AppStore of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StoreScope>()!.store;
  }

  @override
  bool updateShouldNotify(StoreScope oldWidget) => store != oldWidget.store;
}
