import "dart:ui";

import "package:alfaris_handover/main.dart";
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
}
