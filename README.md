# تسليم المهام — مجموعة الفارس

تطبيق فلاتر لإخلاء الطرف وتسليم المهام: الموظف يكتب مهامه، المستلم يوافق أو يرفض، ثم المدير والموارد البشرية يعتمدون.

## الموقع

الدومين: https://handover.alfarisgrp.com

ما دام الـ DNS لسه يشير لسيرفر cPanel القديم، استخدم مؤقتاً:

https://weuth02x1.github.io/alfaris-handover/

## ربط الدومين (GoDaddy)

`handover.alfarisgrp.com` حالياً يفتح استضافة `websitewelcome.com` مو GitHub. في DNS احذف أي سجل A للاسم `handover` (خصوصاً `192.185.30.74`)، ولا تنشئ ساب دومين من cPanel، ثم أضف:

| النوع | الاسم | القيمة |
| --- | --- | --- |
| CNAME | `handover` | `weuth02x1.github.io` |

بعد انتشار السجل شهادة HTTPS تصدر من GitHub.

## تشغيل محلي

```bash
cd flutter
flutter pub get
flutter run -d chrome
```

## المستودع

https://github.com/weuth02x1/alfaris-handover
