import "package:material_ui/material_ui.dart";

import "../i18n.dart";
import "../store.dart";
import "../theme.dart";
import "../widgets/brand.dart";

class ReportPage extends StatelessWidget {
  const ReportPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListenableBuilder(listenable: store, builder: (context, _) => _body(context, store));
  }

  Widget _body(BuildContext context, AppStore store) {
    final user = store.user!;
    final t = store.t;
    final h = store.handover(id);
    if (h == null) return Scaffold(body: Center(child: Text(t.handoverNotFound)));
    final access = store.access(user, h);
    if (!(access.isOwner || access.isManager || access.isHr)) {
      return Scaffold(body: Center(child: Text(t.notAllowed)));
    }
    if (h.status != "approved") {
      return Directionality(
        textDirection: t.dir,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.reportNotFinal),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(t.reportBack)),
              ],
            ),
          ),
        ),
      );
    }
    final manager = store.person(h.managerApproval?.byId);
    final hrUser = store.person(h.hrApproval?.byId);
return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: pageBg,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_forward, size: 16), label: Text(t.reportBack)),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              color: navy,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: const Row(
                                children: [
                                  BrandLockup(height: 44),
                                  Spacer(),
                                  Text("ALFARIS GROUP", style: TextStyle(color: gold, letterSpacing: 2, fontSize: 11)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: navy, width: 2))),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("إيصال تسليم المهام", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy)),
                                        Text("Employee Handover Receipt", style: TextStyle(color: mutedFg), textDirection: TextDirection.ltr),
                                      ],
                                    ),
                                  ),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("No. ${h.number}", style: const TextStyle(fontFamily: "monospace", fontWeight: FontWeight.w700)),
                                        Text("Request ${h.requestRef}", style: const TextStyle(fontFamily: "monospace")),
                                        Text("Issued ${t.date(h.finalizedAt, withTime: true)}"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _Section(ar: "بيانات الموظف", en: "Employee details"),
                            _KV(ar: "اسم الموظف", en: "Employee name", valueAr: h.employee.nameAr, valueEn: h.employee.nameEn),
                            _KV(ar: "الرقم الوظيفي", en: "Employee ID", valueAr: h.employee.id),
                            _KV(ar: "المسمى الوظيفي", en: "Job title", valueAr: h.employee.jobTitleAr, valueEn: h.employee.jobTitleEn),
                            _KV(ar: "المدير المباشر", en: "Direct manager", valueAr: h.employee.managerNameAr.isEmpty ? "—" : h.employee.managerNameAr, valueEn: h.employee.managerNameEn),
                            _KV(ar: "الإدارة", en: "Department", valueAr: h.employee.departmentAr, valueEn: h.employee.departmentEn),
                            _KV(ar: "القسم", en: "Section", valueAr: h.employee.sectionAr, valueEn: h.employee.sectionEn),
                            _KV(ar: "سبب الخروج", en: "Reason for leaving", valueAr: I18n("ar").type(h.type), valueEn: I18n("en").type(h.type)),
                            _KV(ar: "آخر يوم عمل", en: "Last working day", valueAr: t.date(h.lastWorkingDay)),
                            if (h.returnDate != null) _KV(ar: "تاريخ العودة", en: "Return date", valueAr: t.date(h.returnDate)),
                            const SizedBox(height: 16),
                            _Section(ar: "المهام المُسلَّمة", en: "Handed-over tasks"),
                            Table(
                              border: TableBorder.all(color: line),
                              columnWidths: const {
                                0: FixedColumnWidth(36),
                                1: FlexColumnWidth(3),
                                2: FlexColumnWidth(2),
                                3: FlexColumnWidth(1.2),
                                4: FlexColumnWidth(1.4),
                              },
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                                  children: [
                                    _th("#"),
                                    _th("المهمة", "Task"),
                                    _th("المستلم", "Recipient"),
                                    _th("الاستحقاق", "Due"),
                                    _th("وقت القبول", "Accepted at"),
                                  ],
                                ),
                                for (var i = 0; i < h.tasks.length; i++)
                                  TableRow(children: [
                                    Padding(padding: const EdgeInsets.all(8), child: Text("${i + 1}", textAlign: TextAlign.center)),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(h.tasks[i].title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        if (h.tasks[i].details.isNotEmpty) Text(h.tasks[i].details, style: const TextStyle(color: mutedFg, fontSize: 12)),
                                        if (h.tasks[i].acceptNote != null) Text("✓ ${h.tasks[i].acceptNote}", style: const TextStyle(color: Color(0xFF065F46), fontSize: 12)),
                                      ]),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(store.person(h.tasks[i].assigneeId)?.nameAr ?? "—"),
                                        Text(store.person(h.tasks[i].assigneeId)?.nameEn ?? "", style: const TextStyle(color: mutedFg, fontSize: 12), textDirection: TextDirection.ltr),
                                        Text(h.tasks[i].assigneeId, style: const TextStyle(fontFamily: "monospace", fontSize: 11, color: mutedFg)),
                                      ]),
                                    ),
                                    Padding(padding: const EdgeInsets.all(8), child: Text(t.date(h.tasks[i].dueDate))),
                                    Padding(padding: const EdgeInsets.all(8), child: Text(t.date(h.tasks[i].acceptedAt, withTime: true))),
                                  ]),
                              ],
                            ),
                            if (h.generalNotes.isNotEmpty)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.all(12),
                                color: const Color(0xFFF8FAFC),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text("ملاحظات عامة · General notes", style: TextStyle(color: mutedFg, fontSize: 12, fontWeight: FontWeight.w700)),
                                  Text(h.generalNotes),
                                ]),
                              ),
                            const SizedBox(height: 16),
                            _Section(ar: "الاعتمادات", en: "Approvals"),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _Sig(roleAr: "الموظف (المُسلِّم)", roleEn: "Employee", nameAr: h.employee.nameAr, nameEn: h.employee.nameEn, at: t.date(h.submittedAt, withTime: true)),
                                _Sig(roleAr: "المدير المباشر", roleEn: "Direct manager", nameAr: manager?.nameAr ?? "—", nameEn: manager?.nameEn ?? "—", at: t.date(h.managerApproval?.at, withTime: true), note: h.managerApproval?.comment),
                                _Sig(roleAr: "الموارد البشرية", roleEn: "Human Resources", nameAr: hrUser?.nameAr ?? "—", nameEn: hrUser?.nameEn ?? "—", at: t.date(h.hrApproval?.at, withTime: true), note: h.hrApproval?.comment),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const Row(children: [
                              Icon(Icons.verified_user_outlined, size: 14, color: navy),
                              SizedBox(width: 6),
                              Expanded(child: Text("هذا المستند صادر آلياً من نظام تسليم المهام ومقفل بعد الاعتماد النهائي، ومحفوظ في ملف الموظف بنظام الموارد البشرية.", style: TextStyle(fontSize: 11, color: mutedFg))),
                            ]),
                            const SizedBox(height: 6),
                            const Align(alignment: Alignment.centerLeft, child: Text("This document was generated by the handover system, locked after final approval, and filed on the employee record in the HR system.", textDirection: TextDirection.ltr, style: TextStyle(fontSize: 11, color: mutedFg))),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text("SHA-256: ${h.documentHash}${h.hrmsDocumentId != null ? "    HRMS doc: ${h.hrmsDocumentId}" : ""}", textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: "monospace", fontSize: 11, color: mutedFg)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _th(String ar, [String? en]) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ar, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        if (en != null) Text(en, style: const TextStyle(fontSize: 10, color: mutedFg)),
      ]),
    );
  }
}
class _Section extends StatelessWidget {
  const _Section({required this.ar, required this.en});
  final String ar;
  final String en;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(ar, style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
          const Spacer(),
          Text(en, style: const TextStyle(fontSize: 12, color: mutedFg), textDirection: TextDirection.ltr),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({required this.ar, required this.en, required this.valueAr, this.valueEn});
  final String ar;
  final String en;
  final String valueAr;
  final String? valueEn;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: line)),
      child: Row(
        children: [
          Container(width: 140, color: const Color(0xFFF8FAFC), padding: const EdgeInsets.all(8), child: Text(ar, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text(valueAr))),
          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text(valueEn ?? "", textDirection: TextDirection.ltr, style: const TextStyle(color: mutedFg)))),
          Container(width: 140, color: const Color(0xFFF8FAFC), padding: const EdgeInsets.all(8), child: Text(en, textAlign: TextAlign.end, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        ],
      ),
    );
  }
}

class _Sig extends StatelessWidget {
  const _Sig({required this.roleAr, required this.roleEn, required this.nameAr, required this.nameEn, required this.at, this.note});
  final String roleAr;
  final String roleEn;
  final String nameAr;
  final String nameEn;
  final String at;
  final String? note;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: line), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("$roleAr · $roleEn", style: const TextStyle(fontSize: 12, color: mutedFg)),
        const SizedBox(height: 4),
        Text(nameAr, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(nameEn, textDirection: TextDirection.ltr, style: const TextStyle(color: mutedFg)),
        const SizedBox(height: 8),
        Text("✓ $at", style: const TextStyle(color: Color(0xFF047857), fontSize: 11)),
        if (note != null) Text(note!, style: const TextStyle(fontSize: 11, color: mutedFg)),
      ]),
    );
  }
}
