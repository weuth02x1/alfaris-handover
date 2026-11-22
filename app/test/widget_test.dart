import "dart:ui";
import "package:alfaris_handover/main.dart";
import "package:alfaris_handover/store.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("shows sign-in", (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(HandoverApp(store: AppStore()));
    expect(find.text("تسجيل الدخول"), findsOneWidget);
  });
}
