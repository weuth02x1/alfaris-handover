import "package:material_ui/material_ui.dart";

class I18n {
  I18n(this.locale);
  String locale;
  bool get isAr => locale == "ar";
  TextDirection get dir => isAr ? TextDirection.rtl : TextDirection.ltr;
  String pick(String ar, String en) => isAr ? ar : en;

  String date(String? iso, {bool withTime = false}) {
    if (iso == null || iso.isEmpty) return dash;
    final raw = iso.length == 10 ? "${iso}T00:00:00" : iso;
    final d = DateTime.tryParse(raw);
    if (d == null) return iso;
    final local = d.toUtc().add(const Duration(hours: 3));
    final y = local.year.toString().padLeft(4, "0");
    final m = local.month.toString().padLeft(2, "0");
    final day = local.day.toString().padLeft(2, "0");
    if (!withTime) return "$y-$m-$day";
    final h = local.hour.toString().padLeft(2, "0");
    final min = local.minute.toString().padLeft(2, "0");
    return "$y-$m-$day $h:$min";
  }

  String fmt(String s, Map<String, Object> vars) {
    return s.replaceAllMapped(
      RegExp(r"\{(\w+)\}"),
      (m) => "${vars[m[1]] ?? ""}",
    );
  }

  String get appName => isAr ? "نظام تسليم العهد والمهام" : "Employee Handover";
  String get appTagline => isAr
      ? "أتمتة إيصال تسليم المهام عند الإجازة أو إنهاء الخدمة"
      : "Automated handover receipts for vacation and termination clearance";

  String get navInbox => isAr ? "مهامي" : "My work";
  String get navHr => isAr ? "لوحة الموارد البشرية" : "HR console";
  String get navHrShort => isAr ? "الموارد" : "HR";
  String get navOutbox => isAr ? "صندوق البريد" : "Mail outbox";
  String get navLogout => isAr ? "تسجيل الخروج" : "Sign out";
  String get navLanguage => isAr ? "English" : "العربية";

