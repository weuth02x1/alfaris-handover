import "models.dart";

const hrDept = {
  "departmentId": "D-HR",
  "departmentAr": "الموارد البشرية",
  "departmentEn": "Human Resources",
  "sectionAr": "شؤون الموظفين",
  "sectionEn": "Personnel Affairs",
  "branchId": "B-RUH",
};
const talent = {
  "departmentId": "D-TA",
  "departmentAr": "استقطاب المواهب",
  "departmentEn": "Talent Acquisition",
  "sectionAr": "استقطاب المواهب",
  "sectionEn": "Talent Acquisition",
  "branchId": "B-RUH",
};
const itDev = {
  "departmentId": "D-ITD",
  "departmentAr": "تطوير تقنية المعلومات",
  "departmentEn": "IT Development",
  "sectionAr": "تطوير الأنظمة",
  "sectionEn": "Systems Development",
  "branchId": "B-RUH",
};

Map<String, String>? departmentById(String id) => switch (id) {
  "D-HR" => hrDept,
  "D-TA" => talent,
  "D-ITD" => itDev,
  _ => null,
};

const exitReasons = [
  "annual_leave",
  "clearance",
  "resignation",
  "transfer",
  "contract_end",
];

String exitReasonAr(String key) => switch (key) {
  "annual_leave" => "إجازة سنوية",
  "clearance" => "إخلاء طرف",
  "resignation" => "استقالة",
  "transfer" => "نقل",
  "contract_end" => "انتهاء العقد",
  _ => key,
};

/// Same workplace unit even when the Arabic or English label differs.
String departmentKey(Employee person) {
  final blob =
      "${person.departmentId} ${person.departmentAr} ${person.departmentEn} ${person.sectionAr} ${person.sectionEn}"
          .toLowerCase();
  const hr = ["d-hr", "موارد", "شؤون الموظف", "human resource", "personnel"];
  const talent = ["d-ta", "استقطاب", "مواهب", "talent"];
  const it = [
    "d-itd",
    "تقنية المعلومات",
    "تطوير الأنظمة",
    "تطوير تقنية",
    "information technology",
    "it development",
    "systems development",
  ];
  bool hit(List<String> words) => words.any(blob.contains);
  if (hit(hr)) return "D-HR";
  if (hit(talent)) return "D-TA";
  if (hit(it)) return "D-ITD";
  final id = person.departmentId.trim();
  return id.isEmpty ? blob : id;
}
