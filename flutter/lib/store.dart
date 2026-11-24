import "dart:async";
import "dart:convert";
import "dart:math";

import "package:crypto/crypto.dart";
import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";

import "auth_mail.dart";
import "directory.dart";
import "i18n.dart";
import "local_box.dart";
import "models.dart";
import "persist.dart";
import "shared_state.dart";

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
    required this.teamOpen,
    required this.needsReassign,
    required this.hrQueue,
    required this.raised,
  });
  final List<Handover> mine;
  final List<InboxItem> toAccept;
  final List<InboxItem> accepted;
  final List<Handover> managerQueue;
  final List<Handover> teamOpen;
  final List<Handover> needsReassign;
  final List<Handover> hrQueue;
  final List<Handover> raised;
  bool get isEmpty =>
      mine.isEmpty &&
      toAccept.isEmpty &&
      accepted.isEmpty &&
      managerQueue.isEmpty &&
      teamOpen.isEmpty &&
      needsReassign.isEmpty &&
      hrQueue.isEmpty &&
      raised.isEmpty;
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
  AppStore({LocalBox? box}) : _box = box ?? createLocalBox() {
    accounts = [];
    _load();
  }

  final LocalBox _box;
  final SharedBin _shared = SharedBin();
  bool _hydrating = false;
  bool _syncing = false;
  bool _syncQueued = false;
  Timer? _syncTimer;
  static const _storageKey = "alfaris-handover-v1";

  @override
  void notifyListeners() {
    if (!_hydrating) _persist();
    super.notifyListeners();
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

  Employee? findByEmail(String email) {
    final target = email.trim().toLowerCase();
    final matches = [
      for (final e in accounts)
        if (e.email.toLowerCase() == target) e,
    ];
    if (matches.isEmpty) return null;
    final current = user?.id;
    for (final e in matches) {
      if (e.id == current) return e;
    }
    matches.sort((a, b) => _emailScore(b).compareTo(_emailScore(a)));
    return matches.first;
  }

  int _emailScore(Employee e) {
    var score = 0;
    for (final h in handovers) {
      if (h.employee.id != e.id && h.initiatedById != e.id) continue;
      score += h.status == "approved" ? 1 : 5;
    }
    return score;
  }

  Set<String> _idsForEmail(String email) {
    final target = email.trim().toLowerCase();
    return {
      for (final e in accounts)
        if (e.email.toLowerCase() == target) e.id,
    };
  }

  bool _owns(Employee me, Handover h) {
    final ids = _idsForEmail(me.email);
    ids.add(me.id);
    return ids.contains(h.employee.id) || ids.contains(h.initiatedById);
  }

  List<Employee> colleaguesFor(String employeeId) {
    final me = person(employeeId);
    if (me == null) return [];
    return accounts.where((p) => p.id != me.id).toList();
  }

  List<Employee> managersFor(String departmentId) {
    final managers = accounts.where((p) => p.isManager).toList();
    managers.sort((a, b) {
      final am = a.managesDepartmentId == departmentId ? 0 : 1;
      final bm = b.managesDepartmentId == departmentId ? 0 : 1;
      return am.compareTo(bm);
    });
    return managers;
  }

  List<Employee> get hrUsers => accounts.where((e) => e.isHr).toList();

  Future<void> requestOtp(String email) async {
    final mail = email.trim().toLowerCase();
    if (!_isEmail(mail)) throw WorkflowException("invalid");
    final emp = findByEmail(mail);
    if (emp == null) throw WorkflowException("notFoundEmail");
    try {
      await AuthMail.send(emp.email);
    } on WorkflowException {
      rethrow;
    } catch (_) {
      throw WorkflowException("mailFailed");
    }
    lastOtpEmail = emp.email;
    lastOtpCode = null;
    otpDelivered = true;
    notifyListeners();
  }

  Employee createAccount({
    required String email,
    required String name,
    required String employeeNo,
    required String jobTitle,
    required String departmentId,
    String? managerId,
    bool isManager = false,
    String? managesDepartmentId,
  }) {
    final mail = email.trim().toLowerCase();
    final n = name.trim();
    final no = employeeNo.trim();
    final job = jobTitle.trim();
    final dept = departmentById(departmentId);
    final managed = isManager
        ? departmentById(managesDepartmentId ?? "")
        : null;
    if (!_isEmail(mail) || n.length < 2 || n.length > 80) {
      throw WorkflowException("invalid");
    }
    if (!RegExp(r"^\d{3,10}$").hasMatch(no)) throw WorkflowException("invalid");
    if (job.length < 2 || job.length > 80) throw WorkflowException("invalid");
    if (dept == null) throw WorkflowException("invalid");
    if (isManager && managed == null) throw WorkflowException("invalid");
    if (accounts.any((p) => p.email.toLowerCase() == mail)) {
      throw WorkflowException("emailTaken");
    }
    if (accounts.any((p) => p.id == no || p.staffNumber == no)) {
      throw WorkflowException("idTaken");
    }
    final bossId = (managerId == null || managerId.isEmpty) ? null : managerId;
    if (bossId != null) {
      final boss = person(bossId);
      if (boss == null || !boss.isManager) throw WorkflowException("invalid");
    }
    final emp = Employee(
      id: no,
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
      managerId: bossId,
      email: mail,
      role: departmentId == "D-HR" ? "hr" : "employee",
      isManager: isManager,
      managesDepartmentId: managed?["departmentId"],
    );
    accounts.add(emp);
    notifyListeners();
    return emp;
  }

  /// Four linked accounts so one inbox can walk the whole handover cycle.
  /// The plus-addresses all deliver to shahad0x66@gmail.com.
  void ensureCycleAccounts() {
    _addCycle(
      email: "shahad0x66+hr@gmail.com",
      name: "شهد القحطاني",
      employeeNo: "22015",
      jobTitle: "أخصائية موارد بشرية",
      departmentId: "D-HR",
    );
    _addCycle(
      email: "shahad0x66+manager@gmail.com",
      name: "شهد القحطاني",
      employeeNo: "22001",
      jobTitle: "مديرة تطوير تقنية المعلومات",
      departmentId: "D-ITD",
      isManager: true,
      managesDepartmentId: "D-ITD",
    );
    _addCycle(
      email: "shahad0x66+colleague@gmail.com",
      name: "شهد القحطاني",
      employeeNo: "22030",
      jobTitle: "مطورة أنظمة",
      departmentId: "D-ITD",
      managerId: "22001",
    );
    _addCycle(
      email: "shahad0x66@gmail.com",
      name: "شهد القحطاني",
      employeeNo: "22018",
      jobTitle: "مطورة أنظمة",
      departmentId: "D-ITD",
      managerId: "22001",
    );
  }

  void _addCycle({
    required String email,
    required String name,
    required String employeeNo,
    required String jobTitle,
    required String departmentId,
    String? managerId,
    bool isManager = false,
    String? managesDepartmentId,
  }) {
    if (findByEmail(email) != null || person(employeeNo) != null) return;
    try {
      createAccount(
        email: email,
        name: name,
        employeeNo: employeeNo,
        jobTitle: jobTitle,
        departmentId: departmentId,
        managerId: managerId,
        isManager: isManager,
        managesDepartmentId: managesDepartmentId,
      );
    } on WorkflowException {
      return;
    }
  }

  Future<void> register({
    required String email,
    required String name,
    required String employeeNo,
    required String jobTitle,
    required String departmentId,
    String? managerId,
    bool isManager = false,
    String? managesDepartmentId,
  }) async {
    final emp = createAccount(
      email: email,
      name: name,
      employeeNo: employeeNo,
      jobTitle: jobTitle,
      departmentId: departmentId,
      managerId: managerId,
      isManager: isManager,
      managesDepartmentId: managesDepartmentId,
    );
    await requestOtp(emp.email);
  }

  bool _isEmail(String value) =>
      RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$").hasMatch(value) &&
      value.length <= 160;

  void signInForTest(Employee emp) {
    user = emp;
    lastOtpCode = null;
    notifyListeners();
  }

  Future<void> verifyOtp(String email, String code) async {
    final emp = findByEmail(email);
    if (emp == null) throw WorkflowException("notFoundEmail");
    try {
      await AuthMail.verify(emp.email, code);
    } catch (_) {
      throw WorkflowException("badCode");
    }
    user = emp;
    lastOtpCode = null;
    notifyListeners();
  }

  void logout() {
    user = null;
    notifyListeners();
  }

  int waitingCount(Employee person) {
    final box = inboxFor(person);
    return box.toAccept.length +
        box.managerQueue.length +
        box.teamOpen.length +
        box.needsReassign.length +
        box.hrQueue.length +
        box.raised.length;
  }

  Inbox inboxFor(Employee me) {
    final mine = handovers.where((h) => _owns(me, h)).toList();
    final toAccept = <InboxItem>[];
    final accepted = <InboxItem>[];
    for (final h in handovers) {
      for (final task in h.tasks) {
        if (task.assigneeId != me.id) continue;
        if (task.status == "pending" &&
            (h.status == "pending_acceptance" ||
                h.status == "pending_manager" ||
                h.status == "pending_hr")) {
          toAccept.add(InboxItem(handover: h, task: task));
        } else if (task.status == "accepted") {
          accepted.add(InboxItem(handover: h, task: task));
        }
      }
    }
    final managerQueue = handovers
        .where(
          (h) => h.status == "pending_manager" && h.employee.managerId == me.id,
        )
        .toList();
    final teamOpen = handovers
        .where(
          (h) =>
              h.employee.managerId == me.id &&
              h.employee.id != me.id &&
              h.status != "approved" &&
              h.status != "pending_hr" &&
              h.status != "pending_manager",
        )
        .toList();
    final needsReassign = handovers
        .where(
          (h) =>
              _owns(me, h) && h.tasks.any((task) => task.status == "rejected"),
        )
        .toList();
    final hrQueue = me.isHr
        ? handovers.where((h) => h.status == "pending_hr").toList()
        : <Handover>[];
    final raised = me.isHr
        ? handovers
              .where(
                (h) =>
                    h.employee.id != me.id &&
                    (h.status == "draft" ||
                        h.status == "returned" ||
                        h.status == "pending_acceptance" ||
                        h.status == "pending_manager"),
              )
              .toList()
        : <Handover>[];
    return Inbox(
      mine: mine,
      toAccept: toAccept,
      accepted: accepted,
      managerQueue: managerQueue,
      teamOpen: teamOpen,
      needsReassign: needsReassign,
      hrQueue: hrQueue,
      raised: raised,
    );
  }

  Access access(Employee me, Handover h) {
    final isOwner = _owns(me, h);
    final isManager = h.employee.managerId == me.id;
    final isHr = me.isHr;
    final isRecipient = h.tasks.any(
      (t) =>
          t.assigneeId == me.id ||
          t.rejections.any((r) => r.recipientId == me.id),
    );
    return Access(
      isOwner: isOwner,
      isManager: isManager,
      isHr: isHr,
      isRecipient: isRecipient,
    );
  }

  Handover? handover(String id) {
    for (final h in handovers) {
      if (h.id == id) return h;
    }
    return null;
  }

  List<AuditEntry> auditFor(String handoverId) => auditLog
      .where((a) => a.handoverId == handoverId)
      .toList()
      .reversed
      .toList();

  List<EmailMessage> mailFor(Employee me) => outbox
      .where((m) => m.kind != "otp" && m.toEmployeeId == me.id)
      .toList()
      .reversed
      .toList();

  String startOwn(
    Employee actor, {
    required String type,
    required String lastWorkingDay,
    String? returnDate,
  }) {
    if (!exitReasons.contains(type)) throw WorkflowException("invalid");
    if (!RegExp(r"^\d{4}-\d{2}-\d{2}$").hasMatch(lastWorkingDay))
      throw WorkflowException("invalid");
    final back = (returnDate == null || returnDate.isEmpty) ? null : returnDate;
    if (back != null && !RegExp(r"^\d{4}-\d{2}-\d{2}$").hasMatch(back))
      throw WorkflowException("invalid");
    final manager = person(actor.managerId);
    counter += 1;
    final h = Handover(
      id: _id(),
      number: "HO-${DateTime.now().year}-${counter.toString().padLeft(4, "0")}",
      requestRef: "SELF-${actor.displayId}-$counter",
      type: type,
      lastWorkingDay: lastWorkingDay,
      returnDate: back,
      employee: EmployeeSnapshot(
        id: actor.id,
        nameAr: actor.nameAr,
        nameEn: actor.nameEn,
        jobTitleAr: actor.jobTitleAr,
        jobTitleEn: actor.jobTitleEn,
        departmentAr: actor.departmentAr,
        departmentEn: actor.departmentEn,
        sectionAr: actor.sectionAr,
        sectionEn: actor.sectionEn,
        managerId: actor.managerId,
        managerNameAr: manager?.nameAr ?? "",
        managerNameEn: manager?.nameEn ?? "",
      ),
      status: "draft",
      initiatedById: actor.id,
      createdAt: _now(),
    );
    handovers.add(h);
    _audit(h, actor.id, "clearance_initiated", h.requestRef);
    _sendToManagerOrHr(h);
    _notify(
      h,
      actor,
      "أرسلت الطلب ${h.number} | Request sent",
      "وش صار: رفع الطلب.\nوين وصل: ${_where(h)}.",
    );
    notifyListeners();
    return h.id;
  }

  /// A raised request is already with someone: the direct manager, or HR when
  /// the employee has no manager. It must not sit as a draft that nobody sees.
  void _sendToManagerOrHr(Handover h) {
    final manager = person(h.employee.managerId);
    if (manager != null && manager.id != h.employee.id) {
      h.status = "pending_manager";
      _notify(
        h,
        manager,
        "طلب ${exitReasonAr(h.type)} من ${h.employee.nameAr} | Approval needed",
        "رفع ${h.employee.nameAr} طلب ${exitReasonAr(h.type)}.\nوش صار: وصل الطلب للمدير المباشر.\nوين وصل: ${_where(h)}.\nافتح نماذج بانتظار اعتمادك كمدير مباشر.",
      );
      return;
    }
    h.status = "pending_hr";
    for (final person in hrUsers) {
      if (person.id == h.employee.id) continue;
      _notify(
        h,
        person,
        "طلب ${exitReasonAr(h.type)} من ${h.employee.nameAr} | HR approval",
        "رفع ${h.employee.nameAr} طلب ${exitReasonAr(h.type)} وما فيه مدير مباشر.\nوش صار: وصل الطلب مباشرة للموارد البشرية.\nوين وصل: ${_where(h)}.\nافتح نماذج بانتظار اعتماد الموارد البشرية.",
      );
    }
  }

  void saveForm(
    Employee actor,
    String id, {
    required String generalNotes,
    required List<HandoverTask> tasks,
    required bool submit,
  }) {
    final h = handover(id) ?? (throw WorkflowException("notFound"));
    if (!_owns(actor, h)) throw WorkflowException("notAllowed");
    if (h.status == "approved") throw WorkflowException("notAllowed");
    if (tasks.length > 40 || generalNotes.length > 4000)
      throw WorkflowException("notAllowed");
    final colleagueIds = colleaguesFor(actor.id).map((c) => c.id).toSet();
    for (final task in tasks) {
      if (task.title.length > 160 || task.details.length > 2000)
        throw WorkflowException("notAllowed");
      if (submit && task.title.trim().isEmpty)
        throw WorkflowException("titleRequired");
      if (submit && task.assigneeId.isEmpty)
        throw WorkflowException("assigneeRequired");
      if (task.assigneeId.isNotEmpty && !colleagueIds.contains(task.assigneeId))
        throw WorkflowException("notAllowed");
    }
    if (submit && tasks.isEmpty) throw WorkflowException("noTasks");

    final previous = {for (final t in h.tasks) t.id: t};
    h.generalNotes = generalNotes;
    h.tasks = tasks.map((ti) {
      final prev = previous[ti.id];
      final unchanged =
          prev != null &&
          prev.title == ti.title &&
          prev.details == ti.details &&
          prev.dueDate == ti.dueDate &&
          prev.assigneeId == ti.assigneeId;
      if (prev != null && unchanged && prev.status == "accepted") return prev;
      return HandoverTask(
        id: prev?.id ?? (ti.id.isEmpty ? _id() : ti.id),
        title: ti.title.trim(),
        details: ti.details.trim(),
        dueDate: (ti.dueDate == null || ti.dueDate!.isEmpty)
            ? null
            : ti.dueDate,
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

    final alreadyRouted =
        h.status == "pending_manager" || h.status == "pending_hr";
    h.submittedAt ??= _now();
    if (!alreadyRouted) {
      h.lastReturn = null;
      h.managerApproval = null;
      h.hrApproval = null;
    }
    _audit(h, actor.id, "form_submitted", "${h.tasks.length}");
    for (final task in h.tasks) {
      if (task.status == "accepted") continue;
      task.status = "pending";
      final recipient = colleaguesFor(actor.id)
          .firstWhere((c) => c.id == task.assigneeId);
      _audit(
        h,
        actor.id,
        "task_assigned",
        "${task.title} → ${recipient.nameAr}",
      );
    }
    if (!alreadyRouted) _advanceIfAllAccepted(h);
    for (final task in h.tasks) {
      if (task.status != "pending") continue;
      final recipient = colleaguesFor(actor.id)
          .firstWhere((c) => c.id == task.assigneeId);
      _notifyRecipient(h, task, recipient, actor);
    }
    _notify(
      h,
      actor,
      "أرسلت الطلب ${h.number} | Request sent",
      "أرسلت الطلب وأُسندت المهام لزملائك.\nوش صار: إرسال الطلب.\nوين وصل: ${_where(h)}.",
    );
    notifyListeners();
  }

  void acceptTask(Employee actor, String id, String taskId, String note) {
    final h = handover(id) ?? (throw WorkflowException("notFound"));
    final task = _task(h, taskId);
    if (task == null ||
        task.assigneeId != actor.id ||
        task.status != "pending" ||
        !_openForTasks(h)) {
      throw WorkflowException("notAllowed");
    }
    task.status = "accepted";
    task.acceptedAt = _now();
    task.acceptNote = note.trim().isEmpty ? null : note.trim();
    _audit(h, actor.id, "task_accepted", task.title);
    _advanceIfAllAccepted(h);
    final owner = person(h.employee.id);
    if (owner != null) {
      _notify(
        h,
        owner,
        "قبل ${actor.nameAr} مهمة | Task accepted",
        "قبل ${actor.nameAr} المهمة \"${task.title}\".\nوش صار: قبول المهمة.\nوين وصل: ${_where(h)}.",
      );
    }
    notifyListeners();
  }

  void rejectTask(Employee actor, String id, String taskId, String comment) {
    if (comment.trim().isEmpty) throw WorkflowException("commentRequired");
    final h = handover(id) ?? (throw WorkflowException("notFound"));
    final task = _task(h, taskId);
    if (task == null ||
        task.assigneeId != actor.id ||
        task.status != "pending" ||
        !_openForTasks(h)) {
      throw WorkflowException("notAllowed");
    }
    final owner =
        person(h.employee.id) ?? (throw WorkflowException("notFound"));
    task.status = "rejected";
    task.rejections.add(
      TaskRejection(recipientId: actor.id, comment: comment.trim(), at: _now()),
    );
    _audit(h, actor.id, "task_rejected", "${task.title}: ${comment.trim()}");
    _notify(
      h,
      owner,
      "رفض ${actor.nameAr} استلام مهمة | ${actor.nameEn} declined a task",
      "رفض ${actor.nameAr} استلام المهمة \"${task.title}\".\nالسبب: ${comment.trim()}\nافتح النموذج واختر موظفاً آخر لهذه المهمة.\n\n${actor.nameEn} declined \"${task.title}\". Reason: ${comment.trim()}\nOpen the form and pick another employee.",
    );
    notifyListeners();
  }

  void reassignTask(
    Employee actor,
    String id,
    String taskId,
    String newAssigneeId,
  ) {
    final h = handover(id) ?? (throw WorkflowException("notFound"));
    if (!_owns(actor, h) || !_openForTasks(h))
      throw WorkflowException("notAllowed");
    final task = _task(h, taskId);
    if (task == null || task.status != "rejected")
      throw WorkflowException("notAllowed");
    if (task.rejections.any((r) => r.recipientId == newAssigneeId))
      throw WorkflowException("sameAssignee");
    Employee? recipient;
    for (final c in colleaguesFor(actor.id)) {
      if (c.id == newAssigneeId) recipient = c;
    }
    if (recipient == null) throw WorkflowException("assigneeRequired");
    task.assigneeId = newAssigneeId;
    task.status = "pending";
    _audit(
      h,
      actor.id,
      "task_reassigned",
      "${task.title} → ${recipient.nameAr}",
    );
    _notifyRecipient(h, task, recipient, actor);
    notifyListeners();
  }

  void managerDecision(
    Employee actor,
    String id,
    bool approve,
    String comment,
  ) {
    if (!approve && comment.trim().isEmpty)
      throw WorkflowException("commentRequired");
    final h = handover(id) ?? (throw WorkflowException("notFound"));
    if (_owns(actor, h)) throw WorkflowException("notAllowed");
    if (h.status != "pending_manager" || h.employee.managerId != actor.id)
      throw WorkflowException("notAllowed");
    final owner =
        person(h.employee.id) ?? (throw WorkflowException("notFound"));
    if (approve) {
      h.managerApproval = Approval(
        byId: actor.id,
        at: _now(),
        comment: comment.trim().isEmpty ? null : comment.trim(),
      );
      _audit(h, actor.id, "manager_approved", comment.trim());
      _moveToHr(h);
      _notify(
        h,
        owner,
        "اعتمد مديرك الطلب ${h.number} | Manager approved",
        "اعتمد ${actor.nameAr} الطلب.\nوش صار: اعتماد المدير المباشر.\nوين وصل: ${_where(h)}.",
      );
    } else {
      _returnToEmployee(h, owner, actor, "manager", comment.trim());
    }
    notifyListeners();
  }

  void hrDecision(Employee actor, String id, bool approve, String comment) {
    if (!actor.isHr) throw WorkflowException("notAllowed");
    if (!approve && comment.trim().isEmpty)
      throw WorkflowException("commentRequired");
    final h = handover(id) ?? (throw WorkflowException("notFound"));
    if (_owns(actor, h)) throw WorkflowException("notAllowed");
    if (h.status != "pending_hr") throw WorkflowException("notAllowed");
    final owner =
        person(h.employee.id) ?? (throw WorkflowException("notFound"));
    if (!approve) {
      _returnToEmployee(h, owner, actor, "hr", comment.trim());
      notifyListeners();
      return;
    }
    h.hrApproval = Approval(
      byId: actor.id,
      at: _now(),
      comment: comment.trim().isEmpty ? null : comment.trim(),
    );
    h.status = "approved";
    h.finalizedAt = _now();
    h.documentHash = sha256
        .convert(utf8.encode(jsonEncode(_canonical(h))))
        .toString();
    _audit(h, actor.id, "hr_approved", comment.trim());
    _audit(h, "system", "document_generated", h.documentHash!.substring(0, 16));
    final taskLines = h.tasks
        .map(
          (task) =>
              "- ${task.title}${task.details.isEmpty ? "" : "\n  ${task.details}"}",
        )
        .join("\n");
    _notify(
      h,
      owner,
      "اعتمدت الموارد البشرية طلبك ${h.number} | HR approved",
      "اعتمدت الموارد البشرية الطلب وأُغلق.\nوش صار: اعتماد نهائي وإصدار التقرير.\nوين وصل: ${_where(h)}.\nالمهام:\n$taskLines",
    );
    final manager = person(h.employee.managerId);
    if (manager != null && manager.id != owner.id) {
      _notify(
        h,
        manager,
        "أُغلق طلب ${h.employee.nameAr} ${h.number} | Request closed",
        "اعتمدت الموارد البشرية طلب ${h.employee.nameAr} وأُغلق.\nوش صار: اعتماد نهائي.\nوين وصل: ${_where(h)}.\nالمهام:\n$taskLines",
      );
    }
    h.hrmsDocumentId = "MENA-${h.number}";
    _audit(h, "system", "document_uploaded", h.hrmsDocumentId!);
    notifyListeners();
  }

  void _notifyRecipient(
    Handover h,
    HandoverTask task,
    Employee recipient,
    Employee from,
  ) {
    _notify(
      h,
      recipient,
      "${from.nameAr} أسند لك مهام، ادخل للموافقة",
      "${from.nameAr} أسند لك مهمة وتحتاج موافقتك.\nوش صار: إسناد مهمة.\nالمهمة: ${task.title}${task.details.isNotEmpty ? "\nالتفاصيل: ${task.details}" : ""}\nوين وصل: ${_where(h)}.\nادخل بحسابك واقبل المهمة أو ارفضها.\n\n${from.nameEn} assigned you a task: ${task.title}",
    );
  }

  bool _openForTasks(Handover h) =>
      h.status == "pending_acceptance" ||
      h.status == "pending_manager" ||
      h.status == "pending_hr" ||
      h.status == "draft" ||
      h.status == "returned";

  void _advanceIfAllAccepted(Handover h) {
    if (h.status == "pending_manager" ||
        h.status == "pending_hr" ||
        h.status == "approved") {
      return;
    }
    if (h.tasks.isEmpty || h.tasks.every((t) => t.status == "accepted")) {
      _sendToManagerOrHr(h);
      return;
    }
    h.status = "pending_acceptance";
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

  void _returnToEmployee(
    Handover h,
    Employee owner,
    Employee actor,
    String stage,
    String comment,
  ) {
    h.status = "returned";
    h.lastReturn = ReturnInfo(
      stage: stage,
      byId: actor.id,
      comment: comment,
      at: _now(),
    );
    _audit(
      h,
      actor.id,
      stage == "manager" ? "manager_rejected" : "hr_rejected",
      comment,
    );
    _notify(
      h,
      owner,
      "أُعيد نموذج التسليم ${h.number} للتعديل | Handover returned for correction",
      "أعاد ${actor.nameAr} نموذج التسليم إليك.\nالسبب: $comment\nعدّل النموذج وأعد إرساله.\n\n${actor.nameEn} returned your handover form. Reason: $comment",
    );
  }

  void _notifyHr(Handover h, String subject, String extra) {
    for (final person in hrUsers) {
      if (person.id == h.initiatedById) continue;
      _notify(h, person, subject, extra);
    }
  }

  String _where(Handover h) => switch (h.status) {
    "draft" => "مسودة عند الموظف",
    "pending_acceptance" => "بانتظار قبول المهام",
    "pending_manager" => "عند المدير المباشر",
    "pending_hr" => "عند الموارد البشرية",
    "returned" => "راجع للموظف للتعديل",
    "approved" => "معتمد ومغلق",
    _ => h.status,
  };

  String _requestBlock(Handover h) {
    final back = (h.returnDate == null || h.returnDate!.isEmpty)
        ? "غير محدد"
        : h.returnDate!;
    return [
      "رقم الطلب: ${h.number}",
      "نوع الطلب: ${exitReasonAr(h.type)}",
      "الموظف: ${h.employee.nameAr}",
      "القسم: ${h.employee.departmentAr}",
      "آخر يوم عمل: ${h.lastWorkingDay}",
      "تاريخ العودة: $back",
      "وين وصل الطلب: ${_where(h)}",
    ].join("\n");
  }

  void _notify(Handover h, Employee to, String subject, String body) {
    final full = "${_requestBlock(h)}\n\n$body\n\nافتح الموقع:\n$siteUrl";
    outbox.add(
      EmailMessage(
        id: _id(),
        to: to.email,
        toEmployeeId: to.id,
        subject: subject,
        body: full,
        link: "/handovers/${h.id}",
        at: _now(),
        kind: "workflow",
      ),
    );
    if (outbox.length > 100) outbox.removeRange(0, outbox.length - 100);
    WorkflowMail.send(to: to.email, subject: subject, body: full);
  }

  void _audit(
    Handover h,
    String actorId,
    String action, [
    String details = "",
  ]) {
    auditLog.add(
      AuditEntry(
        id: _id(),
        handoverId: h.id,
        at: _now(),
        actorId: actorId,
        action: action,
        details: details,
      ),
    );
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
        : {
            "byId": h.managerApproval!.byId,
            "at": h.managerApproval!.at,
            "comment": h.managerApproval!.comment,
          },
    "hrApproval": h.hrApproval == null
        ? null
        : {
            "byId": h.hrApproval!.byId,
            "at": h.hrApproval!.at,
            "comment": h.hrApproval!.comment,
          },
    "finalizedAt": h.finalizedAt,
  };

  Map<String, dynamic> snapshot() => {
    "counter": counter,
    "accounts": [for (final e in accounts) employeeToJson(e)],
    "handovers": [for (final h in handovers) handoverToJson(h)],
    "outbox": [for (final m in outbox) mailToJson(m)],
    "audit": [for (final a in auditLog) auditToJson(a)],
  };

  void startSharedSync() {
    if (!kIsWeb) return;
    syncShared();
    Timer.periodic(const Duration(seconds: 8), (_) => syncShared());
  }

  Future<void> syncShared() async {
    if (!kIsWeb) return;
    if (_syncing) {
      _syncQueued = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncQueued = false;
        await _exchange();
      } while (_syncQueued);
    } catch (_) {
    } finally {
      _syncing = false;
      if (_syncQueued) {
        _syncQueued = false;
        syncShared();
      }
    }
  }

  Future<void> _exchange() async {
    final remote = await _shared.fetch();
    if (remote == null) return;
    final local = snapshot();
    var merged = mergeSharedState(local, remote);
    if (stateFingerprint(merged) != stateFingerprint(remote)) {
      final written = await _writeUnion(merged);
      if (written == null) return;
      merged = written;
    }
    final now = snapshot();
    final safe = mergeSharedState(now, merged);
    if (stateFingerprint(now) != stateFingerprint(local) ||
        stateFingerprint(safe) != stateFingerprint(merged)) {
      _syncQueued = true;
    }
    if (stateFingerprint(safe) != stateFingerprint(now)) {
      replaceShared(safe);
    }
  }

  /// Write the union, then read it back. If another device saved in between,
  /// put the combined copy back so a new request is not deleted.
  Future<Map<String, dynamic>?> _writeUnion(Map<String, dynamic> merged) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final latest = await _shared.fetch();
      if (latest == null) return null;
      merged = mergeSharedState(snapshot(), latest);
      if (stateFingerprint(merged) == stateFingerprint(latest)) return merged;
      if (!await _shared.save(merged)) return null;
      final confirm = await _shared.fetch();
      if (confirm == null) return merged;
      final recovered = mergeSharedState(merged, confirm);
      if (stateFingerprint(recovered) == stateFingerprint(confirm)) {
        return recovered;
      }
      merged = recovered;
    }
    if (!await _shared.save(merged)) return null;
    return merged;
  }

  void replaceShared(Map<String, dynamic> state) {
    final keepUser = user?.id;
    final keepEmail = user?.email;
    final keepLocale = locale;
    final combined = mergeSharedState(snapshot(), state);
    _applyShared(combined, keepUser: keepUser, keepEmail: keepEmail);
    locale = keepLocale;
  }

  void _applyShared(
    Map<String, dynamic> state, {
    String? keepUser,
    String? keepEmail,
  }) {
    _hydrating = true;
    counter = (state["counter"] as num?)?.toInt() ?? counter;
    accounts = [
      for (final item in state["accounts"] as List)
        if (item is Map) employeeFromJson(Map<String, dynamic>.from(item)),
    ];
    handovers
      ..clear()
      ..addAll([
        for (final item in state["handovers"] as List)
          if (item is Map) handoverFromJson(Map<String, dynamic>.from(item)),
      ]);
    outbox
      ..clear()
      ..addAll([
        for (final item in state["outbox"] as List)
          if (item is Map) mailFromJson(Map<String, dynamic>.from(item)),
      ]);
    auditLog
      ..clear()
      ..addAll([
        for (final item in state["audit"] as List)
          if (item is Map) auditFromJson(Map<String, dynamic>.from(item)),
      ]);
    _repairOwners();
    user = person(keepUser) ?? findByEmail(keepEmail ?? "");
    _hydrating = false;
    notifyListeners();
  }

  /// A form can outlive the account row when the same email is registered twice.
  /// Put that owner back so the open form does not turn into "not found".
  void _repairOwners() {
    for (final h in handovers) {
      if (person(h.employee.id) != null) continue;
      String? email;
      for (final message in outbox) {
        if (message.toEmployeeId == h.employee.id && message.to.contains("@")) {
          email = message.to.trim().toLowerCase();
          break;
        }
      }
      if (email == null || email.isEmpty) continue;
      final dept = h.employee.departmentAr.contains("موارد")
          ? hrDept
          : h.employee.departmentAr.contains("استقطاب")
          ? talent
          : itDev;
      accounts.add(
        Employee(
          id: h.employee.id,
          staffNumber: h.employee.id,
          nameAr: h.employee.nameAr,
          nameEn: h.employee.nameEn,
          jobTitleAr: h.employee.jobTitleAr,
          jobTitleEn: h.employee.jobTitleEn,
          departmentId: dept["departmentId"]!,
          departmentAr: h.employee.departmentAr.isEmpty
              ? dept["departmentAr"]!
              : h.employee.departmentAr,
          departmentEn: h.employee.departmentEn.isEmpty
              ? dept["departmentEn"]!
              : h.employee.departmentEn,
          sectionAr: h.employee.sectionAr.isEmpty
              ? dept["sectionAr"]!
              : h.employee.sectionAr,
          sectionEn: h.employee.sectionEn.isEmpty
              ? dept["sectionEn"]!
              : h.employee.sectionEn,
          branchId: "B-RUH",
          managerId: h.employee.managerId,
          email: email,
          role: dept["departmentId"] == "D-HR" ? "hr" : "employee",
        ),
      );
    }
  }

  void _persist() {
    try {
      _box.write(
        _storageKey,
        jsonEncode({
          "userId": user?.id,
          "userEmail": user?.email,
          "locale": locale,
          "counter": counter,
          ...snapshot(),
        }),
      );
    } catch (_) {}
    if (!kIsWeb || _hydrating) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 500), syncShared);
  }

  void _load() {
    final raw = _box.read(_storageKey);
    if (raw == null || raw.isEmpty) return;
    _hydrating = true;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      counter = (data["counter"] as num?)?.toInt() ?? 0;
      final savedLocale = data["locale"];
      if (savedLocale is String &&
          (savedLocale == "ar" || savedLocale == "en")) {
        locale = savedLocale;
      }
      accounts = [
        for (final item in data["accounts"] as List? ?? const [])
          if (item is Map) employeeFromJson(item.cast<String, dynamic>()),
      ];
      for (final item in data["handovers"] as List? ?? const []) {
        if (item is Map)
          handovers.add(handoverFromJson(item.cast<String, dynamic>()));
      }
      for (final item in data["outbox"] as List? ?? const []) {
        if (item is Map) outbox.add(mailFromJson(item.cast<String, dynamic>()));
      }
      for (final item in data["audit"] as List? ?? const []) {
        if (item is Map)
          auditLog.add(auditFromJson(item.cast<String, dynamic>()));
      }
      _repairOwners();
      user =
          person(data["userId"] as String?) ??
          findByEmail("${data["userEmail"] ?? ""}");
    } catch (_) {
      accounts = [];
      handovers.clear();
      outbox.clear();
      auditLog.clear();
      user = null;
    } finally {
      _hydrating = false;
    }
  }
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