  String get loginTitle => isAr ? "تسجيل الدخول" : "Sign in";
  String get loginSubtitle => isAr
      ? "أدخل إيميلك. نرسل رمز الدخول إلى صندوق الوارد عبر بريد المجموعة."
      : "Enter your email. We send the sign-in code to that inbox through company mail.";
  String get mailLive => isAr
      ? "البريد مربوط: الرمز يطلع على إيميلك من Supabase / Resend."
      : "Mail is connected: the code is emailed through Supabase / Resend.";
  String get mailOffline => isAr
      ? "البريد غير مربوط على هذا الموقع حالياً. استخدم الدخول التجريبي أو أعد المحاولة لاحقاً."
      : "Mail is not connected on this site right now. Use sample sign-in or try again later.";
  String get sampleTitle => isAr ? "حسابات محفوظة" : "Saved accounts";
  String get sampleHint => isAr
      ? "اضغط الاسم وادخل مباشرة. الطلب يبقى في نفس الصفحة إذا بدّلت الحساب من هنا."
      : "Tap a name to enter. The request stays on this page if you switch accounts here.";
  String get switchAccount => isAr ? "تبديل الحساب" : "Switch account";
  String get email => isAr ? "الإيميل" : "Email";
  String get emailPh => "name@company.com";
  String get sendCode => isAr ? "أرسل الرمز على الإيميل" : "Email me the code";
  String get codeSent =>
      isAr ? "أرسلنا رمز الدخول إلى إيميلك." : "We emailed the sign-in code.";
  String get checkInbox => isAr
      ? "افتح الإيميل واكتب الرمز كما هو. شيك غير المرغوب إذا تأخر."
      : "Open the email and type the code as it appears. Check spam if it is slow.";
  String get demoMail => isAr ? "رمز الدخول" : "Sign-in code";
  String get code => isAr ? "رمز الدخول" : "Sign-in code";
  String get confirm => isAr ? "دخول" : "Sign in";
  String get resend => isAr ? "إرسال رمز جديد" : "Send a new code";
  String get badCode => isAr ? "الرمز غير صحيح." : "That code is not correct.";
  String get expired => isAr
      ? "انتهت صلاحية الرمز. اطلب رمزاً جديداً."
      : "This code has expired. Request a new one.";
  String get notFound => isAr
      ? "ما فيه حساب بهذا الإيميل. أنشئ حساباً أولاً."
      : "No account uses this email. Create one first.";
  String get invalid => isAr
      ? "تأكد من الإيميل وباقي البيانات."
      : "Check the email and the other fields.";
  String get slow => isAr
      ? "محاولات كثيرة. انتظر ربع ساعة ثم أعد الطلب."
      : "Too many attempts. Wait 15 minutes, then try again.";
  String get mailFailed => isAr
      ? "ما قدرنا نرسل الرمز إلى هذا الإيميل. حاول مرة ثانية."
      : "We could not send the code to that email. Try again.";
  String get mailerDown => isAr
      ? "المشروع واصل، بس بريد Supabase/Resend رافض الإرسال. في Authentication → SMTP حط Host smtp.resend.com وPort 465 وUser resend، والمرسل عنوان على دومين موثّق في Resend مو Gmail."
      : "The app reached Supabase, but its mailer refused to send. In Authentication → SMTP set host smtp.resend.com, port 465, user resend, and a From address on a Resend-verified domain — not Gmail.";
  String get emailTaken => isAr
      ? "هذا الإيميل مسجّل. ادخل منه."
      : "This email is already registered. Sign in with it.";
  String get idTaken => isAr
      ? "هذا الرقم الوظيفي مستخدم."
      : "This employee number is already used.";
  String get haveAccount =>
      isAr ? "عندك حساب؟ سجّل الدخول" : "Already have an account? Sign in";
  String get createAccount =>
      isAr ? "ما عندك حساب؟ أنشئ حساباً" : "No account yet? Create one";
  String get signupTitle => isAr ? "إنشاء حساب" : "Create an account";
  String get signupHint => isAr
      ? "اكتب بياناتك الحقيقية. المدير والمستلم يختارون من الحسابات المسجّلة في الموقع."
      : "Enter your real details. The manager and the recipient are chosen from people registered on this site.";
  String get directManager => isAr ? "المدير المباشر" : "Direct manager";
  String get noManager => isAr ? "بدون مدير مباشر" : "No direct manager";
  String get noManagerYet => isAr
      ? "ما فيه مدير مسجّل لهذا القسم بعد. تقدر تكمل بدون مدير."
      : "No manager is registered for this department yet. You can continue without one.";
  String get isDirectManager =>
      isAr ? "أنا مدير مباشر" : "I am a direct manager";
  String get managesDepartment => isAr ? "أدير قسم" : "Department I manage";
  String get name => isAr ? "الاسم" : "Name";
  String get namePh => isAr ? "اسمك الثلاثي" : "Your full name";
  String get employeeNo => isAr ? "الرقم الوظيفي" : "Employee number";
  String get employeeNoPh => isAr ? "أرقام فقط" : "Digits only";
  String get jobTitle => isAr ? "المسمى الوظيفي" : "Job title";
  String get jobTitlePh =>
      isAr ? "مثال: أخصائية موارد بشرية" : "e.g. HR Specialist";
  String get department => isAr ? "القسم" : "Department";
  String get deptHr => isAr ? "الموارد البشرية" : "Human Resources";
  String get deptTalent => isAr ? "استقطاب المواهب" : "Talent Acquisition";
  String get deptIt => isAr ? "تطوير تقنية المعلومات" : "IT Development";
  String get createAndSend =>
      isAr ? "إنشاء الحساب وإرسال الرمز" : "Create account and email the code";
  String get linkFor =>
      isAr ? "هذا الرابط مخصص للإيميل" : "This link belongs to";

