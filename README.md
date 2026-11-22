# تسليم المهام — مجموعة الفارس

تطبيق لإخلاء الطرف وتسليم المهام: الموظف يكتب مهامه، المستلم يوافق أو يرفض، ثم المدير والموارد البشرية يعتمدون.

## الدومين

https://handover.alfarisgrp.com

أضف في DNS الدومين `alfarisgrp.com` هذا السجل ثم انتظر التفعيل:

| النوع | الاسم | القيمة |
| --- | --- | --- |
| CNAME | `handover` | `weuth02x1.github.io` |

في Resend أضف الدومين `alfarisgrp.com` وألصق سجلات التحقق، وعيّن المرسل `Alfaris Group <noreply@alfarisgrp.com>`. في سوبربيس SMTP غيّر عنوان المرسل لنفس الإيميل (مو Gmail) وUsername: `resend`.

رمز الدخول يُرسل عبر هذا الدومين بعد ربط DNS. قبل اكتمال الربط يمكن فتح النسخة المؤقتة:

https://weuth02x1.github.io/alfaris-handover/

## تشغيل محلي

```bash
cd flutter
flutter pub get
flutter run -d chrome
```

## المستودع

https://github.com/weuth02x1/alfaris-handover
