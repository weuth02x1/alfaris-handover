using Alfaris.Handover.Models;

namespace Alfaris.Handover.Data;

public static class StaffDirectory
{
    public static readonly Dictionary<string, string> HrDept = new()
    {
        ["departmentId"] = "D-HR", ["departmentAr"] = "الموارد البشرية", ["departmentEn"] = "Human Resources",
        ["sectionAr"] = "شؤون الموظفين", ["sectionEn"] = "Personnel Affairs", ["branchId"] = "B-RUH"
    };
    public static readonly Dictionary<string, string> Talent = new()
    {
        ["departmentId"] = "D-TA", ["departmentAr"] = "استقطاب المواهب", ["departmentEn"] = "Talent Acquisition",
        ["sectionAr"] = "استقطاب المواهب", ["sectionEn"] = "Talent Acquisition", ["branchId"] = "B-RUH"
    };
    public static readonly Dictionary<string, string> ItDev = new()
    {
        ["departmentId"] = "D-ITD", ["departmentAr"] = "تطوير تقنية المعلومات", ["departmentEn"] = "IT Development",
        ["sectionAr"] = "تطوير الأنظمة", ["sectionEn"] = "Systems Development", ["branchId"] = "B-RUH"
    };

    public static readonly string[] ExitReasons = ["annual_leave", "clearance", "resignation", "transfer", "contract_end"];

    public static string DepartmentKey(Employee person)
    {
        var blob = $"{person.DepartmentId} {person.DepartmentAr} {person.DepartmentEn} {person.SectionAr} {person.SectionEn}".ToLowerInvariant();
        if (Hit(blob, "d-hr", "موارد", "شؤون الموظف", "human resource", "personnel")) return "D-HR";
        if (Hit(blob, "d-ta", "استقطاب", "مواهب", "talent")) return "D-TA";
        if (Hit(blob, "d-itd", "تقنية المعلومات", "تطوير الأنظمة", "تطوير تقنية", "information technology", "it development", "systems development")) return "D-ITD";
        return string.IsNullOrWhiteSpace(person.DepartmentId) ? blob : person.DepartmentId.Trim();
    }

    static bool Hit(string blob, params string[] words) => words.Any(blob.Contains);

    public static List<Employee> Seed() =>
    [
        E("30102", "منيرة السبيعي", "Munira Alsubaie", "مديرة الموارد البشرية", "HR Manager", HrDept, "munira.alsubaie@alfaris.example", "hr"),
        E("30115", "هند الغامدي", "Hind Alghamdi", "أخصائية موارد بشرية", "HR Specialist", HrDept, "hind.alghamdi@alfaris.example", "hr", "30102"),
        E("40210", "سلطان القحطاني", "Sultan Alqahtani", "مدير استقطاب المواهب", "Talent Acquisition Manager", Talent, "sultan.alqahtani@alfaris.example", "employee"),
        E("40221", "لمى الحربي", "Lama Alharbi", "أخصائية استقطاب مواهب", "Talent Acquisition Specialist", Talent, "lama.alharbi@alfaris.example", "employee", "40210"),
        E("40233", "فيصل الشمري", "Faisal Alshammari", "أخصائي استقطاب مواهب", "Talent Acquisition Specialist", Talent, "faisal.alshammari@alfaris.example", "employee", "40210"),
        E("10501", "فهد العتيبي", "Fahad Alotaibi", "مدير تطوير تقنية المعلومات", "IT Development Manager", ItDev, "fahad.alotaibi@alfaris.example", "employee", null, "إدارة التطوير", "Development Management"),
        E("10518", "سارة القحطاني", "Sarah Alqahtani", "مطورة أنظمة أولى", "Senior Systems Developer", ItDev, "sarah.alqahtani@alfaris.example", "employee", "10501"),
        E("10524", "خالد الشهري", "Khalid Alshehri", "مطور برمجيات", "Software Developer", ItDev, "khalid.alshehri@alfaris.example", "employee", "10501"),
        E("10530", "عبدالله الحربي", "Abdullah Alharbi", "مطور واجهات", "Frontend Developer", ItDev, "abdullah.alharbi@alfaris.example", "employee", "10501"),
        E("10540", "نورة الدوسري", "Noura Aldosari", "محللة أنظمة", "Systems Analyst", new Dictionary<string, string>
        {
            ["departmentId"] = "IT-SYS", ["departmentAr"] = "إدارة تقنية المعلومات", ["departmentEn"] = "Information Technology",
            ["sectionAr"] = "تحليل الأنظمة", ["sectionEn"] = "Systems Analysis", ["branchId"] = "B-RUH"
        }, "noura.aldosari@alfaris.example", "employee", "10501"),
    ];

    public static readonly ApprovedRequest[] ApprovedRequests =
    [
        new("ANN-2026-0412", "10518", "annual_leave", "2026-12-01", "2026-12-28"),
        new("CLR-2026-0087", "10524", "clearance", "2026-12-15", null),
        new("ANN-2026-0419", "40221", "annual_leave", "2026-12-05", "2026-12-19"),
        new("RES-2026-0014", "40233", "resignation", "2026-12-31", null),
    ];

    static Employee E(string id, string nameAr, string nameEn, string jobAr, string jobEn, Dictionary<string, string> dept, string email, string role, string? managerId = null, string? sectionAr = null, string? sectionEn = null) =>
        new(id, nameAr, nameEn, jobAr, jobEn, dept["departmentId"], dept["departmentAr"], dept["departmentEn"], sectionAr ?? dept["sectionAr"], sectionEn ?? dept["sectionEn"], dept["branchId"], email, role, managerId);
}
