# تسليم المهام — مجموعة الفارس

تطبيق لإخلاء الطرف وتسليم المهام: الموظف يكتب مهامه، المستلم يوافق أو يرفض، ثم المدير والموارد البشرية يعتمدون.

## الرابط العام

https://weuth02x1.github.io/alfaris-handover/

رمز الدخول يُرسل من `AlfarisHandOver` عبر SMTP (`smtp.resend.com`) المضبوط في سوبربيس.

على GitHub: أضف أسرار المستودع `SUPABASE_URL` و`SUPABASE_ANON_KEY` (مفتاح anon العام من إعدادات سوبربيس) ثم أعد تشغيل GitHub Pages. بدونها يظهر الرمز على الشاشة للتجربة.

حسابات الدليل التجريبي: `sarah.alqahtani@alfaris.example`، `hind.alghamdi@alfaris.example`، `fahad.alotaibi@alfaris.example`.

## تشغيل محلي

```bash
cd flutter
flutter pub get
flutter run -d chrome
```

## المستودع

https://github.com/weuth02x1/alfaris-handover
