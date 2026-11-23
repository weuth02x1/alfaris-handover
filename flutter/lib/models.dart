class Employee {
  Employee({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.jobTitleAr,
    required this.jobTitleEn,
    required this.departmentId,
    required this.departmentAr,
    required this.departmentEn,
    required this.sectionAr,
    required this.sectionEn,
    required this.branchId,
    required this.email,
    required this.role,
    this.managerId,
    this.staffNumber,
    this.isManager = false,
    this.managesDepartmentId,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String jobTitleAr;
  final String jobTitleEn;
  final String departmentId;
  final String departmentAr;
  final String departmentEn;
  final String sectionAr;
  final String sectionEn;
  final String branchId;
  final String? managerId;
  final String email;
  final String role;
  final String? staffNumber;
  final bool isManager;
  final String? managesDepartmentId;

  String get displayId => staffNumber ?? id;
  bool get isHr => role == "hr";
}

class ApprovedRequest {
  const ApprovedRequest({
    required this.ref,
    required this.employeeId,
    required this.type,
    required this.startDate,
    this.endDate,
  });

  final String ref;
  final String employeeId;
  final String type;
  final String startDate;
  final String? endDate;
}

class TaskRejection {
  TaskRejection({
    required this.recipientId,
    required this.comment,
    required this.at,
  });
  final String recipientId;
  final String comment;
  final String at;
}

class HandoverTask {
  HandoverTask({
    required this.id,
    required this.title,
    required this.details,
    required this.assigneeId,
    required this.status,
    this.dueDate,
    this.acceptedAt,
    this.acceptNote,
    List<TaskRejection>? rejections,
  }) : rejections = rejections ?? [];

  String id;
  String title;
  String details;
  String? dueDate;
  String assigneeId;
  String status;
  String? acceptedAt;
  String? acceptNote;
  List<TaskRejection> rejections;
}

class EmployeeSnapshot {
  EmployeeSnapshot({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.jobTitleAr,
    required this.jobTitleEn,
    required this.departmentAr,
    required this.departmentEn,
    required this.sectionAr,
    required this.sectionEn,
    required this.managerNameAr,
    required this.managerNameEn,
    this.managerId,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String jobTitleAr;
  final String jobTitleEn;
  final String departmentAr;
  final String departmentEn;
  final String sectionAr;
  final String sectionEn;
  final String? managerId;
  final String managerNameAr;
  final String managerNameEn;
}

class ReturnInfo {
  ReturnInfo({
    required this.stage,
    required this.byId,
    required this.comment,
    required this.at,
  });
  final String stage;
  final String byId;
  final String comment;
  final String at;
}

class Approval {
  Approval({required this.byId, required this.at, this.comment});
  final String byId;
  final String at;
  final String? comment;
}

class Handover {
  Handover({
    required this.id,
    required this.number,
    required this.requestRef,
    required this.type,
    required this.lastWorkingDay,
    required this.employee,
    required this.status,
    required this.initiatedById,
    required this.createdAt,
    this.returnDate,
    this.generalNotes = "",
    List<HandoverTask>? tasks,
    this.lastReturn,
    this.managerApproval,
    this.hrApproval,
    this.submittedAt,
    this.finalizedAt,
    this.documentHash,
    this.hrmsDocumentId,
  }) : tasks = tasks ?? [];

  final String id;
  final String number;
  final String requestRef;
  String type;
  String lastWorkingDay;
  String? returnDate;
  final EmployeeSnapshot employee;
  String status;
  String generalNotes;
  List<HandoverTask> tasks;
  ReturnInfo? lastReturn;
  Approval? managerApproval;
  Approval? hrApproval;
  final String initiatedById;
  final String createdAt;
  String? submittedAt;
  String? finalizedAt;
  String? documentHash;
  String? hrmsDocumentId;
}

class AuditEntry {
  AuditEntry({
    required this.id,
    required this.handoverId,
    required this.at,
    required this.actorId,
    required this.action,
    this.details = "",
  });

  final String id;
  final String handoverId;
  final String at;
  final String actorId;
  final String action;
  final String details;
}

class EmailMessage {
  EmailMessage({
    required this.id,
    required this.to,
    required this.toEmployeeId,
    required this.subject,
    required this.body,
    required this.at,
    required this.kind,
    this.link,
    this.otpCode,
  });

  final String id;
  final String to;
  final String toEmployeeId;
  final String subject;
  final String body;
  final String? link;
  final String at;
  final String kind;
  final String? otpCode;
}

class OtpChallenge {
  OtpChallenge({
    required this.employeeId,
    required this.email,
    required this.code,
    required this.expiresAt,
  });

  final String employeeId;
  final String email;
  final String code;
  final String expiresAt;
}

class WorkflowException implements Exception {
  WorkflowException(this.code);
  final String code;
  @override
  String toString() => code;
}
