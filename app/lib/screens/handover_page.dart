import "package:material_ui/material_ui.dart";

import "../directory.dart";
import "../main.dart";
import "../models.dart";
import "report_page.dart";

class HandoverPage extends StatefulWidget {
  const HandoverPage({super.key, required this.id});

  final String id;

  @override
  State<HandoverPage> createState() => _HandoverPageState();
}

class _HandoverPageState extends State<HandoverPage> {
  late final notes = TextEditingController();
  late List<HandoverTask> draft;
  final comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    final h = StoreScope.of(context).must(widget.id);
    notes.text = h.generalNotes;
    draft = [
      for (final t in h.tasks)
        HandoverTask(id: t.id, title: t.title, details: t.details, assigneeId: t.assigneeId, status: t.status, rejectComment: t.rejectComment),
    ];
    if (draft.isEmpty) {
      draft.add(HandoverTask(id: "t${DateTime.now().microsecondsSinceEpoch}", title: "", details: "", assigneeId: ""));
    }
  }

  @override
  void dispose() {
    notes.dispose();
    comment.dispose();
    super.dispose();
  }

  void flash(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final h = store.must(widget.id);
        final me = store.user!;
        final owner = byId(h.employeeId)!;
        final manager = owner.managerId == null ? null : byId(owner.managerId!);
        final canEdit = me.id == owner.id && (h.status == HandoverStatus.draft || h.status == HandoverStatus.returned);
        final colleagues = store.colleaguesOf(owner);

        return Scaffold(
          appBar: AppBar(
            title: Text("${h.number} · ${owner.nameAr}"),
            actions: [
              if (h.status == HandoverStatus.approved)
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportPage(id: h.id))),
                  child: const Text("التقرير", style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text("${owner.jobTitleAr} · ${owner.departmentAr}"),
              Text("${reasonLabel(h.type)} · ${statusLabel(h.status)}"),
              if (h.returnComment != null) ...[
                const SizedBox(height: 8),
                Material(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text("معاد: ${h.returnComment}"),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: notes,
                enabled: canEdit,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "ملاحظات عامة"),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text("المهام", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (canEdit)
                    TextButton(
                      onPressed: () => setState(() {
                        draft.add(HandoverTask(id: "t${DateTime.now().microsecondsSinceEpoch}", title: "", details: "", assigneeId: ""));
                      }),
                      child: const Text("أضف مهمة"),
                    ),
                ],
              ),
              for (final task in (canEdit ? draft : h.tasks)) _taskCard(context, h, me, owner, canEdit, colleagues, task),
              const SizedBox(height: 12),
              if (canEdit)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        try {
                          store.saveForm(h.id, notes.text, draft, submit: false);
                          flash("انحفظت المسودة.");
                        } catch (e) {
                          flash(e);
                        }
                      },
                      child: const Text("حفظ"),
                    ),
                    FilledButton(
                      onPressed: () {
                        try {
                          store.saveForm(h.id, notes.text, draft, submit: true);
                          flash("أرسلنا المهام للمستلمين.");
                        } catch (e) {
                          flash(e);
                        }
                      },
                      child: const Text("أرسل للمستلمين"),
                    ),
                  ],
                ),
              if (h.status == HandoverStatus.pendingManager && manager?.id == me.id) _decision("اعتماد المدير", store.managerDecide),
              if (h.status == HandoverStatus.pendingHr && me.role == Role.hr && me.id != owner.id) _decision("اعتماد الموارد البشرية", store.hrDecide),
            ],
          ),
        );
      },
    );
  }

  Widget _taskCard(
    BuildContext context,
    Handover h,
    Employee me,
    Employee owner,
    bool canEdit,
    List<Employee> colleagues,
    HandoverTask task,
  ) {
    final store = StoreScope.of(context);
    final assignee = task.assigneeId.isEmpty ? null : byId(task.assigneeId);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canEdit) ...[
              TextField(
                controller: TextEditingController(text: task.title),
                decoration: const InputDecoration(labelText: "عنوان المهمة"),
                onChanged: (v) => task.title = v,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: task.details),
                decoration: const InputDecoration(labelText: "التفاصيل"),
                onChanged: (v) => task.details = v,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: task.assigneeId.isEmpty ? null : task.assigneeId,
                items: [
                  for (final person in colleagues)
                    DropdownMenuItem(value: person.id, child: Text("${person.nameAr} · ${person.jobTitleAr}")),
                ],
                onChanged: (v) => setState(() => task.assigneeId = v ?? ""),
                decoration: const InputDecoration(labelText: "المستلم"),
              ),
            ] else ...[
              Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(task.details),
              Text("المستلم: ${assignee?.nameAr ?? "-"}"),
              Text("الحالة: ${task.status.name}"),
              if (task.rejectComment.isNotEmpty) Text("سبب الرفض: ${task.rejectComment}"),
            ],
            if (task.status == TaskStatus.pending && task.assigneeId == me.id)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(onPressed: () => store.acceptTask(h.id, task.id), child: const Text("أوافق")),
                    OutlinedButton(
                      onPressed: () async {
                        comment.text = "";
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("سبب الرفض"),
                            content: TextField(controller: comment, decoration: const InputDecoration(hintText: "اكتب السبب")),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("رفض")),
                            ],
                          ),
                        );
                        if (ok == true) {
                          try {
                            store.rejectTask(h.id, task.id, comment.text);
                          } catch (e) {
                            flash(e);
                          }
                        }
                      },
                      child: const Text("أرفض"),
                    ),
                  ],
                ),
              ),
            if (task.status == TaskStatus.rejected && me.id == owner.id)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownButtonFormField<String>(
                  items: [
                    for (final person in colleagues.where((p) => p.id != task.assigneeId))
                      DropdownMenuItem(value: person.id, child: Text("أعد الإسناد إلى ${person.nameAr}")),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    try {
                      store.reassignTask(h.id, task.id, v);
                    } catch (e) {
                      flash(e);
                    }
                  },
                  decoration: const InputDecoration(labelText: "موظف بديل"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _decision(String title, void Function(String id, {required bool approve, String comment}) decide) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(controller: comment, decoration: const InputDecoration(labelText: "تعليق")),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () {
                    try {
                      decide(widget.id, approve: true, comment: comment.text);
                    } catch (e) {
                      flash(e);
                    }
                  },
                  child: const Text("اعتماد"),
                ),
                OutlinedButton(
                  onPressed: () {
                    try {
                      decide(widget.id, approve: false, comment: comment.text);
                    } catch (e) {
                      flash(e);
                    }
                  },
                  child: const Text("إعادة للموظف"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
