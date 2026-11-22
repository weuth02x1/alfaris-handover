using System.Globalization;

namespace Alfaris.Handover.Services;

public class LocaleService
{
    public string Locale { get; set; } = "ar";
    public bool IsAr => Locale == "ar";
    public string Dir => IsAr ? "rtl" : "ltr";
    public string Pick(string ar, string en) => IsAr ? ar : en;

    public string Date(string? iso, bool withTime = false)
    {
        if (string.IsNullOrWhiteSpace(iso)) return Dash;
        var raw = iso.Length == 10 ? iso + "T00:00:00" : iso;
        if (!DateTime.TryParse(raw, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var d)) return iso;
        var local = d.Kind == DateTimeKind.Utc ? d.AddHours(3) : DateTime.SpecifyKind(d, DateTimeKind.Utc).AddHours(3);
        return withTime ? local.ToString("yyyy-MM-dd HH:mm") : local.ToString("yyyy-MM-dd");
    }

    public string AppName => Pick("نظام تسليم العهد والمهام", "Employee Handover");
    public string AppTagline => Pick("أتمتة إيصال تسليم المهام عند الإجازة أو إنهاء الخدمة", "Automated handover receipts for vacation and termination clearance");
    public string NavInbox => Pick("مهامي", "My work");
    public string NavHr => Pick("لوحة الموارد البشرية", "HR console");
    public string NavOutbox => Pick("صندوق البريد", "Mail outbox");
    public string NavLogout => Pick("تسجيل الخروج", "Sign out");
    public string NavLanguage => Pick("English", "العربية");
    public string LoginTitle => Pick("تسجيل الدخول", "Sign in");
    public string LoginSubtitle => Pick("أدخل إيميلك. نرسل رمز الدخول إلى صندوق الوارد عبر بريد المجموعة.", "Enter your email. We send the sign-in code to that inbox through company mail.");
    public string Email => Pick("الإيميل", "Email");
    public string SendCode => Pick("أرسل الرمز على الإيميل", "Email me the code");
    public string CodeSent => Pick("أرسلنا رمز الدخول إلى إيميلك.", "We emailed the sign-in code.");
    public string CheckInbox => Pick("افتح الإيميل واكتب الرمز المكوّن من 6 أرقام. شيك غير المرغوب إذا تأخر.", "Open the email and type the 6-digit code. Check spam if it is slow.");
    public string Code => Pick("رمز الدخول", "Sign-in code");
    public string Confirm => Pick("دخول", "Sign in");
    public string Resend => Pick("إرسال رمز جديد", "Send a new code");
    public string MailFailed => Pick("ما قدرنا نرسل الرمز إلى هذا الإيميل. حاول مرة ثانية.", "We could not send the code to that email. Try again.");
    public string CreateAccount => Pick("ما عندك حساب؟ أنشئ حساباً", "No account yet? Create one");
    public string HaveAccount => Pick("عندك حساب؟ سجّل الدخول", "Already have an account? Sign in");
    public string SignupTitle => Pick("إنشاء حساب", "Create an account");
    public string SignupHint => Pick("الحساب يتفعل لما يوصلك الرمز على إيميلك وتكتبه هنا.", "The account activates when the code arrives in your email and you type it here.");
    public string Name => Pick("الاسم", "Name");
    public string EmployeeNo => Pick("الرقم الوظيفي", "Employee number");
    public string JobTitle => Pick("المسمى الوظيفي", "Job title");
    public string Department => Pick("القسم", "Department");
    public string DeptHr => Pick("الموارد البشرية", "Human Resources");
    public string DeptTalent => Pick("استقطاب المواهب", "Talent Acquisition");
    public string DeptIt => Pick("تطوير تقنية المعلومات", "IT Development");
    public string CreateAndSend => Pick("إنشاء الحساب وإرسال الرمز", "Create account and email the code");
    public string InboxTitle => Pick("المطلوب منك", "Waiting on you");
    public string InboxSubtitle => Pick("كل ما ينتظر إجراءك في دورة تسليم المهام.", "Everything that needs your action in the handover cycle.");
    public string MyHandovers => Pick("نماذج التسليم الخاصة بي", "My handover forms");
    public string TasksToAccept => Pick("مهام مُسندة إليك بانتظار قبولك", "Tasks assigned to you, waiting for your acceptance");
    public string ManagerQueue => Pick("نماذج بانتظار اعتمادك كمدير مباشر", "Waiting for your approval as direct manager");
    public string HrQueue => Pick("نماذج بانتظار اعتماد الموارد البشرية", "Waiting for HR approval");
    public string AcceptedByMe => Pick("مهام استلمتها", "Tasks I took over");
    public string Nothing => Pick("لا يوجد شيء بانتظارك حالياً.", "Nothing is waiting on you right now.");
    public string NothingHint => Pick("ستصلك رسالة بريد عند إسناد مهمة لك أو طلب اعتمادك.", "You will get an email when a task is assigned to you or your approval is needed.");
    public string Open => Pick("فتح", "Open");
    public string From => Pick("من", "From");
    public string HrTitle => Pick("لوحة الموارد البشرية", "HR console");
    public string HrSubtitle => Pick("ابدأ إخلاء الطرف للطلبات المعتمدة في Menaitech وتابع جميع نماذج التسليم.", "Start clearance for requests approved in Menaitech and track every handover.");
    public string ApprovedRequests => Pick("طلبات معتمدة في Menaitech", "Approved requests in Menaitech");
    public string StartClearance => Pick("بدء إخلاء الطرف", "Start clearance");
    public string AlreadyStarted => Pick("تم البدء", "Started");
    public string AllHandovers => Pick("جميع نماذج التسليم", "All handover forms");
    public string SourceMock => Pick("بيانات تجريبية (لم يُضبط Menaitech API)", "Sample data (Menaitech API not configured)");
    public string OutboxTitle => Pick("رسائلي", "My messages");
    public string OutboxEmpty => Pick("لم تُرسل أي رسالة بعد.", "No messages sent yet.");
    public string EmployeeInfo => Pick("بيانات الموظف (من نظام الموارد البشرية)", "Employee details (from HR system)");
    public string ClearanceInfo => Pick("بيانات إخلاء الطرف", "Clearance details");
    public string Tasks => Pick("المهام المُسلَّمة", "Handed-over tasks");
    public string AddTask => Pick("إضافة مهمة", "Add task");
    public string RemoveTask => Pick("حذف", "Remove");
    public string SaveDraft => Pick("حفظ كمسودة", "Save draft");
    public string Submit => Pick("إرسال للمستلمين", "Send to recipients");
    public string Accept => Pick("قبول المهمة", "Accept task");
    public string Reject => Pick("رفض المهمة", "Decline task");
    public string Approve => Pick("اعتماد", "Approve");
    public string RejectAndReturn => Pick("رفض وإعادة للموظف", "Reject and return");
    public string ViewReport => Pick("عرض التقرير النهائي", "View final report");
    public string ReportTitle => Pick("إيصال تسليم المهام", "Employee Handover Receipt");
    public string ReportPrint => Pick("طباعة / حفظ PDF", "Print / Save PDF");
    public string Back => Pick("رجوع", "Back");
    public string Dash => "—";

