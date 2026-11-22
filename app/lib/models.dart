enum Role { employee, hr }

enum ExitReason { annualLeave, clearance, resignation, transfer, contractEnd }

enum HandoverStatus { draft, pendingAcceptance, pendingManager, pendingHr, returned, approved }

enum TaskStatus { draft, pending, accepted, rejected }

class Employee {
  const Employee({
    required this.id,
    required this.nameAr,
    required this.jobTitleAr,
    required this.departmentId,
    required this.departmentAr,
    required this.email,
    required this.role,
    this.managerId,
  });

  final String id;
  final String nameAr;
  final String jobTitleAr;
  final String departmentId;
  final String departmentAr;
  final String email;
  final Role role;
  final String? managerId;
}

class ApprovedRequest {
  const ApprovedRequest({
    required this.ref,
    required this.employeeId,
    required this.type,
    required this.startDate,
  });

  final String ref;
  final String employeeId;
  final ExitReason type;
  final String startDate;
}

class HandoverTask {
  HandoverTask({
    required this.id,
    required this.title,
    required this.details,
    required this.assigneeId,
    this.status = TaskStatus.draft,
    this.rejectComment = "",
  });

  final String id;
  String title;
  String details;
  String assigneeId;
  TaskStatus status;
  String rejectComment;
}

class Handover {
  Handover({
    required this.id,
    required this.number,
    required this.requestRef,
    required this.type,
    required this.employeeId,
    required this.status,
    required this.createdAt,
    this.generalNotes = "",
    List<HandoverTask>? tasks,
    this.returnComment,
  });

  final String id;
  final String number;
  final String requestRef;
  final ExitReason type;
  final String employeeId;
  HandoverStatus status;
  final DateTime createdAt;
  String generalNotes;
  final List<HandoverTask> tasks = [];
  String? returnComment;
}

String reasonLabel(ExitReason reason) {
  return switch (reason) {
    ExitReason.annualLeave => "إجازة سنوية",
    ExitReason.clearance => "إخلاء طرف",
    ExitReason.resignation => "استقالة",
    ExitReason.transfer => "نقل",
    ExitReason.contractEnd => "انتهاء العقد",
  };
}

String statusLabel(HandoverStatus status) {
  return switch (status) {
    HandoverStatus.draft => "مسودة",
    HandoverStatus.pendingAcceptance => "بانتظار قبول المهام",
    HandoverStatus.pendingManager => "بانتظار المدير",
    HandoverStatus.pendingHr => "بانتظار الموارد البشرية",
    HandoverStatus.returned => "مُعاد للتعديل",
    HandoverStatus.approved => "معتمد",
  };
}
