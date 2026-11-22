import "package:material_ui/material_ui.dart";

import "../directory.dart";
import "../models.dart";
import "../main.dart";
import "../theme.dart";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(text: "sarah.alqahtani@alfaris.example");
  String? error;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  void submit() {
    setState(() => error = null);
    try {
      StoreScope.of(context).signIn(email.text);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 880;
          final brand = Container(
            color: navy,
            padding: const EdgeInsets.all(32),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ALFARIS GROUP", style: TextStyle(color: gold, fontSize: 18, letterSpacing: 3)),
                SizedBox(height: 24),
                Text("نظام تسليم العهد والمهام", style: TextStyle(color: cream, fontSize: 28, fontWeight: FontWeight.w600)),
                SizedBox(height: 12),
                Text("أتمتة إيصال تسليم المهام عند الإجازة أو إنهاء الخدمة", style: TextStyle(color: gold)),
              ],
            ),
          );
          final form = Padding(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Text("تسجيل الدخول", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text("هذا إصدار GitHub التجريبي. ادخل بإيميل أحد الموظفين في الدليل."),
                    const SizedBox(height: 20),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: "الإيميل"),
                      onSubmitted: (_) => submit(),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(onPressed: submit, child: const Text("دخول")),
                    const SizedBox(height: 24),
                    const Text("حسابات للتجربة", style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final person in employees)
                          ActionChip(
                            label: Text("${person.nameAr} · ${person.role == Role.hr ? "موارد بشرية" : person.jobTitleAr}"),
                            onPressed: () {
                              email.text = person.email;
                              submit();
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          if (!wide) {
            return ListView(children: [SizedBox(height: 220, child: brand), form]);
          }
          return Row(children: [Expanded(child: brand), Expanded(child: form)]);
        },
      ),
    );
  }
}
