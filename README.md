# تسليم المهام — مجموعة الفارس

تطبيق لإخلاء الطرف وتسليم المهام: الموظف يكتب مهامه، المستلم يوافق أو يرفض، ثم المدير والموارد البشرية يعتمدون.

## الرابط الذي يعمل الآن

https://weuth02x1.github.io/alfaris-handover/

`handover.alfarisgrp.com` ما يفتح لأن الـ DNS يحوّله لاستضافة cPanel (`websitewelcome.com`) مو لـ GitHub. في GoDaddy احذف أي سجل A للاسم `handover`، ولا تنشئ ساب دومين من cPanel، ثم أضف:

| النوع | الاسم | القيمة |
| --- | --- | --- |
| CNAME | `handover` | `weuth02x1.github.io` |

بعد ما السجل ينتشر نرجع نفعّل HTTPS على الدومين.

## تشغيل محلي

```bash
cd flutter
flutter pub get
flutter run -d chrome
```

## المستودع

https://github.com/weuth02x1/alfaris-handover