    public string Status(string key) => key switch
    {
        "draft" => Pick("بانتظار تعبئة الموظف", "Waiting for employee"),
        "pending_acceptance" => Pick("بانتظار قبول المستلمين", "Waiting for recipients"),
        "pending_manager" => Pick("بانتظار اعتمادك كمدير مباشر", "Waiting for direct manager"),
        "pending_hr" => Pick("بانتظار الموارد البشرية", "Waiting for HR"),
        "returned" => Pick("مُعاد للموظف للتعديل", "Returned for correction"),
        "approved" => Pick("معتمد ومغلق", "Approved and locked"),
        _ => key
    };

    public string TaskStatus(string key) => key switch
    {
        "draft" => Pick("لم يُرسل", "Not sent"),
        "pending" => Pick("بانتظار القبول", "Waiting for acceptance"),
        "accepted" => Pick("مقبولة", "Accepted"),
        "rejected" => Pick("مرفوضة - تحتاج مستلم آخر", "Rejected - needs new recipient"),
        _ => key
    };

    public string Type(string key) => key switch
    {
        "annual_leave" => Pick("إجازة سنوية", "Annual leave"),
        "clearance" => Pick("إخلاء طرف", "Clearance"),
        "resignation" => Pick("استقالة", "Resignation"),
        "transfer" => Pick("نقل", "Transfer"),
        "contract_end" => Pick("انتهاء العقد", "End of contract"),
        _ => key
    };

    public string Error(string code) => code switch
    {
        "notAllowed" => Pick("ليست لديك صلاحية لهذا الإجراء.", "You are not allowed to do this."),
        "commentRequired" => Pick("سبب الرفض إلزامي.", "A reason is required."),
        "notFound" => Pick("النموذج غير موجود.", "Handover not found."),
        "assigneeRequired" => Pick("اختر مستلماً لكل مهمة.", "Choose a recipient for every task."),
        "titleRequired" => Pick("اكتب عنوان كل مهمة.", "Every task needs a title."),
        "sameAssignee" => Pick("اختر موظفاً مختلفاً عن الذي رفض المهمة.", "Choose a different employee from the one who declined."),
        "noTasks" => Pick("أضف مهمة واحدة على الأقل.", "Add at least one task."),
        "badCode" => Pick("الرمز غير صحيح.", "That code is not correct."),
        "expired" => Pick("انتهت صلاحية الرمز. اطلب رمزاً جديداً.", "This code has expired. Request a new one."),
        "notFoundEmail" => Pick("ما فيه حساب بهذا الإيميل. أنشئ حساباً أولاً.", "No account uses this email. Create one first."),
        "invalid" => Pick("تأكد من الإيميل وباقي البيانات.", "Check the email and the other fields."),
        "mailFailed" => MailFailed,
        "emailTaken" => Pick("هذا الإيميل مسجّل. ادخل منه.", "This email is already registered. Sign in with it."),
        "idTaken" => Pick("هذا الرقم الوظيفي مستخدم.", "This employee number is already used."),
        _ => code
    };
}
