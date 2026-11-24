import "package:alfaris_handover/auth_mail.dart";
import "package:alfaris_handover/directory.dart";
import "package:alfaris_handover/i18n.dart";
import "package:alfaris_handover/local_box.dart";
import "package:alfaris_handover/models.dart";
import "package:alfaris_handover/store.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("clearance cycle after a signed-in employee", () {
    final store = AppStore();
    final hind = store.createAccount(
      email: "hind@alfaris.test",
      name: "هند الغامدي",
      employeeNo: "30115",
      jobTitle: "أخصائية موارد بشرية",
      departmentId: "D-HR",
    );
    final fahad = store.createAccount(
      email: "fahad@alfaris.test",
      name: "فهد العتيبي",
      employeeNo: "10501",
      jobTitle: "مدير تطوير",
      departmentId: "D-ITD",
      isManager: true,
      managesDepartmentId: "D-ITD",
    );
    final sarah = store.createAccount(
      email: "sarah@alfaris.test",
      name: "سارة القحطاني",
      employeeNo: "10518",
      jobTitle: "مطورة أنظمة",
      departmentId: "D-ITD",
      managerId: fahad.id,
    );
    final abdullah = store.createAccount(
      email: "abdullah@alfaris.test",
      name: "عبدالله الحربي",
      employeeNo: "10530",
      jobTitle: "مطور واجهات",
      departmentId: "D-ITD",
      managerId: fahad.id,
    );
    store.signInForTest(sarah);

    final id = store.startOwn(
      sarah,
      type: "clearance",
      lastWorkingDay: "2026-12-15",
    );
    store.saveForm(
      sarah,
      id,
      generalNotes: "سلمت صلاحيات Git للفريق",
      tasks: [
        HandoverTask(
          id: "",
          title: "متابعة مشروع ترقية نظام الرواتب",
          details: "الملفات على الشبكة الداخلية",
          assigneeId: abdullah.id,
          status: "draft",
        ),
      ],
      submit: true,
    );
    expect(store.handover(id)!.status, "pending_acceptance");

    store.acceptTask(
      abdullah,
      id,
      store.handover(id)!.tasks.first.id,
      "تم الاستلام",
    );
    expect(store.handover(id)!.status, "pending_manager");

    store.managerDecision(fahad, id, true, "");
    expect(store.handover(id)!.status, "pending_hr");

    store.hrDecision(hind, id, true, "معتمد");
    expect(store.handover(id)!.status, "approved");
    expect(store.handover(id)!.documentHash, isNotNull);

    expect(
      store
          .mailFor(abdullah)
          .any(
            (m) =>
                m.body.contains("إسناد مهمة") &&
                m.body.contains("وين وصل الطلب: بانتظار قبول المهام"),
          ),
      isTrue,
    );
    expect(
      store.mailFor(sarah).any((m) => m.body.contains("قبول المهمة")),
      isTrue,
    );
    expect(
      store
          .mailFor(fahad)
          .any((m) => m.body.contains("وين وصل الطلب: عند المدير المباشر")),
      isTrue,
    );
    expect(
      store
          .mailFor(hind)
          .any((m) => m.body.contains("وين وصل الطلب: عند الموارد البشرية")),
      isTrue,
    );
    expect(store.mailFor(sarah).first.body, contains("معتمد ومغلق"));
    expect(
      store.mailFor(sarah).first.body,
      contains("متابعة مشروع ترقية نظام الرواتب"),
    );
    expect(store.mailFor(fahad).first.subject, contains("أُغلق طلب"));
  });

  test(
    "sign-in without mail configured does not invent a local code",
    () async {
      final store = AppStore();
      expect(AuthMail.enabled, isFalse);
      expect(store.people, isEmpty);
      await expectLater(
        store.requestOtp("nobody@alfaris.test"),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.code,
            "code",
            "notFoundEmail",
          ),
        ),
      );
      store.createAccount(
        email: "hind@alfaris.test",
        name: "هند",
        employeeNo: "30115",
        jobTitle: "موارد بشرية",
        departmentId: "D-HR",
      );
      await expectLater(
        store.requestOtp("hind@alfaris.test"),
        throwsA(
          isA<WorkflowException>().having((e) => e.code, "code", "mailFailed"),
        ),
      );
      expect(I18n("ar").error("mailFailed"), isNot(contains("mailFailed")));
      expect(I18n("ar").error("mailerDown"), contains("SMTP"));
      expect(store.lastOtpCode, isNull);
      expect(store.user, isNull);
    },
  );

  test("an employee can open leave and only assign a registered colleague", () {
    final store = AppStore();
    store.createAccount(
      email: "hind@alfaris.test",
      name: "هند الغامدي",
      employeeNo: "30115",
      jobTitle: "موارد بشرية",
      departmentId: "D-HR",
    );
    final fahad = store.createAccount(
      email: "fahad@alfaris.test",
      name: "فهد العتيبي",
      employeeNo: "10501",
      jobTitle: "مدير تطوير",
      departmentId: "D-ITD",
      isManager: true,
      managesDepartmentId: "D-ITD",
    );
    final sarah = store.createAccount(
      email: "sarah@alfaris.test",
      name: "سارة القحطاني",
      employeeNo: "10518",
      jobTitle: "مطورة أنظمة",
      departmentId: "D-ITD",
      managerId: fahad.id,
    );
    store.accounts.add(
      Employee(
        id: "10540",
        nameAr: "نورة الدوسري",
        nameEn: "نورة الدوسري",
        jobTitleAr: "محللة",
        jobTitleEn: "محللة",
        departmentId: "IT-SYS",
        departmentAr: "إدارة تقنية المعلومات",
        departmentEn: "Information Technology",
        sectionAr: "تحليل الأنظمة",
        sectionEn: "Systems Analysis",
        branchId: "B-RUH",
        email: "noura@alfaris.test",
        role: "employee",
        managerId: fahad.id,
      ),
    );
    store.createAccount(
      email: "lama@alfaris.test",
      name: "لمى الحربي",
      employeeNo: "40221",
      jobTitle: "استقطاب",
      departmentId: "D-TA",
    );
    store.signInForTest(sarah);
    final colleagues = store.colleaguesFor(sarah.id).map((e) => e.id);
    expect(colleagues, contains("10540"));
    expect(colleagues, contains("10501"));
    expect(colleagues, isNot(contains("40221")));
    expect(departmentKey(store.person("10540")!), "D-ITD");

    final id = store.startOwn(
      sarah,
      type: "annual_leave",
      lastWorkingDay: "2026-12-01",
      returnDate: "2026-12-20",
    );
    expect(store.handover(id)!.status, "draft");
    final hind = store.person("30115")!;
    final notice = store.mailFor(hind).single;
    expect(notice.subject, "يوجد طلب إجازة سنوية من سارة القحطاني");
    expect(notice.body, contains("القسم: تطوير تقنية المعلومات"));
    expect(notice.body, contains("آخر يوم عمل: 2026-12-01"));
    expect(notice.body, contains("تاريخ العودة: 2026-12-20"));
    expect(store.inboxFor(hind).raised.map((h) => h.id), contains(id));
    expect(store.mailFor(sarah), isEmpty);
    expect(
      () => store.saveForm(
        sarah,
        id,
        generalNotes: "",
        tasks: [
          HandoverTask(
            id: "",
            title: "تسليم",
            details: "",
            assigneeId: "40221",
            status: "draft",
          ),
        ],
        submit: true,
      ),
      throwsA(
        isA<WorkflowException>().having((e) => e.code, "code", "notAllowed"),
      ),
    );
  });

  test("a reload keeps registered people and their manager", () {
    final box = LocalBox();
    final store = AppStore(box: box);
    expect(store.people, isEmpty);
    final manager = store.createAccount(
      email: "fahad@alfaris.test",
      name: "فهد",
      employeeNo: "10501",
      jobTitle: "مدير",
      departmentId: "D-ITD",
      isManager: true,
      managesDepartmentId: "D-ITD",
    );
    store.createAccount(
      email: "sarah@alfaris.test",
      name: "سارة",
      employeeNo: "10518",
      jobTitle: "مطورة",
      departmentId: "D-ITD",
      managerId: manager.id,
    );
    final again = AppStore(box: box);
    expect(again.person("10518")?.managerId, "10501");
    expect(again.managersFor("D-ITD").map((e) => e.id), ["10501"]);
    expect(again.managersFor("D-HR"), isEmpty);
  });

  test("cycle accounts share one inbox and cover the whole handover", () {
    final store = AppStore();
    store.ensureCycleAccounts();
    expect(store.people, hasLength(4));
    final shahad = store.findByEmail("shahad0x66@gmail.com");
    expect(shahad, isNotNull);
    expect(
      store.colleaguesFor(shahad!.id).map((e) => e.email),
      contains("shahad0x66+colleague@gmail.com"),
    );
    expect(
      store.person(shahad.managerId)?.email,
      "shahad0x66+manager@gmail.com",
    );
    expect(store.hrUsers.single.email, "shahad0x66+hr@gmail.com");
    store.ensureCycleAccounts();
    expect(store.people, hasLength(4));
  });

  test("OTP redirect points at the live site, not localhost", () {
    expect(
      AuthMail.otpUri().queryParameters["redirect_to"],
      contains("alfaris-handover"),
    );
    expect(AuthMail.otpUri().toString(), isNot(contains("localhost")));
    expect(siteUrl, isNot(contains("localhost")));
  });
}