  String status(String key) => {
    "draft": isAr ? "بانتظار تعبئة الموظف" : "Waiting for employee",
    "pending_acceptance": isAr
        ? "بانتظار قبول المستلمين"
        : "Waiting for recipients",
    "pending_manager": isAr
        ? "بانتظار اعتمادك كمدير مباشر"
        : "Waiting for direct manager",
    "pending_hr": isAr ? "بانتظار الموارد البشرية" : "Waiting for HR",
    "returned": isAr ? "مُعاد للموظف للتعديل" : "Returned for correction",
    "approved": isAr ? "معتمد ومغلق" : "Approved and locked",
  }[key]!;

  String taskStatus(String key) => {
    "draft": isAr ? "لم يُرسل" : "Not sent",
    "pending": isAr ? "بانتظار القبول" : "Waiting for acceptance",
    "accepted": isAr ? "مقبولة" : "Accepted",
    "rejected": isAr
        ? "مرفوضة - تحتاج مستلم آخر"
        : "Rejected - needs new recipient",
  }[key]!;

  String type(String key) => {
    "annual_leave": isAr ? "إجازة سنوية" : "Annual leave",
    "clearance": isAr ? "إخلاء طرف" : "Clearance",
    "resignation": isAr ? "استقالة" : "Resignation",
    "transfer": isAr ? "نقل" : "Transfer",
    "contract_end": isAr ? "انتهاء العقد" : "End of contract",
  }[key]!;

  String audit(String key) =>
      {
        "clearance_initiated": isAr ? "بدء إخلاء الطرف" : "Clearance initiated",
        "link_sent": isAr ? "إرسال رابط آمن" : "Secure link sent",
        "form_saved": isAr ? "حفظ مسودة" : "Draft saved",
        "form_submitted": isAr ? "إرسال النموذج" : "Form submitted",
        "task_assigned": isAr ? "إسناد مهمة" : "Task assigned",
        "task_accepted": isAr ? "قبول مهمة" : "Task accepted",
        "task_rejected": isAr ? "رفض مهمة" : "Task rejected",
        "task_reassigned": isAr ? "تحويل مهمة لموظف آخر" : "Task reassigned",
        "manager_approved": isAr ? "اعتماد المدير المباشر" : "Manager approved",
        "manager_rejected": isAr ? "رفض المدير المباشر" : "Manager rejected",
        "hr_approved": isAr ? "اعتماد الموارد البشرية" : "HR approved",
        "hr_rejected": isAr ? "رفض الموارد البشرية" : "HR rejected",
        "document_generated": isAr
            ? "إصدار التقرير النهائي"
            : "Final report generated",
        "document_uploaded": isAr
            ? "رفع التقرير لنظام الموارد البشرية"
            : "Report uploaded to HRMS",
      }[key] ??
      key;

  String get startRequest => isAr ? "ابدأ الطلب" : "Start request";
  String get newRequest => isAr ? "رفع طلب" : "New request";
  String get newRequestHint => isAr
      ? "اختر نوع الخروج والتاريخ. بعدها تعبّئ المهام وتسندها لزميل من نفس القسم."
      : "Choose the reason and the dates. Then list the tasks and assign each one to someone in your department.";
  String get sameDepartmentOnly => isAr
      ? "المستلم لازم يكون موظفاً مسجّلاً في الموقع ومن نفس قسمك."
      : "The recipient must be registered on this site and in your department.";
  String get pickDate => isAr ? "اختر من التقويم" : "Choose from the calendar";
  String get inboxTitle => isAr ? "المطلوب منك" : "Waiting on you";
  String get inboxSubtitle => isAr
      ? "كل ما ينتظر إجراءك في دورة تسليم المهام."
      : "Everything that needs your action in the handover cycle.";
  String get myHandovers =>
      isAr ? "نماذج التسليم الخاصة بي" : "My handover forms";
  String get tasksToAccept => isAr
      ? "مهام مُسندة إليك بانتظار قبولك"
      : "Tasks assigned to you, waiting for your acceptance";
  String get managerQueue => isAr
      ? "نماذج بانتظار اعتمادك كمدير مباشر"
      : "Waiting for your approval as direct manager";
  String get hrQueue =>
      isAr ? "نماذج بانتظار اعتماد الموارد البشرية" : "Waiting for HR approval";
  String get raisedQueue =>
      isAr ? "طلبات مرفوعة للموارد البشرية" : "Requests raised to HR";
  String get notices => isAr ? "إشعارات" : "Notices";
  String get acceptedByMe => isAr ? "مهام استلمتها" : "Tasks I took over";
  String get nothing => isAr
      ? "لا يوجد شيء بانتظارك حالياً."
      : "Nothing is waiting on you right now.";
  String get nothingHint => isAr
      ? "إذا رُفع طلب أو أُسندت لك مهمة يصلك إشعار هنا وعلى إيميلك فيه نوع الطلب والتفاصيل."
      : "When a request is raised or a task is assigned to you, the notice arrives here and by email with the request type and details.";
  String get open => isAr ? "فتح" : "Open";
  String get from => isAr ? "من" : "From";

