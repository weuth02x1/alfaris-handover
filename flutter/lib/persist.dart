import "models.dart";

Map<String, Object?> employeeToJson(Employee e) => {
  "id": e.id,
  "nameAr": e.nameAr,
  "nameEn": e.nameEn,
  "jobTitleAr": e.jobTitleAr,
  "jobTitleEn": e.jobTitleEn,
  "departmentId": e.departmentId,
  "departmentAr": e.departmentAr,
  "departmentEn": e.departmentEn,
  "sectionAr": e.sectionAr,
  "sectionEn": e.sectionEn,
  "branchId": e.branchId,
  "managerId": e.managerId,
  "email": e.email,
  "role": e.role,
  "staffNumber": e.staffNumber,
  "isManager": e.isManager,
  "managesDepartmentId": e.managesDepartmentId,
};

Employee employeeFromJson(Map<String, dynamic> m) => Employee(
  id: "${m["id"]}",
  nameAr: "${m["nameAr"] ?? ""}",
  nameEn: "${m["nameEn"] ?? ""}",
  jobTitleAr: "${m["jobTitleAr"] ?? ""}",
  jobTitleEn: "${m["jobTitleEn"] ?? ""}",
  departmentId: "${m["departmentId"] ?? ""}",
  departmentAr: "${m["departmentAr"] ?? ""}",
  departmentEn: "${m["departmentEn"] ?? ""}",
  sectionAr: "${m["sectionAr"] ?? ""}",
  sectionEn: "${m["sectionEn"] ?? ""}",
  branchId: "${m["branchId"] ?? "B-RUH"}",
  managerId: m["managerId"] as String?,
  email: "${m["email"] ?? ""}",
  role: "${m["role"] ?? "employee"}",
  staffNumber: m["staffNumber"] as String?,
  isManager: m["isManager"] == true,
  managesDepartmentId: m["managesDepartmentId"] as String?,
);

Map<String, Object?> handoverToJson(Handover h) => {
  "id": h.id,
  "number": h.number,
  "requestRef": h.requestRef,
  "type": h.type,
  "lastWorkingDay": h.lastWorkingDay,
  "returnDate": h.returnDate,
  "employee": {
    "id": h.employee.id,
    "nameAr": h.employee.nameAr,
    "nameEn": h.employee.nameEn,
    "jobTitleAr": h.employee.jobTitleAr,
    "jobTitleEn": h.employee.jobTitleEn,
    "departmentAr": h.employee.departmentAr,
    "departmentEn": h.employee.departmentEn,
    "sectionAr": h.employee.sectionAr,
    "sectionEn": h.employee.sectionEn,
    "managerId": h.employee.managerId,
    "managerNameAr": h.employee.managerNameAr,
    "managerNameEn": h.employee.managerNameEn,
  },
  "status": h.status,
  "generalNotes": h.generalNotes,
  "tasks": [
    for (final t in h.tasks)
      {
        "id": t.id,
        "title": t.title,
        "details": t.details,
        "dueDate": t.dueDate,
        "assigneeId": t.assigneeId,
        "status": t.status,
        "acceptedAt": t.acceptedAt,
        "acceptNote": t.acceptNote,
        "rejections": [
          for (final r in t.rejections)
            {"recipientId": r.recipientId, "comment": r.comment, "at": r.at},
        ],
      },
  ],
  "lastReturn": h.lastReturn == null
      ? null
      : {
          "stage": h.lastReturn!.stage,
          "byId": h.lastReturn!.byId,
          "comment": h.lastReturn!.comment,
          "at": h.lastReturn!.at,
        },
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
  "initiatedById": h.initiatedById,
  "createdAt": h.createdAt,
  "submittedAt": h.submittedAt,
  "finalizedAt": h.finalizedAt,
  "documentHash": h.documentHash,
  "hrmsDocumentId": h.hrmsDocumentId,
};

