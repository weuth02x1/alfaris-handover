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
    expect(find.text("حسابات محفوظة"), findsOneWidget);
    expect(find.text("نظام تسليم العهد والمهام"), findsWidgets);
  });

  testWidgets("phone and laptop can start a request and open the calendar", (
    tester,
  ) async {
    for (final size in const [Size(390, 844), Size(1280, 800)]) {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = AppStore();
      await tester.pumpWidget(HandoverApp(store: store));
      await tester.pump();
      final sarah = find.textContaining("sarah.alqahtani").first;
      await tester.ensureVisible(sarah);
      await tester.tap(sarah);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text("رفع طلب"), findsOneWidget);
      await tester.tap(find.text("رفع طلب"));
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
