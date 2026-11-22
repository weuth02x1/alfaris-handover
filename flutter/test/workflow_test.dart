import "package:alfaris_handover/directory.dart";
import "package:alfaris_handover/models.dart";
import "package:alfaris_handover/store.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("OTP sign-in then full clearance cycle", () async {
    final store = AppStore();
    await store.requestOtp("hind.alghamdi@alfaris.example");
    expect(store.lastOtpCode, hasLength(6));
    await store.verifyOtp("hind.alghamdi@alfaris.example", store.lastOtpCode!);
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

    final hind = mockEmployees.firstWhere((e) => e.id == "30115");
    store.user = hind;
    store.hrDecision(hind, id, true, "معتمد");
    expect(store.handover(id)!.status, "approved");
    expect(store.handover(id)!.documentHash, isNotNull);
  });

  test("signup and OTP work for a new personal email", () async {
    final store = AppStore();
    await store.requestOtp("shahad0x66@gmail.com");
    expect(store.lastOtpCode, hasLength(6));
    await store.verifyOtp("shahad0x66@gmail.com", store.lastOtpCode!);
    expect(store.user?.email, "shahad0x66@gmail.com");
  });
}
