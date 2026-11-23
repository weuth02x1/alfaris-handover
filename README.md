# تسليم المهام — مجموعة الفارس (ASP.NET)

نظام إخلاء الطرف وتسليم المهام. الرمز يُرسل من **سيرفر ASP.NET** إلى مشروع Supabase، وResend يوصّله على الإيميل. الرمز لا يظهر في الصفحة. التطبيق **لا يُرفع على Grok**.

الدومين: `http://handover.alfarisgrp.com` (من دون SSL)

مشروع Auth: `https://sfshhcfjowiptefesqgp.supabase.co`

## البريد (Supabase + Resend)

المسار الوحيد للدخول الحقيقي:

1. المستخدم يكتب إيميله في الموقع.
2. السيرفر يستدعي `POST /auth/v1/otp` على مشروع Supabase مع `redirect_to=http://handover.alfarisgrp.com`.
3. SMTP داخل Supabase (Resend: `smtp.resend.com`) يرسل الرسالة. حقل From لازم يكون على دومين المجموعة بعد SPF/DKIM.
4. المستخدم يكتب الرمز هنا. السيرفر يتحقق عبر `/auth/v1/verify`.

إذا ما انضبط مفتاح Supabase، السيرفر يستخدم `RESEND_API_KEY` مباشرة (ومن `noreply@alfarisgrp.com` أو `RESEND_FROM`)، أو SMTP الشركة.

على IIS عيّن هذه المتغيرات (القيم من لوحة Cursor / Supabase / Resend، مو داخل الملفات):

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `RESEND_API_KEY`
- `RESEND_FROM` (مثال: `Alfaris Group <noreply@alfarisgrp.com>`)
- اختياري إذا SMTP مباشر: `SMTP_HOST` `SMTP_PORT` `SMTP_USER` `SMTP_PASS` `SMTP_FROM`

في لوحة Supabase Authentication:

- Site URL: `http://handover.alfarisgrp.com`
- Redirect URLs: `http://handover.alfarisgrp.com/**`
- SMTP: Resend، ومن عنوان على `alfarisgrp.com` مو Grok.

## تشغيل محلي

يلزم .NET 8.

```bash
cd aspnet
dotnet restore
dotnet run
```

من غير مفاتيح البريد يظهر دخول تجريبي للتطوير فقط. مع المفاتيح، الرمز يجي على الإيميل.

## HTTP من دون SSL

الموقع يشتغل على `http://handover.alfarisgrp.com` بدون شهادة. التطبيق لا يحوّل إلى HTTPS ولا يرسل HSTS حتى ما ينرمي المتصفح على شهادة `*.websitewelcome.com`.

```bash
cd aspnet
dotnet publish -c Release -o C:\inetpub\alfaris-handover
```

## الدورة

الموارد البشرية تبدأ الطلب → الموظف يعبّئ المهام → المستلم يقبل أو يرفض → المدير ثم الموارد البشرية يعتمدون → إيصال مقفل للطباعة.
