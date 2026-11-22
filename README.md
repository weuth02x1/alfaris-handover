# تسليم المهام — مجموعة الفارس

تطبيق Flutter لإخلاء الطرف وتسليم المهام: الموظف يكتب مهامه، المستلم يوافق أو يرفض، ثم المدير والموارد البشرية يعتمدون.

رمز الدخول يُرسل عبر **Resend** من الخادم بعد تسجيل الدخول في Cursor. المفتاح لا يُوضع داخل تطبيق الويب.

## الرابط العام

https://weuth02x1.github.io/alfaris-handover/

حسابات الدليل التجريبي: `sarah.alqahtani@alfaris.example`، `hind.alghamdi@alfaris.example`، `fahad.alotaibi@alfaris.example`.

## تشغيل الواجهة

```bash
cd flutter
flutter pub get
flutter run -d chrome
```

مع خادم Next.js الذي يرسل من Resend:

```bash
npm install
npm run dev
```

ثم ابنِ الواجهة على نفس الجهاز:

```bash
cd flutter
flutter run -d chrome --dart-define=MAIL_API_URL=http://127.0.0.1:4317
```

## الإيميل

على التطبيق المنشور: اطلب الرمز من صفحة الدخول (أو سجّل حسابك أولاً إن كان إيميلك جديد). شوف الوارد والسبام.

النطاق المجاني `onboarding@resend.dev` يرسل غالباً فقط لإيميل حساب Resend إلى أن يتوثق دومين المجموعة.

موقع GitHub Pages يبقى بواجهة التجربة (الرمز يظهر على الشاشة) ما لم يُضبط خادم بريد محمي بمفتاح، وليس من المتصفح.

## المستودع

https://github.com/weuth02x1/alfaris-handover