  String get hrTitle => isAr ? "لوحة الموارد البشرية" : "HR console";
  String get hrSubtitle => isAr
      ? "تابع نماذج التسليم التي يرفعها الموظفون المسجّلون."
      : "Track handover forms raised by registered employees.";
  String get approvedRequests =>
      isAr ? "طلبات معتمدة في Menaitech" : "Approved requests in Menaitech";
  String get approvedRequestsHint => isAr
      ? "بدء إخلاء الطرف يُنشئ نموذج التسليم تلقائياً ويرسل للموظف رابطاً آمناً بالبريد."
      : "Starting clearance creates the handover form and emails the employee a secure link.";
  String get startClearance => isAr ? "بدء إخلاء الطرف" : "Start clearance";
  String get alreadyStarted => isAr ? "تم البدء" : "Started";
  String get allHandovers => isAr ? "جميع نماذج التسليم" : "All handover forms";
  String get noRequests =>
      isAr ? "لا توجد طلبات معتمدة جديدة." : "No new approved requests.";
  String get noHandovers =>
      isAr ? "لم يتم إنشاء أي نموذج بعد." : "No handover forms yet.";
  String get ref => isAr ? "رقم الطلب" : "Request";
  String get employee => isAr ? "الموظف" : "Employee";
  String get typeLabel => isAr ? "سبب الخروج" : "Reason for leaving";
  String get fromDate => isAr ? "من" : "From";
  String get toDate => isAr ? "إلى" : "To";
  String get statusLabel => isAr ? "الحالة" : "Status";
  String get number => isAr ? "رقم النموذج" : "Form no.";
  String get progress => isAr ? "قبول المهام" : "Acceptance";
  String get source => isAr ? "مصدر البيانات" : "Data source";
  String get sourceMock => isAr
      ? "بيانات تجريبية (لم يُضبط Menaitech API)"
      : "Sample data (Menaitech API not configured)";

  String get outboxTitle => isAr ? "رسائلي" : "My messages";
  String get outboxSubtitle => isAr
      ? "الرسائل المرسلة إلى إيميلك فقط. رابط المهمة يبقى داخل الإيميل."
      : "Only messages sent to your email. The task link stays in the email itself.";
  String get outboxEmpty =>
      isAr ? "لم تُرسل أي رسالة بعد." : "No messages sent yet.";
  String get outboxTo => isAr ? "إلى" : "To";

