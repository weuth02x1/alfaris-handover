import "models.dart";

const hrId = "D-HR";
const hrName = "الموارد البشرية";
const talentId = "D-TA";
const talentName = "استقطاب المواهب";
const itDevId = "D-ITD";
const itDevName = "تطوير تقنية المعلومات";

const employees = <Employee>[
  Employee(
    id: "30102",
    nameAr: "منيرة السبيعي",
    jobTitleAr: "مديرة الموارد البشرية",
    departmentId: hrId,
    departmentAr: hrName,
    email: "munira.alsubaie@alfaris.example",
    role: Role.hr,
  ),
  Employee(
    id: "30115",
    nameAr: "هند الغامدي",
    jobTitleAr: "أخصائية موارد بشرية",
    departmentId: hrId,
    departmentAr: hrName,
    email: "hind.alghamdi@alfaris.example",
    role: Role.hr,
    managerId: "30102",
  ),
  Employee(
    id: "40210",
    nameAr: "سلطان القحطاني",
    jobTitleAr: "مدير استقطاب المواهب",
    departmentId: talentId,
    departmentAr: talentName,
    email: "sultan.alqahtani@alfaris.example",
    role: Role.employee,
  ),
  Employee(
    id: "40221",
    nameAr: "لمى الحربي",
    jobTitleAr: "أخصائية استقطاب مواهب",
    departmentId: talentId,
    departmentAr: talentName,
    email: "lama.alharbi@alfaris.example",
    role: Role.employee,
    managerId: "40210",
  ),
  Employee(
    id: "40233",
    nameAr: "فيصل الشمري",
    jobTitleAr: "أخصائي استقطاب مواهب",
    departmentId: talentId,
    departmentAr: talentName,
    email: "faisal.alshammari@alfaris.example",
    role: Role.employee,
    managerId: "40210",
  ),
  Employee(
    id: "10501",
    nameAr: "فهد العتيبي",
    jobTitleAr: "مدير تطوير تقنية المعلومات",
    departmentId: itDevId,
    departmentAr: itDevName,
    email: "fahad.alotaibi@alfaris.example",
    role: Role.employee,
  ),
  Employee(
    id: "10518",
    nameAr: "سارة القحطاني",
    jobTitleAr: "مطورة أنظمة أولى",
    departmentId: itDevId,
    departmentAr: itDevName,
    email: "sarah.alqahtani@alfaris.example",
    role: Role.employee,
    managerId: "10501",
  ),
  Employee(
    id: "10524",
    nameAr: "خالد الشهري",
    jobTitleAr: "مطور برمجيات",
    departmentId: itDevId,
    departmentAr: itDevName,
    email: "khalid.alshehri@alfaris.example",
    role: Role.employee,
    managerId: "10501",
  ),
  Employee(
    id: "10530",
    nameAr: "عبدالله الحربي",
    jobTitleAr: "مطور واجهات",
    departmentId: itDevId,
    departmentAr: itDevName,
    email: "abdullah.alharbi@alfaris.example",
    role: Role.employee,
    managerId: "10501",
  ),
];

const approvedRequests = <ApprovedRequest>[
  ApprovedRequest(ref: "ANN-2026-0412", employeeId: "10518", type: ExitReason.annualLeave, startDate: "2026-12-01"),
  ApprovedRequest(ref: "CLR-2026-0087", employeeId: "10524", type: ExitReason.clearance, startDate: "2026-12-15"),
  ApprovedRequest(ref: "ANN-2026-0419", employeeId: "40221", type: ExitReason.annualLeave, startDate: "2026-12-05"),
  ApprovedRequest(ref: "RES-2026-0014", employeeId: "40233", type: ExitReason.resignation, startDate: "2026-12-31"),
];

Employee? byId(String id) {
  for (final person in employees) {
    if (person.id == id) return person;
  }
  return null;
}

Employee? byEmail(String email) {
  final target = email.trim().toLowerCase();
  for (final person in employees) {
    if (person.email == target) return person;
  }
  return null;
}
