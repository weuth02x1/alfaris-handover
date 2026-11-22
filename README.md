# تسليم المهام — مجموعة الفارس (ASP.NET)

نظام إخلاء الطرف وتسليم المهام لموظفي مجموعة الفارس: الموارد البشرية تبدأ الطلب المعتمد من Menaitech، الموظف يعبّئ مهامه ويختار المستلم، المستلم يقبل أو يرفض، ثم يعتمد المدير المباشر ثم الموارد البشرية، وبعد الاعتماد يُقفل إيصال للطباعة.

الدومين المقصود: `https://handover.alfarisgrp.com`

هذا تطبيق **ASP.NET Core 8** (Razor Pages). لا يُنشر على GitHub Pages ولا على استضافة Grok. السيرفر الحالي على `192.185.30.74` (cPanel / Apache) لا يشغّل ASP.NET.

## تشغيل محلي

يلزم [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0).

```bash
cd aspnet
dotnet restore
dotnet run
```

يفتح على `http://127.0.0.1:4521`.

- الواجهة عربية افتراضياً، مع زر English.
- رمز الدخول يُرسل من السيرفر إلى Supabase Auth (SMTP الذي ضبطته مع Resend). الرمز لا يظهر في الصفحة.
- على جهاز التطوير فقط، إذا لم يُضبط `SUPABASE_ANON_KEY`، يظهر دخول تجريبي لموظفي العينة حتى تختبر الدورة بدون بريد.
- البيانات في الذاكرة: إعادة تشغيل التطبيق تمسح النماذج غير المنشورة في قاعدة.

عيّن المفتاح على الجهاز أو على IIS:

```bash
set SUPABASE_ANON_KEY=...   # Windows
export SUPABASE_ANON_KEY=... # Linux
```

لا تضع المفتاح داخل الملفات ولا في المستودع.

## نشر على IIS وربط الدومين

1. ثبّت [ASP.NET Core 8 Hosting Bundle](https://dotnet.microsoft.com/download/dotnet/8.0) على ويندوز سيرفر.
2. انشر التطبيق:

```bash
cd aspnet
dotnet publish -c Release -o C:\inetpub\alfaris-handover
```

3. في IIS أنشئ موقع `handover.alfarisgrp.com` يشير إلى مجلد النشر، مع ربط HTTPS.
4. أضف متغير البيئة للموقع: `SUPABASE_ANON_KEY` (مفتاح anon/publishable لمشروع Supabase). اختياري: `SUPABASE_URL` إذا تغيّر المشروع.
5. في DNS عند GoDaddy:
   - احذف سجل A للاسم `handover` الذي يشير إلى `192.185.30.74`.
   - لا تضف CNAME إلى GitHub.
   - أضف سجل A (أو CNAME إلى السيرفر الويندوز) يشير إلى IP سيرفر IIS.

بعد انتشار DNS افتح `https://handover.alfarisgrp.com`.

## الدورة

1. موظف موارد بشرية يبدأ إخلاء الطرف من لوحة HR لطلب معتمد.
2. الموظف يضيف المهام ويختار مستلماً من نفس الإدارة ويرسل.
3. المستلم يقبل أو يرفض مع سبب. عند الرفض يحوّل الموظف المهمة لشخص آخر.
4. بعد قبول الكل يعتمد المدير، ثم تعتمد الموارد البشرية.
5. يُقفل الإيصال وبصمته SHA-256 ويُطبع من صفحة التقرير.

الأقسام الحالية: الموارد البشرية، استقطاب المواهب، تطوير تقنية المعلومات.

بيانات Menaitech في هذه النسخة تجريبية حتى يُضبط رابط الـ API.

## البريد

الرمز يُرسل عبر `POST https://sfshhcfjowiptefesqgp.supabase.co/auth/v1/otp` من السيرفر فقط، ثم التحقق عبر `/auth/v1/verify`. اجعل From في Supabase SMTP على دومين المجموعة بعد ضبط SPF/DKIM مع Resend.