  String get employeeInfo => isAr
      ? "بيانات الموظف (من نظام الموارد البشرية)"
      : "Employee details (from HR system)";
  String get formName => isAr ? "اسم الموظف" : "Employee name";
  String get formId => isAr ? "الرقم الوظيفي" : "Employee ID";
  String get formJobTitle => isAr ? "المسمى الوظيفي" : "Job title";
  String get formManager => isAr ? "المدير المباشر" : "Direct manager";
  String get formDepartment => isAr ? "الإدارة" : "Department";
  String get formSection => isAr ? "القسم" : "Section";
  String get clearanceInfo => isAr ? "بيانات إخلاء الطرف" : "Clearance details";
  String get requestRef => isAr ? "رقم الطلب" : "Request";
  String get lastWorkingDay => isAr ? "آخر يوم عمل" : "Last working day";
  String get returnDate => isAr ? "تاريخ العودة" : "Return date";
  String get tasks => isAr ? "المهام المُسلَّمة" : "Handed-over tasks";
  String get tasksHint => isAr
      ? "اكتب كل مهمة وحدد الموظف الذي سيستلمها. المستلم لازم يكون من نفس القسم، حتى لو اسم القسم مختلف، ويجب أن يقبل كل مستلم مهمته."
      : "List each task and who will take it over. Recipients must be in your department, and each must accept.";
  String get taskTitle => isAr ? "المهمة" : "Task";
  String get taskTitlePh => isAr
      ? "مثال: متابعة مشروع ترقية نظام الرواتب"
      : "e.g. Follow up on the payroll upgrade project";
  String get taskDetails => isAr ? "التفاصيل والملاحظات" : "Details and notes";
  String get taskDetailsPh => isAr
      ? "الوضع الحالي، الملفات والروابط، جهات التواصل، ما المتبقي..."
      : "Current status, files and links, contacts, what is left...";
  String get dueDate => isAr ? "تاريخ الاستحقاق" : "Due date";
  String get assignee => isAr ? "المستلم" : "Recipient";
  String get chooseAssignee =>
      isAr ? "اختر الموظف المستلم" : "Choose recipient";
  String get addTask => isAr ? "إضافة مهمة" : "Add task";
  String get removeTask => isAr ? "حذف" : "Remove";
  String get generalNotes => isAr ? "ملاحظات عامة" : "General notes";
  String get generalNotesPh => isAr
      ? "أي معلومات إضافية تخص التسليم (عهد، صلاحيات، كلمات مرور تم تسليمها لتقنية المعلومات...)"
      : "Anything else about the handover (assets, access, credentials handed to IT...)";
  String get saveDraft => isAr ? "حفظ كمسودة" : "Save draft";
  String get submit => isAr ? "إرسال للمستلمين" : "Send to recipients";
  String get readOnly => isAr
      ? "النموذج للقراءة فقط في هذه المرحلة."
      : "This form is read-only at this stage.";
  String get returnedBanner => isAr
      ? "أُعيد النموذج إليك للتعديل"
      : "This form was returned to you for correction";
  String get returnedBy => isAr ? "بواسطة" : "by";
  String get rejectedTasksBanner => isAr
      ? "بعض المستلمين رفضوا المهام. اختر موظفاً آخر لكل مهمة مرفوضة."
      : "Some recipients declined their tasks. Pick another employee for each declined task.";
  String get previouslyRejectedBy =>
      isAr ? "رفضها سابقاً" : "Previously declined by";
  String get reassign => isAr ? "تحويل لموظف آخر" : "Reassign";
  String get newAssignee => isAr ? "المستلم الجديد" : "New recipient";
  String get accept => isAr ? "قبول المهمة" : "Accept task";
  String get reject => isAr ? "رفض المهمة" : "Decline task";
  String get acceptNote => isAr ? "ملاحظة (اختياري)" : "Note (optional)";
  String get rejectReason => isAr ? "سبب الرفض (إلزامي)" : "Reason (required)";
  String get rejectReasonPh => isAr
      ? "مثال: لدي ضغط عمل في نفس الفترة، أقترح الزميل..."
      : "e.g. I have a heavy workload in the same period...";
  String get confirmReject => isAr ? "تأكيد الرفض" : "Confirm decline";
  String get cancel => isAr ? "إلغاء" : "Cancel";
  String get approve => isAr ? "اعتماد" : "Approve";
  String get rejectAndReturn =>
      isAr ? "رفض وإعادة للموظف" : "Reject and return";
  String get approvalComment =>
      isAr ? "ملاحظة (اختياري)" : "Comment (optional)";
  String get rejectionComment =>
      isAr ? "سبب الرفض (إلزامي)" : "Reason (required)";
  String get managerReview =>
      isAr ? "مراجعة المدير المباشر" : "Direct manager review";
  String get managerReviewHint => isAr
      ? "اعتمادك يؤكد انتقال ملكية المهام للمستلمين."
      : "Your approval confirms task ownership moves to the recipients.";
  String get hrReview => isAr ? "اعتماد الموارد البشرية" : "HR approval";
  String get hrReviewHint => isAr
      ? "الاعتماد النهائي يغلق إخلاء الطرف ويصدر التقرير ويرفعه لملف الموظف."
      : "Final approval closes clearance, issues the report and files it on the employee record.";
  String get yourTask => isAr ? "مهمة مُسندة إليك" : "Assigned to you";
  String get auditTrail => isAr ? "سجل التدقيق" : "Audit trail";
  String get viewReport => isAr ? "عرض التقرير النهائي" : "View final report";
  String get acceptedAt => isAr ? "تاريخ القبول" : "Accepted at";
  String get progressFmt => isAr ? "تم قبول {a} من {b}" : "{a} of {b} accepted";
  String get noTasks =>
      isAr ? "أضف مهمة واحدة على الأقل." : "Add at least one task.";

