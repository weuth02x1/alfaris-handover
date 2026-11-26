import "package:alfaris_handover/auth_mail.dart";
import "package:alfaris_handover/directory.dart";
import "package:alfaris_handover/i18n.dart";
import "package:alfaris_handover/local_box.dart";
import "package:alfaris_handover/models.dart";
import "package:alfaris_handover/shared_state.dart";
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
    expect(store.handover(id)!.status, "pending_manager");
    expect(store.waitingCount(abdullah), 1);
    expect(store.inboxFor(fahad).managerQueue, hasLength(1));
    expect(store.waitingCount(fahad), 1);

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
                m.body.contains("وين وصل الطلب: عند المدير المباشر"),
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

  test("a code typed in Arabic matches every address in the same inbox", () {
    expect(AuthMail.digits("٦٧٦٨٨٧"), "676887");
    expect(AuthMail.digits("۴۷۶ ۴۰۳"), "476403");
    expect(
      AuthMail.inboxKey("Shahad0x66+HR@gmail.com"),
      AuthMail.inboxKey("shahad.0x66@googlemail.com"),
    );
    expect(
      AuthMail.inboxKey("shahad0x66+hr@gmail.com"),
      isNot(AuthMail.inboxKey("shahad0x4@gmail.com")),
    );
    final store = AppStore();
    store.createAccount(
      email: "shahad0x66+hr@gmail.com",
      name: "شهد موارد",
      employeeNo: "22015",
      jobTitle: "موارد بشرية",
      departmentId: "D-HR",
    );
    store.createAccount(
      email: "shahad0x66@gmail.com",
      name: "شهد",
      employeeNo: "22018",
      jobTitle: "مطورة",
      departmentId: "D-ITD",
    );
    store.createAccount(
      email: "shahad0x4@gmail.com",
      name: "شهد أخرى",
      employeeNo: "17272",
      jobTitle: "مطورة",
      departmentId: "D-ITD",
    );
    expect(store.otpEmailsFor("shahad0x66@gmail.com"), [
      "shahad0x66@gmail.com",
      "shahad0x66+hr@gmail.com",
    ]);
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
    expect(colleagues, contains("40221"));
    expect(departmentKey(store.person("10540")!), "D-ITD");

    final id = store.startOwn(
      sarah,
      type: "annual_leave",
      lastWorkingDay: "2026-12-01",
      returnDate: "2026-12-20",
    );
    expect(store.handover(id)!.status, "pending_manager");
    final hind = store.person("30115")!;
    final notice = store.mailFor(fahad).single;
    expect(notice.subject, contains("إجازة"));
    expect(notice.body, contains("القسم: تطوير تقنية المعلومات"));
    expect(notice.body, contains("آخر يوم عمل: 2026-12-01"));
    expect(notice.body, contains("تاريخ العودة: 2026-12-20"));
    expect(store.inboxFor(fahad).managerQueue.map((h) => h.id), contains(id));
    expect(store.inboxFor(hind).raised.map((h) => h.id), contains(id));
    expect(store.mailFor(sarah).single.body, contains("عند المدير المباشر"));
    store.saveForm(
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
    );
    expect(store.handover(id)!.status, "pending_manager");
    expect(store.inboxFor(store.person("40221")!).toAccept, hasLength(1));
    expect(
      () => store.hrDecision(hind, id, true, ""),
      throwsA(isA<WorkflowException>()),
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
    expect(again.managersFor("D-HR").map((e) => e.id), ["10501"]);
  });

  test("a request opened on another device reaches HR and the manager", () {
    final remote = {
      "counter": 3,
      "accounts": [
        {
          "id": "88001",
          "nameAr": "محمد عبدالماجد",
          "nameEn": "محمد عبدالماجد",
          "jobTitleAr": "محلل",
          "jobTitleEn": "محلل",
          "departmentId": "D-ITD",
          "departmentAr": "تطوير تقنية المعلومات",
          "departmentEn": "IT Development",
          "sectionAr": "تطوير الأنظمة",
          "sectionEn": "Systems Development",
          "branchId": "B-RUH",
          "managerId": "22001",
          "email": "mohammed@example.com",
          "role": "employee",
          "staffNumber": "88001",
          "isManager": false,
        },
      ],
      "handovers": [
        {
          "id": "remote-1",
          "number": "HO-2026-0008",
          "requestRef": "SELF-88001-1",
          "type": "clearance",
          "lastWorkingDay": "2026-12-01",
          "employee": {
            "id": "88001",
            "nameAr": "محمد عبدالماجد",
            "nameEn": "محمد عبدالماجد",
            "jobTitleAr": "محلل",
            "jobTitleEn": "محلل",
            "departmentAr": "تطوير تقنية المعلومات",
            "departmentEn": "IT Development",
            "sectionAr": "تطوير الأنظمة",
            "sectionEn": "Systems Development",
            "managerId": "22001",
            "managerNameAr": "شهد القحطاني",
            "managerNameEn": "شهد القحطاني",
          },
          "status": "pending_acceptance",
          "generalNotes": "",
          "tasks": [
            {
              "id": "task-1",
              "title": "تسليم الملفات",
              "details": "",
              "assigneeId": "22030",
              "status": "pending",
              "rejections": [],
            },
          ],
          "initiatedById": "88001",
          "createdAt": "2026-11-24T08:00:00Z",
        },
      ],
      "outbox": [],
      "audit": [],
    };
    final local = AppStore();
    local.ensureCycleAccounts();
    final merged = mergeSharedState(local.snapshot(), remote);
    final seen = AppStore();
    seen.replaceShared(merged);
    final hr = seen.findByEmail("shahad0x66+hr@gmail.com")!;
    final manager = seen.findByEmail("shahad0x66+manager@gmail.com")!;
    expect(seen.inboxFor(hr).raised.map((h) => h.id), contains("remote-1"));
    expect(
      seen.inboxFor(manager).teamOpen.map((h) => h.id),
      contains("remote-1"),
    );
    expect(seen.waitingCount(hr), greaterThan(0));
    expect(seen.waitingCount(manager), greaterThan(0));
  });

  test("a new account on a fresh device can send to any registered person", () {
    final fresh = AppStore();
    fresh.ensureCycleAccounts();
    final manager = fresh.findByEmail("shahad0x66+manager@gmail.com")!;
    final colleague = fresh.findByEmail("shahad0x66+colleague@gmail.com")!;
    final hr = fresh.findByEmail("shahad0x66+hr@gmail.com")!;
    final newcomer = fresh.createAccount(
      email: "mohammed.new@gmail.com",
      name: "محمد عبدالماجد",
      employeeNo: "88021",
      jobTitle: "محلل",
      departmentId: "D-TA",
      managerId: manager.id,
    );
    final id = fresh.startOwn(
      newcomer,
      type: "clearance",
      lastWorkingDay: "2026-12-01",
    );
    fresh.saveForm(
      newcomer,
      id,
      generalNotes: "",
      tasks: [
        HandoverTask(
          id: "",
          title: "تسليم الملفات",
          details: "",
          assigneeId: colleague.id,
          status: "draft",
        ),
      ],
      submit: true,
    );
    final olderDevice = AppStore();
    olderDevice.ensureCycleAccounts();
    final merged = mergeSharedState(olderDevice.snapshot(), fresh.snapshot());
    final seen = AppStore();
    seen.replaceShared(merged);
    expect(seen.findByEmail("mohammed.new@gmail.com"), isNotNull);
    expect(
      seen
          .inboxFor(seen.person(colleague.id)!)
          .toAccept
          .map((item) => item.handover.id),
      contains(id),
    );
    expect(
      seen.inboxFor(seen.person(hr.id)!).raised.map((h) => h.id),
      contains(id),
    );
    expect(
      seen.inboxFor(seen.person(manager.id)!).managerQueue.map((h) => h.id),
      contains(id),
    );
  });

  test("a new resignation goes to the manager, or straight to HR", () {
    final store = AppStore();
    final hr = store.createAccount(
      email: "hr3@alfaris.test",
      name: "هند",
      employeeNo: "50115",
      jobTitle: "موارد بشرية",
      departmentId: "D-HR",
    );
    final manager = store.createAccount(
      email: "boss3@alfaris.test",
      name: "فهد",
      employeeNo: "50501",
      jobTitle: "مدير",
      departmentId: "D-ITD",
      isManager: true,
      managesDepartmentId: "D-ITD",
    );
    final withBoss = store.createAccount(
      email: "new.with.boss@gmail.com",
      name: "سارة",
      employeeNo: "50518",
      jobTitle: "مطورة",
      departmentId: "D-TA",
      managerId: manager.id,
    );
    final noBoss = store.createAccount(
      email: "new.no.boss@gmail.com",
      name: "محمد",
      employeeNo: "50519",
      jobTitle: "محلل",
      departmentId: "D-TA",
    );
    final toManager = store.startOwn(
      withBoss,
      type: "resignation",
      lastWorkingDay: "2026-12-30",
    );
    expect(store.handover(toManager)!.status, "pending_manager");
    expect(store.inboxFor(manager).managerQueue.map((h) => h.id), [toManager]);
    expect(store.inboxFor(hr).hrQueue, isEmpty);

    final toHr = store.startOwn(
      noBoss,
      type: "resignation",
      lastWorkingDay: "2026-12-30",
    );
    expect(store.handover(toHr)!.status, "pending_hr");
    expect(store.inboxFor(hr).hrQueue.map((h) => h.id), [toHr]);
    expect(store.inboxFor(manager).managerQueue.map((h) => h.id), [toManager]);
    store.saveForm(
      noBoss,
      toHr,
      generalNotes: "",
      tasks: [
        HandoverTask(
          id: "",
          title: "تسليم",
          details: "",
          assigneeId: hr.id,
          status: "draft",
        ),
        HandoverTask(
          id: "",
          title: "شبكة",
          details: "",
          assigneeId: manager.id,
          status: "draft",
        ),
      ],
      submit: true,
    );
    expect(store.handover(toHr)!.status, "pending_hr");
    store.acceptTask(hr, toHr, store.handover(toHr)!.tasks.first.id, "تم");
    expect(
      () => store.hrDecision(hr, toHr, true, ""),
      throwsA(
        isA<WorkflowException>().having((e) => e.code, "code", "tasksPending"),
      ),
    );
    expect(store.handover(toHr)!.documentHash, isNull);
    store.acceptTask(manager, toHr, store.handover(toHr)!.tasks.last.id, "تم");

    final otherDevice = AppStore();
    otherDevice.replaceShared(
      mergeSharedState(otherDevice.snapshot(), store.snapshot()),
    );
    final hrThere = otherDevice.findByEmail("hr3@alfaris.test")!;
    final bossThere = otherDevice.findByEmail("boss3@alfaris.test")!;
    expect(otherDevice.inboxFor(bossThere).managerQueue.map((h) => h.id), [
      toManager,
    ]);
    expect(otherDevice.inboxFor(hrThere).hrQueue.map((h) => h.id), [toHr]);
    store.hrDecision(hr, toHr, true, "معتمد");
    expect(store.handover(toHr)!.status, "approved");
    expect(store.handover(toHr)!.documentHash, isNotNull);
  });

  test(
    "a form stays open when the same email is saved from another device",
    () {
      final store = AppStore();
      final hr = store.createAccount(
        email: "hr4@alfaris.test",
        name: "هند",
        employeeNo: "60115",
        jobTitle: "موارد بشرية",
        departmentId: "D-HR",
      );
      final owner = store.createAccount(
        email: "shahad0x4@gmail.com",
        name: "shahad saad alqahtani",
        employeeNo: "17272",
        jobTitle: "AI",
        departmentId: "D-ITD",
      );
      store.signInForTest(owner);
      final id = store.startOwn(
        owner,
        type: "resignation",
        lastWorkingDay: "2026-12-30",
      );
      final older = AppStore();
      older.createAccount(
        email: "shahad0x4@gmail.com",
        name: "mohamed Ali",
        employeeNo: "12212",
        jobTitle: "IT",
        departmentId: "D-ITD",
      );
      store.replaceShared(older.snapshot());
      expect(store.handover(id), isNotNull);
      expect(store.handover(id)!.status, "pending_hr");
      expect(store.user?.id, "17272");
      expect(store.inboxFor(store.user!).mine.map((h) => h.id), contains(id));
      expect(store.person("12212"), isNotNull);
      expect(store.inboxFor(hr).hrQueue.map((h) => h.id), contains(id));
      final saved = store.snapshot();
      (saved["accounts"] as List).removeWhere((item) => item["id"] == "17272");
      final restored = AppStore();
      restored.replaceShared(saved);
      expect(restored.person("17272")?.email, "shahad0x4@gmail.com");
      expect(restored.handover(id)?.status, "pending_hr");
      expect(
        restored
            .inboxFor(restored.findByEmail("shahad0x4@gmail.com")!)
            .mine
            .map((h) => h.id),
        contains(id),
      );
    },
  );

  test("HR can approve or reject a request that has no manager", () {
    final store = AppStore();
    final hr = store.createAccount(
      email: "hr5@alfaris.test",
      name: "هند",
      employeeNo: "70115",
      jobTitle: "موارد بشرية",
      departmentId: "D-HR",
    );
    final person = store.createAccount(
      email: "majid@alfaris.test",
      name: "Mohammed A Majid",
      employeeNo: "96552",
      jobTitle: "IT Director",
      departmentId: "D-ITD",
    );
    final colleague = store.createAccount(
      email: "witness@alfaris.test",
      name: "شهد",
      employeeNo: "22030",
      jobTitle: "مطورة",
      departmentId: "D-ITD",
    );
    final id = store.startOwn(
      person,
      type: "annual_leave",
      lastWorkingDay: "2026-11-26",
      returnDate: "2026-12-10",
    );
    store.handover(id)!.status = "pending_acceptance";
    store.handover(id)!.tasks = [
      HandoverTask(
        id: "erp",
        title: "ERP - Epicor",
        details: "ERP",
        assigneeId: colleague.id,
        status: "pending",
      ),
      HandoverTask(
        id: "net",
        title: "Network",
        details: "Network",
        assigneeId: colleague.id,
        status: "accepted",
      ),
    ];
    store.handover(id)!.status = "pending_hr";
    expect(
      () => store.hrDecision(hr, id, true, ""),
      throwsA(
        isA<WorkflowException>().having((e) => e.code, "code", "tasksPending"),
      ),
    );
    store.handover(id)!.hrApproval = null;
    store.handover(id)!.status = "approved";
    store.handover(id)!.hrmsDocumentId = "MENA-HO-2026-0010";
    store.replaceShared(store.snapshot());
    expect(store.handover(id)!.status, "pending_hr");
    expect(store.handover(id)!.hrmsDocumentId, isNull);
    expect(store.inboxFor(hr).hrQueue.map((h) => h.id), contains(id));
    expect(
      () => store.hrDecision(hr, id, true, ""),
      throwsA(
        isA<WorkflowException>().having((e) => e.code, "code", "tasksPending"),
      ),
    );
    store.handover(id)!.tasks.first.status = "accepted";
    store.hrDecision(hr, id, true, "معتمد");
    expect(store.handover(id)!.status, "approved");
    expect(store.handover(id)!.documentHash, isNotNull);
  });

  test("a refusal comes back, then acceptance reaches the manager and HR", () {
    final store = AppStore();
    final hind = store.createAccount(
      email: "hind2@alfaris.test",
      name: "هند",
      employeeNo: "40115",
      jobTitle: "موارد بشرية",
      departmentId: "D-HR",
    );
    final fahad = store.createAccount(
      email: "fahad2@alfaris.test",
      name: "فهد",
      employeeNo: "20501",
      jobTitle: "مدير",
      departmentId: "D-ITD",
      isManager: true,
      managesDepartmentId: "D-ITD",
    );
    final sara = store.createAccount(
      email: "sara2@alfaris.test",
      name: "سارة",
      employeeNo: "20518",
      jobTitle: "مطورة",
      departmentId: "D-ITD",
      managerId: fahad.id,
    );
    final first = store.createAccount(
      email: "first2@alfaris.test",
      name: "أحمد",
      employeeNo: "20530",
      jobTitle: "مطور",
      departmentId: "D-ITD",
      managerId: fahad.id,
    );
    final second = store.createAccount(
      email: "second2@alfaris.test",
      name: "ليان",
      employeeNo: "20531",
      jobTitle: "مطورة",
      departmentId: "D-ITD",
      managerId: fahad.id,
    );
    final id = store.startOwn(
      sara,
      type: "annual_leave",
      lastWorkingDay: "2026-12-20",
    );
    store.saveForm(
      sara,
      id,
      generalNotes: "",
      tasks: [
        HandoverTask(
          id: "",
          title: "تسليم الملفات",
          details: "على المجلد المشترك",
          assigneeId: first.id,
          status: "draft",
        ),
      ],
      submit: true,
    );
    expect(store.inboxFor(first).toAccept, hasLength(1));
    final before = store.snapshot();
    store.rejectTask(first, id, store.handover(id)!.tasks.first.id, "مشغولة");
    expect(store.inboxFor(sara).needsReassign, hasLength(1));
    expect(
      () => store.reassignTask(
        sara,
        id,
        store.handover(id)!.tasks.first.id,
        first.id,
      ),
      throwsA(
        isA<WorkflowException>().having((e) => e.code, "code", "sameAssignee"),
      ),
    );
    expect(
      () => store.hrDecision(hind, id, true, ""),
      throwsA(isA<WorkflowException>()),
    );
    expect(store.handover(id)!.documentHash, isNull);
    final rejected = store.snapshot();
    final seenByOwner = mergeSharedState(before, rejected);
    final task =
        ((seenByOwner["handovers"] as List).single["tasks"] as List).single;
    expect(task["status"], "rejected");

    store.reassignTask(sara, id, store.handover(id)!.tasks.first.id, second.id);
    expect(store.inboxFor(second).toAccept, hasLength(1));
    store.acceptTask(second, id, store.handover(id)!.tasks.first.id, "تم");
    expect(store.handover(id)!.status, "pending_manager");
    expect(store.inboxFor(fahad).managerQueue, hasLength(1));
    store.managerDecision(fahad, id, true, "");
    expect(store.handover(id)!.status, "pending_hr");
    expect(store.inboxFor(hind).hrQueue, hasLength(1));
    store.hrDecision(hind, id, true, "معتمد");
    expect(store.handover(id)!.status, "approved");
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
