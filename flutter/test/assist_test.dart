import "package:alfaris_handover/assist.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("suggestion parser keeps plain tasks and drops padding", () {
    final tasks = TaskSuggestion.fromBody({
      "tasks": [
        {"title": "تسليم ملفات المشروع", "details": "المجلد المشترك وآخر نسخة."},
        {"title": "لا", "details": "قصيرة"},
        "نص زيادة",
        {"title": "إغلاق الصلاحيات", "details": "ص" * 500},
        {"title": "تسليم العهد", "details": ""},
        {"title": "متابعة التذاكر المفتوحة", "details": "ما انقفل منها."},
        {"title": "جرد الأجهزة", "details": "لابتوب وشاشة."},
        {"title": "مهمة سادسة زيادة", "details": "ما تنضاف."},
      ],
    });

    expect(tasks.map((task) => task.title), [
      "تسليم ملفات المشروع",
      "إغلاق الصلاحيات",
      "تسليم العهد",
      "متابعة التذاكر المفتوحة",
      "جرد الأجهزة",
    ]);
    expect(tasks[1].details.length, 400);
    expect(TaskSuggestion.fromBody({"nope": true}), isEmpty);
  });
}