Handover handoverFromJson(Map<String, dynamic> m) {
  final employee = Map<String, dynamic>.from(m["employee"] as Map);
  final tasks = <HandoverTask>[];
  for (final item in m["tasks"] as List? ?? const []) {
    if (item is! Map) continue;
    final task = item.cast<String, dynamic>();
    tasks.add(
      HandoverTask(
        id: "${task["id"]}",
        title: "${task["title"] ?? ""}",
        details: "${task["details"] ?? ""}",
        dueDate: task["dueDate"] as String?,
        assigneeId: "${task["assigneeId"] ?? ""}",
        status: "${task["status"] ?? "draft"}",
        acceptedAt: task["acceptedAt"] as String?,
        acceptNote: task["acceptNote"] as String?,
        rejections: [
          for (final r in task["rejections"] as List? ?? const [])
            if (r is Map)
              TaskRejection(
                recipientId: "${r["recipientId"]}",
                comment: "${r["comment"] ?? ""}",
                at: "${r["at"] ?? ""}",
              ),
        ],
      ),
    );
  }
  ReturnInfo? lastReturn;
  if (m["lastReturn"] is Map) {
    final r = (m["lastReturn"] as Map).cast<String, dynamic>();
    lastReturn = ReturnInfo(
      stage: "${r["stage"]}",
      byId: "${r["byId"]}",
      comment: "${r["comment"] ?? ""}",
      at: "${r["at"] ?? ""}",
    );
  }
  Approval? approval(Object? raw) {
    if (raw is! Map) return null;
    final a = raw.cast<String, dynamic>();
    return Approval(
      byId: "${a["byId"]}",
      at: "${a["at"] ?? ""}",
      comment: a["comment"] as String?,
    );
  }

  return Handover(
    id: "${m["id"]}",
    number: "${m["number"]}",
    requestRef: "${m["requestRef"]}",
    type: "${m["type"]}",
    lastWorkingDay: "${m["lastWorkingDay"]}",
    returnDate: m["returnDate"] as String?,
    employee: EmployeeSnapshot(
      id: "${employee["id"]}",
      nameAr: "${employee["nameAr"] ?? ""}",
      nameEn: "${employee["nameEn"] ?? ""}",
      jobTitleAr: "${employee["jobTitleAr"] ?? ""}",
      jobTitleEn: "${employee["jobTitleEn"] ?? ""}",
      departmentAr: "${employee["departmentAr"] ?? ""}",
      departmentEn: "${employee["departmentEn"] ?? ""}",
      sectionAr: "${employee["sectionAr"] ?? ""}",
      sectionEn: "${employee["sectionEn"] ?? ""}",
      managerId: employee["managerId"] as String?,
      managerNameAr: "${employee["managerNameAr"] ?? ""}",
      managerNameEn: "${employee["managerNameEn"] ?? ""}",
    ),
    status: "${m["status"] ?? "draft"}",
    generalNotes: "${m["generalNotes"] ?? ""}",
    tasks: tasks,
    lastReturn: lastReturn,
    managerApproval: approval(m["managerApproval"]),
    hrApproval: approval(m["hrApproval"]),
    initiatedById: "${m["initiatedById"] ?? ""}",
    createdAt: "${m["createdAt"] ?? ""}",
    submittedAt: m["submittedAt"] as String?,
    finalizedAt: m["finalizedAt"] as String?,
    documentHash: m["documentHash"] as String?,
    hrmsDocumentId: m["hrmsDocumentId"] as String?,
  );
}

Map<String, Object?> mailToJson(EmailMessage m) => {
  "id": m.id,
  "to": m.to,
  "toEmployeeId": m.toEmployeeId,
  "subject": m.subject,
  "body": m.body,
  "link": m.link,
  "at": m.at,
  "kind": m.kind,
};

EmailMessage mailFromJson(Map<String, dynamic> m) => EmailMessage(
  id: "${m["id"]}",
  to: "${m["to"] ?? ""}",
  toEmployeeId: "${m["toEmployeeId"] ?? ""}",
  subject: "${m["subject"] ?? ""}",
  body: "${m["body"] ?? ""}",
  link: m["link"] as String?,
  at: "${m["at"] ?? ""}",
  kind: "${m["kind"] ?? "workflow"}",
);

Map<String, Object?> auditToJson(AuditEntry a) => {
  "id": a.id,
  "handoverId": a.handoverId,
  "at": a.at,
  "actorId": a.actorId,
  "action": a.action,
  "details": a.details,
};

AuditEntry auditFromJson(Map<String, dynamic> m) => AuditEntry(
  id: "${m["id"]}",
  handoverId: "${m["handoverId"] ?? ""}",
  at: "${m["at"] ?? ""}",
  actorId: "${m["actorId"] ?? ""}",
  action: "${m["action"] ?? ""}",
  details: "${m["details"] ?? ""}",
);
