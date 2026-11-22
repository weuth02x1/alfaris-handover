import "package:material_ui/material_ui.dart";

import "../models.dart";
import "../store.dart";
import "../theme.dart";
import "../widgets/brand.dart";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final name = TextEditingController();
  final employeeNo = TextEditingController();
  final jobTitle = TextEditingController();
  final code = TextEditingController();
  String departmentId = "D-HR";
  bool signup = false;
  bool codeStep = false;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    email.addListener(() => setState(() {}));
    code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    email.dispose();
    name.dispose();
    employeeNo.dispose();
    jobTitle.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> sendCode({required bool create}) async {
    final store = StoreScope.of(context);
    final t = store.t;
    setState(() {
      error = null;
      busy = true;
    });
    try {
      if (create) {
        await store.register(
          email: email.text,
          name: name.text,
          employeeNo: employeeNo.text,
          jobTitle: jobTitle.text,
          departmentId: departmentId,
        );
      } else {
        await store.requestOtp(email.text);
      }
      if (mounted) {
        setState(() {
          codeStep = true;
          busy = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        final errCode = e is WorkflowException ? e.code : e.toString();
        error = t.error(errCode);
        if (errCode == "notFoundEmail") signup = true;
      });
    }
  }

  Future<void> confirm() async {
    final store = StoreScope.of(context);
    final t = store.t;
    setState(() {
      error = null;
      busy = true;
    });
    try {
      await store.verifyOtp(email.text, code.text);
      if (mounted) setState(() => busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = t.error(e is WorkflowException ? e.code : e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = store.t;
    return Directionality(
      textDirection: t.dir,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 880;
            final brand = Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: navy)),
                const Positioned(left: -64, bottom: -64, child: BrandWatermark(size: 320)),
                const Positioned(right: -80, top: -80, child: BrandWatermark(size: 280, angle: 0.2)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandLockup(height: 72),
                      const Spacer(),
                      Container(width: 64, height: 1, color: gold),
                      const SizedBox(height: 16),
                      Text(t.appName, style: const TextStyle(color: cream, fontSize: 34, fontWeight: FontWeight.w600, height: 1.3)),
                      const SizedBox(height: 12),
                      Text(t.appTagline, style: const TextStyle(color: gold, fontSize: 14, height: 1.6)),
                      const Spacer(),
                      const Text("ALFARIS GROUP", style: TextStyle(color: gold, letterSpacing: 3.5, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            );
            final form = Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(onPressed: store.toggleLocale, child: Text(t.navLanguage)),
                      ),
                      Text(t.loginTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: navy)),
                      const SizedBox(height: 6),
                      Text(t.loginSubtitle, style: const TextStyle(color: mutedFg, fontSize: 14)),
                      const SizedBox(height: 20),
                      Text(t.email, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(hintText: t.emailPh),
                      ),
                      if (signup && !codeStep) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            border: Border.all(color: line),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.signupTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(t.signupHint, style: const TextStyle(color: mutedFg, fontSize: 13)),
                              const SizedBox(height: 12),
                              Text(t.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(controller: name, decoration: InputDecoration(hintText: t.namePh)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t.employeeNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        TextField(controller: employeeNo, decoration: InputDecoration(hintText: t.employeeNoPh)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t.jobTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        TextField(controller: jobTitle, decoration: InputDecoration(hintText: t.jobTitlePh)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(t.department, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              DropdownMenu<String>(
                                initialSelection: departmentId,
                                expandedInsets: EdgeInsets.zero,
                                dropdownMenuEntries: [
                                  DropdownMenuEntry(value: "D-HR", label: t.deptHr),
                                  DropdownMenuEntry(value: "D-TA", label: t.deptTalent),
                                  DropdownMenuEntry(value: "D-ITD", label: t.deptIt),
                                ],
                                onSelected: (v) => setState(() => departmentId = v ?? "D-HR"),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (codeStep) ...[
                        const SizedBox(height: 16),
                        Text(t.codeSent, style: const TextStyle(color: mutedFg, fontSize: 14)),
                        const SizedBox(height: 6),
                        Text(t.checkInbox, style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 12),
                        Text(t.code, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: code,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, letterSpacing: 10, fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(counterText: ""),
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: const TextStyle(color: Color(0xFFBE123C), fontSize: 13)),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (codeStep) ...[
                            FilledButton(
                              onPressed: busy || code.text.trim().length < 6 ? null : confirm,
                              child: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cream)) : Text(t.confirm),
                            ),
                            OutlinedButton(
                              onPressed: busy ? null : () => sendCode(create: false),
                              child: Text(t.resend),
                            ),
                          ] else if (signup)
                            FilledButton(
                              onPressed: busy || email.text.trim().isEmpty ? null : () => sendCode(create: true),
                              child: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cream)) : Text(t.createAndSend),
                            )
                          else
                            FilledButton(
                              onPressed: busy || email.text.trim().isEmpty ? null : () => sendCode(create: false),
                              child: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cream)) : Text(t.sendCode),
                            ),
                        ],
                      ),
                      if (!codeStep)
                        TextButton(
                          onPressed: () => setState(() {
                            signup = !signup;
                            error = null;
                          }),
                          child: Text(signup ? t.haveAccount : t.createAccount),
                        ),
                    ],
                  ),
                ),
              ),
            );
            if (!wide) {
              return ListView(children: [SizedBox(height: 280, child: brand), form]);
            }
            return Row(children: [Expanded(child: brand), Expanded(child: form)]);
          },
        ),
      ),
    );
  }
}
