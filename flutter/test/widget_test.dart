import "dart:ui";

import "package:alfaris_handover/i18n.dart";
import "package:alfaris_handover/main.dart";
import "package:alfaris_handover/models.dart";
import "package:alfaris_handover/screens/report_page.dart";
import "package:alfaris_handover/store.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

void main() {
  testWidgets("shows sign-in", (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(HandoverApp(store: AppStore()));
    expect(find.text("تسجيل الدخول"), findsOneWidget);
    expect(find.text("أرسل الرمز على الإيميل"), findsNothing);
    expect(find.textContaining("mailFailed"), findsNothing);
    expect(
      find.text("ما قدرنا نرسل الرمز إلى هذا الإيميل. حاول مرة ثانية."),
      findsNothing,
    );
    expect(find.text("حسابات محفوظة"), findsNothing);
    expect(find.textContaining("sarah.alqahtani"), findsNothing);
    expect(find.textContaining("هند الغامدي"), findsNothing);
    expect(find.text("نظام تسليم العهد والمهام"), findsWidgets);
  });

  testWidgets("phone and laptop can start a request and open the calendar", (
    tester,
  ) async {
    for (final size in const [Size(390, 844), Size(1280, 800)]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = AppStore();
      final manager = store.createAccount(
        email: "fahad@alfaris.test",
        name: "فهد",
        employeeNo: "10501",
        jobTitle: "مدير",
        departmentId: "D-ITD",
        isManager: true,
        managesDepartmentId: "D-ITD",
      );
      final sarah = store.createAccount(
        email: "sarah@alfaris.test",
        name: "سارة",
        employeeNo: "10518",
        jobTitle: "مطورة",
        departmentId: "D-ITD",
        managerId: manager.id,
      );
      store.signInForTest(sarah);
      await tester.pumpWidget(HandoverApp(store: store));
      await tester.pump();
      final button = find.widgetWithText(FilledButton, "رفع طلب");
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining("آخر يوم عمل"), findsOneWidget);
      await tester.tap(find.textContaining("آخر يوم عمل"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(Dialog), findsWidgets);
      final day = find.text("15");
      if (day.evaluate().isNotEmpty) {
        await tester.tap(day.last);
        await tester.pump();
      }
      final ok = find.text("حسنًا");
      if (ok.evaluate().isNotEmpty) {
        await tester.tap(ok);
      } else {
        await tester.tap(find.text("إلغاء"));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets("due and acceptance dates read day month year", (tester) async {
    expect(I18n("ar").day("2026-11-26"), "26/11/2026");
    expect(I18n("ar").clock("2026-11-24T13:39:38.321Z"), "16:39");
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    final hr = store.createAccount(
      email: "hr@alfaris.test",
      name: "شهد",
      employeeNo: "22015",
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
    final id = store.startOwn(
      person,
      type: "annual_leave",
      lastWorkingDay: "2026-11-26",
      returnDate: "2026-12-03",
    );
    final h = store.handover(id)!;
    h.status = "approved";
    h.submittedAt = "2026-11-24T13:15:42.510Z";
    h.finalizedAt = "2026-11-24T13:39:38.321Z";
    h.hrApproval = Approval(
      byId: hr.id,
      at: "2026-11-24T13:39:38.321Z",
      comment: "Accepted",
    );
    h.tasks = [
      HandoverTask(
        id: "erp",
        title: "ERP",
        details: "Epicor",
        assigneeId: "22001",
        status: "pending",
      ),
      HandoverTask(
        id: "net",
        title: "Network",
        details: "Branches",
        assigneeId: hr.id,
        status: "accepted",
        dueDate: "2026-12-03",
        acceptedAt: "2026-11-24T13:20:03.944Z",
      ),
    ];
    store.signInForTest(hr);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(home: ReportPage(id: id)),
      ),
    );
    await tester.pump();
    expect(find.text(I18n("ar").reportWaitsForTasks), findsOneWidget);
    expect(find.text("لم يُقبل"), findsNothing);
    h.tasks.first.status = "accepted";
    h.tasks.first.acceptedAt = "2026-11-24T13:20:03.944Z";
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(home: ReportPage(id: id)),
      ),
    );
    await tester.pump();
    expect(find.text("26/11/2026"), findsWidgets);
    expect(find.text("03/12/2026"), findsWidgets);
    expect(find.text("لم يُقبل"), findsNothing);
    expect(find.text("16:20"), findsWidgets);
    expect(find.text("16:39"), findsWidgets);
    expect(find.textContaining("2026-11-"), findsNothing);
  });
}
