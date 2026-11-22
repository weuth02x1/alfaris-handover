# تسليم المهام — مجموعة الفارس

تطبيق Flutter لإخلاء الطرف وتسليم المهام: الموظف يكتب مهامه، المستلم يوافق أو يرفض، ثم المدير والموارد البشرية يعتمدون.

رمز الدخول يُرسل عبر **Resend**. المفتاح يبقى على الخادم في `/api/otp` ولا يُوضع داخل تطبيق الويب.

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

## ربط الإرسال على GitHub Pages

1. أضف `RESEND_API_KEY` (و`RESEND_FROM` إن كان عندك نطاق موثّق) من النموذج الآمن أو أسرار GitHub.
2. انشر مسار `/api/otp` (Next.js أو Cloudflare Worker في `workers/otp.js`).
3. ضع عنوان الـ API في GitHub variable اسمه `MAIL_API_URL`، مثل `https://example.com`.
4. النطاق المجاني `onboarding@resend.dev` يرسل فقط لإيميل حساب Resend إلى أن توثّق دومين المجموعة.

بدون `MAIL_API_URL` يبقى الرمز ظاهراً في صفحة الدخول للتجربة.

## المستودع

https://github.com/weuth02x1/alfaris-handover
