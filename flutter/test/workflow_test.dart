import "package:alfaris_handover/auth_mail.dart";
import "package:alfaris_handover/directory.dart";
import "package:alfaris_handover/i18n.dart";
import "package:alfaris_handover/models.dart";
import "package:alfaris_handover/store.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("clearance cycle after a signed-in employee", () {
    final store = AppStore();
    final hind = mockEmployees.firstWhere((e) => e.id == "30115");
    store.signInForTest(hind);
    expect(store.user?.id, "30115");

    final id = store.initiateClearance(store.user!, "ANN-2026-0412");
    final sarah = mockEmployees.firstWhere((e) => e.id == "10518");
    store.user = sarah;
    store.saveForm(
      sarah,
      id,
      generalNotes: "سلمت صلاحيات Git للفريق",
      tasks: [
        HandoverTask(
          id: "",
          title: "متابعة مشروع ترقية نظام الرواتب",
          details: "الملفات على الشبكة الداخلية",
          assigneeId: "10530",
          status: "draft",
        ),
      ],
      submit: true,
    );
    expect(store.handover(id)!.status, "pending_acceptance");

    final abdullah = mockEmployees.firstWhere((e) => e.id == "10530");
    store.user = abdullah;
    store.acceptTask(abdullah, id, store.handover(id)!.tasks.first.id, "تم الاستلام");
    expect(store.handover(id)!.status, "pending_manager");

    final fahad = mockEmployees.firstWhere((e) => e.id == "10501");
    store.user = fahad;
    store.managerDecision(fahad, id, true, "");
    expect(store.handover(id)!.status, "pending_hr");

    store.user = hind;
    store.hrDecision(hind, id, true, "معتمد");
    expect(store.handover(id)!.status, "approved");
    expect(store.handover(id)!.documentHash, isNotNull);
  });

  test("sign-in without mail configured does not invent a local code", () async {
    final store = AppStore();
    expect(AuthMail.enabled, isFalse);
    await expectLater(
      store.requestOtp("hind.alghamdi@alfaris.example"),
      throwsA(isA<WorkflowException>().having((e) => e.code, "code", "mailFailed")),
    );
    expect(I18n("ar").error("mailFailed"), isNot(contains("mailFailed")));
    expect(I18n("ar").error("mailerDown"), contains("SMTP"));
    expect(store.lastOtpCode, isNull);
    expect(store.user, isNull);
  });

  test("OTP redirect points at the live site, not localhost", () {
    expect(AuthMail.otpUri().queryParameters["redirect_to"], contains("alfaris-handover"));
    expect(AuthMail.otpUri().toString(), isNot(contains("localhost")));
    expect(siteUrl, isNot(contains("localhost")));
  });
}