  String get reportTitle =>
      isAr ? "إيصال تسليم المهام" : "Employee Handover Receipt";
  String get reportSubtitle =>
      isAr ? "Employee Handover Receipt" : "إيصال تسليم المهام";
  String get reportPrint => isAr ? "طباعة / حفظ PDF" : "Print / Save PDF";
  String get reportBack => isAr ? "رجوع" : "Back";
  String get reportFinalNote => isAr
      ? "هذا المستند صادر آلياً من نظام تسليم المهام ومقفل بعد الاعتماد النهائي، ومحفوظ في ملف الموظف بنظام الموارد البشرية."
      : "This document was generated by the handover system, locked after final approval, and filed on the employee record in the HR system.";
  String get reportHash => isAr ? "بصمة المستند" : "Document fingerprint";
  String get reportHrms =>
      isAr ? "رقم المستند في Menaitech" : "Menaitech document ID";
  String get reportNotFinal => isAr
      ? "التقرير يصدر بعد الاعتماد النهائي من الموارد البشرية."
      : "The report is issued after final HR approval.";

  String get notAllowed => isAr
      ? "ليست لديك صلاحية لهذا الإجراء."
      : "You are not allowed to do this.";
  String get commentRequired =>
      isAr ? "سبب الرفض إلزامي." : "A reason is required.";
  String get handoverNotFound =>
      isAr ? "النموذج غير موجود." : "Handover not found.";
  String get assigneeRequired =>
      isAr ? "اختر مستلماً لكل مهمة." : "Choose a recipient for every task.";
  String get titleRequired =>
      isAr ? "اكتب عنوان كل مهمة." : "Every task needs a title.";
  String get sameAssignee => isAr
      ? "اختر موظفاً مختلفاً عن الذي رفض المهمة."
      : "Choose a different employee from the one who declined.";
  String error(String code) =>
      {
        "notAllowed": notAllowed,
        "commentRequired": commentRequired,
        "notFound": handoverNotFound,
        "assigneeRequired": assigneeRequired,
        "titleRequired": titleRequired,
        "sameAssignee": sameAssignee,
        "noTasks": noTasks,
        "badCode": badCode,
        "expired": expired,
        "notFoundEmail": notFound,
        "invalid": invalid,
        "slow": slow,
        "mailFailed": mailFailed,
        "mailerDown": mailerDown,
        "emailTaken": emailTaken,
        "idTaken": idTaken,
      }[code] ??
      code;

  String get dash => "—";
  String get back => isAr ? "رجوع" : "Back";
}
