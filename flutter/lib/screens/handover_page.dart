import "package:material_ui/material_ui.dart";

import "../assist.dart";
import "../models.dart";
import "../store.dart";
import "../theme.dart";
import "../widgets/app_header.dart";
import "../widgets/badges.dart";
import "../widgets/step_tracker.dart";

String _personChoice(AppStore store, Employee person) {
  final t = store.t;
  final department = t.pick(person.departmentAr, person.departmentEn);
  final name = store.nameOf(person);
  if (department.isEmpty) return name;
  return "$name · $department";
}

bool _taskOpen(String status) =>
    status == "draft" ||
    status == "pending_acceptance" ||
    status == "pending_manager" ||
    status == "pending_hr" ||
    status == "returned";

class HandoverPage extends StatelessWidget {
  const HandoverPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => _body(context, store),
    );
  }

  Widget _body(BuildContext context, AppStore store) {
    final user = store.user!;
    final t = store.t;
    final h = store.handover(id);
    if (h == null) {
      return Directionality(
        textDirection: t.dir,
        child: AppScaffold(
          user: user,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.handoverNotFound),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    "/",
                    (_) => false,
                  ),
                  child: Text(t.inboxTitle),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final access = store.access(user, h);
    if (!(access.isOwner ||
        access.isManager ||
        access.isHr ||
        access.isRecipient)) {
      return Directionality(
        textDirection: t.dir,
        child: AppScaffold(
          user: user,
          body: Center(child: Text(t.notAllowed)),
        ),
      );
    }
    final editable = access.isOwner && h.status != "approved";
    final colleagues = access.isOwner
        ? store.colleaguesFor(user.id)
        : <Employee>[];
    final rejected = h.tasks.where((x) => x.status == "rejected").toList();
    final acceptedCount = h.tasks.where((x) => x.status == "accepted").length;
    final visible = (access.isOwner || access.isManager || access.isHr)
        ? h.tasks
        : h.tasks
              .where(
                (x) =>
                    x.assigneeId == user.id ||
                    x.rejections.any((r) => r.recipientId == user.id),
              )
              .toList();
    final audit = store.auditFor(h.id);

    return Directionality(
      textDirection: t.dir,
      child: AppScaffold(
        user: user,
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 12 : 28,
            24,
            MediaQuery.sizeOf(context).width < 600 ? 12 : 28,
            48,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          h.number,
                          style: const TextStyle(
                            fontFamily: "monospace",
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: navy,
                          ),
                        ),
                        HandoverStatusBadge(
                          status: h.status,
                          label: t.status(h.status),
                        ),
                        if (h.status == "approved" &&
                            h.tasks.every((task) => task.status == "accepted"))
                          FilledButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              "/handovers/${h.id}/report",
                            ),
                            icon: const Icon(
                              Icons.description_outlined,
                              size: 16,
                            ),
                            label: Text(t.viewReport),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${store.nameSnap(h.employee)} · ${t.type(h.type)} · ${h.requestRef}",
                      style: const TextStyle(color: mutedFg),
                    ),
                    if (t.arrival(h.status).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        t.arrival(h.status),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: StepTracker(
                          status: h.status,
                          labels: [
                            t.status("draft"),
                            t.status("pending_acceptance"),
                            t.status("pending_manager"),
                            t.status("pending_hr"),
                            t.status("approved"),
                          ],
                        ),
                      ),
                    ),
                    if (h.status == "returned" && h.lastReturn != null) ...[
                      const SizedBox(height: 12),
                      _Alert(
                        title:
                            "${t.returnedBanner} ${t.returnedBy} ${store.nameOf(store.person(h.lastReturn!.byId))}",
                        body: h.lastReturn!.comment,
                      ),
                    ],
                    if (access.isOwner && rejected.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _Alert(title: t.rejectedTasksBanner),
                      for (final task in rejected) ...[
                        const SizedBox(height: 8),
                        _Reassign(
                          handoverId: h.id,
                          taskId: task.id,
                          colleagues: colleagues,
                          excluded: task.rejections
                              .map((r) => r.recipientId)
                              .toSet(),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, box) {
                        final cards = [
                          _InfoCard(
                            icon: Icons.person_outline,
                            title: t.employeeInfo,
                            fields: [
                              (t.formName, store.nameSnap(h.employee), false),
                              (t.formId, h.employee.id, true),
                              (
                                t.formJobTitle,
                                t.pick(
                                  h.employee.jobTitleAr,
                                  h.employee.jobTitleEn,
                                ),
                                false,
                              ),
                              (
                                t.formManager,
                                t
                                        .pick(
                                          h.employee.managerNameAr,
                                          h.employee.managerNameEn,
                                        )
                                        .isEmpty
                                    ? t.dash
                                    : t.pick(
                                        h.employee.managerNameAr,
                                        h.employee.managerNameEn,
                                      ),
                                false,
                              ),
                              (
                                t.formDepartment,
                                t.pick(
                                  h.employee.departmentAr,
                                  h.employee.departmentEn,
                                ),
                                false,
                              ),
                              (
                                t.formSection,
                                t.pick(
                                  h.employee.sectionAr,
                                  h.employee.sectionEn,
                                ),
                                false,
                              ),
                            ],
                          ),
                          _InfoCard(
                            icon: Icons.calendar_month_outlined,
                            title: t.clearanceInfo,
                            fields: [
                              (t.requestRef, h.requestRef, true),
                              (t.typeLabel, t.type(h.type), false),
                              (
                                t.lastWorkingDay,
                                t.date(h.lastWorkingDay),
                                false,
                              ),
                              (t.returnDate, t.date(h.returnDate), false),
                              (
                                t.progress,
                                h.tasks.isEmpty
                                    ? t.dash
                                    : t.fmt(t.progressFmt, {
                                        "a": acceptedCount,
                                        "b": h.tasks.length,
                                      }),
                                false,
                              ),
                            ],
                          ),
                        ];
                        if (box.maxWidth < 720)
                          return Column(
                            children: [
                              cards[0],
                              const SizedBox(height: 12),
                              cards[1],
                            ],
                          );
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 12),
                            Expanded(child: cards[1]),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    if (editable)
                      _Editor(
                        key: ValueKey(
                          h.tasks
                              .map(
                                (task) =>
                                    "${task.id}:${task.status}:${task.assigneeId}",
                              )
                              .join("|"),
                        ),
                        handover: h,
                        colleagues: colleagues,
                      )
                    else
                      _ReadonlyTasks(
                        handover: h,
                        visible: visible,
                        access: access,
                        user: user,
                        colleagues: colleagues,
                      ),
                    if (h.status == "pending_manager" && access.isManager) ...[
                      const SizedBox(height: 16),
                      _Decision(kind: "manager", handoverId: h.id),
                    ],
                    if (h.status == "pending_hr" && access.isHr) ...[
                      const SizedBox(height: 16),
                      _Decision(kind: "hr", handoverId: h.id),
                    ],
                    if (access.isOwner || access.isManager || access.isHr) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    t.auditTrail,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              for (final a in audit)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        margin: const EdgeInsets.only(top: 4),
                                        decoration: const BoxDecoration(
                                          color: navy,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              children: [
                                                Text(
                                                  t.audit(a.action),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  "${a.actorId == "system" ? "System" : store.nameOf(store.person(a.actorId))} · ${t.date(a.at, withTime: true)}",
                                                  style: const TextStyle(
                                                    color: mutedFg,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (a.details.isNotEmpty)
                                              Text(
                                                a.details,
                                                style: const TextStyle(
                                                  color: mutedFg,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({required this.title, this.body});
  final String title;
  final String? body;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFECDD3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFF9F1239)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9F1239),
                  ),
                ),
                if (body != null)
                  Text(
                    body!,
                    style: const TextStyle(
                      color: Color(0xFF9F1239),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.fields,
  });
  final IconData icon;
  final String title;
  final List<(String, String, bool)> fields;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final f in fields)
                  SizedBox(
                    width: 180,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.$1,
                          style: const TextStyle(color: mutedFg, fontSize: 12),
                        ),
                        Text(
                          f.$2,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: f.$3 ? "monospace" : null,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor({super.key, required this.handover, required this.colleagues});
  final Handover handover;
  final List<Employee> colleagues;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final notes = TextEditingController(text: widget.handover.generalNotes);
  late List<HandoverTask> tasks;
  bool suggesting = false;

  @override
  void initState() {
    super.initState();
    tasks = widget.handover.tasks.isEmpty
        ? [
            HandoverTask(
              id: "",
              title: "",
              details: "",
              assigneeId: "",
              status: "draft",
            ),
          ]
        : [
            for (final t in widget.handover.tasks)
              HandoverTask(
                id: t.id,
                title: t.title,
                details: t.details,
                dueDate: t.dueDate,
                assigneeId: t.assigneeId,
                status: t.status,
                rejections: t.rejections,
              ),
          ];
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> suggest() async {
    final store = StoreScope.of(context);
    final employee = widget.handover.employee;
    setState(() => suggesting = true);
    try {
      final ideas = await Assist.suggestTasks(
        type: store.t.type(widget.handover.type),
        job: store.t.pick(employee.jobTitleAr, employee.jobTitleEn),
        department: store.t.pick(employee.departmentAr, employee.departmentEn),
        lastWorkingDay: widget.handover.lastWorkingDay,
        notes: notes.text,
        existing: [
          for (final task in tasks)
            if (task.title.trim().isNotEmpty) task.title.trim(),
        ],
      );
      if (!mounted) return;
      if (ideas.isEmpty) {
        setState(() => suggesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(store.t.assistEmpty)),
        );
        return;
      }
      setState(() {
        suggesting = false;
        final kept = [
          for (final task in tasks)
            if (task.title.trim().isNotEmpty || task.details.trim().isNotEmpty)
              task,
        ];
        tasks = [
          ...kept,
          for (final idea in ideas)
            HandoverTask(
              id: "",
              title: idea.title,
              details: idea.details,
              assigneeId: "",
              status: "draft",
            ),
        ];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => suggesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.t.error(e.toString()))),
      );
    }
  }

  void save(bool submit) {
    final store = StoreScope.of(context);
    try {
      store.saveForm(
        store.user!,
        widget.handover.id,
        generalNotes: notes.text,
        tasks: tasks,
        submit: submit,
      );
      final recipients = tasks
          .map((task) => store.person(task.assigneeId))
          .whereType<Employee>()
          .map((person) => person.email)
          .toSet()
          .join("، ");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submit && recipients.isNotEmpty
                ? store.t.sentTo(recipients)
                : store.t.audit(submit ? "form_submitted" : "form_saved"),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(store.t.error(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = store.t;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.tasks,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              t.tasksHint,
              style: const TextStyle(color: mutedFg, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              t.sameDepartmentOnly,
              style: const TextStyle(color: mutedFg, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < tasks.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tasks[i].status == "rejected"
                      ? rejectedTaskBg
                      : muted.withValues(alpha: 0.45),
                  border: Border.all(
                    color: tasks[i].status == "rejected"
                        ? rejectedTaskBorder
                        : line,
                    width: tasks[i].status == "rejected" ? 1.6 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                "${t.taskTitle} ${i + 1}",
                                style: TextStyle(
                                  color: tasks[i].status == "rejected"
                                      ? rejectedTaskFg
                                      : mutedFg,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (tasks[i].status == "rejected")
                                TaskStatusBadge(
                                  status: tasks[i].status,
                                  label: t.taskStatus(tasks[i].status),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: tasks.length == 1
                              ? null
                              : () => setState(() => tasks.removeAt(i)),
                          child: Text(t.removeTask),
                        ),
                      ],
                    ),
                    _TaskFields(
                      key: ObjectKey(tasks[i]),
                      task: tasks[i],
                      colleagues: widget.colleagues,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: suggesting
                      ? null
                      : () => setState(
                            () => tasks.add(
                              HandoverTask(
                                id: "",
                                title: "",
                                details: "",
                                assigneeId: "",
                                status: "draft",
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.add),
                  label: Text(t.addTask),
                ),
                OutlinedButton.icon(
                  onPressed: suggesting ? null : suggest,
                  icon: suggesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: Text(suggesting ? t.suggesting : t.suggestTasks),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.suggestHint,
              style: const TextStyle(color: mutedFg, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t.generalNotes,
                hintText: t.generalNotesPh,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => save(false),
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: Text(t.saveDraft),
                ),
                FilledButton.icon(
                  onPressed: () => save(true),
                  icon: const Icon(Icons.send, size: 16),
                  label: Text(t.submit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskFields extends StatefulWidget {
  const _TaskFields({
    super.key,
    required this.task,
    required this.colleagues,
    required this.onChanged,
  });
  final HandoverTask task;
  final List<Employee> colleagues;
  final VoidCallback onChanged;
  @override
  State<_TaskFields> createState() => _TaskFieldsState();
}

class _TaskFieldsState extends State<_TaskFields> {
  late final title = TextEditingController(text: widget.task.title);
  late final details = TextEditingController(text: widget.task.details);
  late final due = TextEditingController(text: widget.task.dueDate ?? "");

  @override
  void dispose() {
    title.dispose();
    details.dispose();
    due.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = store.t;
    return Column(
      children: [
        TextField(
          controller: title,
          decoration: InputDecoration(
            labelText: t.taskTitle,
            hintText: t.taskTitlePh,
          ),
          onChanged: (v) => widget.task.title = v,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: details,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: t.taskDetails,
            hintText: t.taskDetailsPh,
          ),
          onChanged: (v) => widget.task.details = v,
        ),
        const SizedBox(height: 8),
        DropdownMenu<String>(
          initialSelection: widget.task.assigneeId.isEmpty
              ? null
              : widget.task.assigneeId,
          label: Text(t.assignee),
          hintText: t.chooseAssignee,
          expandedInsets: EdgeInsets.zero,
          dropdownMenuEntries: [
            for (final c in widget.colleagues)
              if (!widget.task.rejections.any((r) => r.recipientId == c.id))
                DropdownMenuEntry(
                  value: c.id,
                  label:
                      "${_personChoice(store, c)} · ${t.pick(c.jobTitleAr, c.jobTitleEn)} · ${c.staffNumber ?? c.id}",
                ),
          ],
          onSelected: (v) {
            widget.task.assigneeId = v ?? "";
            widget.onChanged();
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final current = DateTime.tryParse(widget.task.dueDate ?? "");
              final picked = await showDatePicker(
                context: context,
                initialDate: current ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked == null) return;
              final iso =
                  "${picked.year.toString().padLeft(4, "0")}-${picked.month.toString().padLeft(2, "0")}-${picked.day.toString().padLeft(2, "0")}";
              setState(() {
                widget.task.dueDate = iso;
                due.text = iso;
              });
              widget.onChanged();
            },
            icon: const Icon(Icons.calendar_month_outlined),
            label: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                due.text.isEmpty
                    ? "${t.dueDate} · ${t.pickDate}"
                    : "${t.dueDate}: ${t.date(due.text)}",
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadonlyTasks extends StatelessWidget {
  const _ReadonlyTasks({
    required this.handover,
    required this.visible,
    required this.access,
    required this.user,
    required this.colleagues,
  });
  final Handover handover;
  final List<HandoverTask> visible;
  final Access access;
  final Employee user;
  final List<Employee> colleagues;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = store.t;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  t.tasks,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (handover.status == "approved") ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock_outline, size: 16, color: mutedFg),
                ],
              ],
            ),
            if (!access.isRecipient)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  t.readOnly,
                  style: const TextStyle(color: mutedFg, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            for (final task in visible)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: task.status == "rejected" ? rejectedTaskBg : null,
                  border: Border.all(
                    color: task.status == "rejected"
                        ? rejectedTaskBorder
                        : task.assigneeId == user.id &&
                              task.status == "pending" &&
                              _taskOpen(handover.status)
                        ? navy.withValues(alpha: 0.5)
                        : line,
                    width: task.status == "rejected" ? 1.6 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: task.status == "rejected"
                                ? rejectedTaskFg
                                : null,
                          ),
                        ),
                        if (task.assigneeId == user.id)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: muted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              t.yourTask,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        TaskStatusBadge(
                          status: task.status,
                          label: t.taskStatus(task.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${t.assignee}: ${store.nameOf(store.person(task.assigneeId))}${task.dueDate != null ? " · ${t.dueDate}: ${t.date(task.dueDate)}" : ""}${task.acceptedAt != null ? " · ${t.acceptedAt}: ${t.date(task.acceptedAt, withTime: true)}" : ""}",
                      style: const TextStyle(color: mutedFg, fontSize: 12),
                    ),
                    if (task.details.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(task.details),
                      ),
                    if (task.acceptNote != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task.acceptNote!,
                          style: const TextStyle(
                            color: Color(0xFF065F46),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (task.rejections.isNotEmpty &&
                        (access.isOwner || access.isManager || access.isHr))
                      for (final r in task.rejections)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${t.previouslyRejectedBy} ${store.nameOf(store.person(r.recipientId))} · ${t.date(r.at, withTime: true)} — ${r.comment}",
                            style: const TextStyle(
                              color: Color(0xFF9F1239),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    if (task.assigneeId == user.id &&
                        task.status == "pending" &&
                        _taskOpen(handover.status))
                      _RecipientActions(
                        handoverId: handover.id,
                        taskId: task.id,
                        taskTitle: task.title,
                      ),
                    if (access.isOwner &&
                        task.status == "rejected" &&
                        _taskOpen(handover.status))
                      _Reassign(
                        handoverId: handover.id,
                        taskId: task.id,
                        colleagues: colleagues,
                        excluded: task.rejections
                            .map((r) => r.recipientId)
                            .toSet(),
                      ),
                  ],
                ),
              ),
            if (handover.generalNotes.isNotEmpty &&
                (access.isOwner || access.isManager || access.isHr))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.generalNotes,
                      style: const TextStyle(
                        color: mutedFg,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(handover.generalNotes),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecipientActions extends StatefulWidget {
  const _RecipientActions({
    required this.handoverId,
    required this.taskId,
    required this.taskTitle,
  });
  final String handoverId;
  final String taskId;
  final String taskTitle;
  @override
  State<_RecipientActions> createState() => _RecipientActionsState();
}

class _RecipientActionsState extends State<_RecipientActions> {
  final note = TextEditingController();
  final reason = TextEditingController();
  bool open = false;
  @override
  void dispose() {
    note.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = store.t;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: navy.withValues(alpha: 0.04),
        border: Border.all(color: navy.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: note,
            decoration: InputDecoration(labelText: t.acceptNote),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () {
                  try {
                    store.acceptTask(
                      store.user!,
                      widget.handoverId,
                      widget.taskId,
                      note.text,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.audit("task_accepted"))),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.error(e.toString()))),
                    );
                  }
                },
                icon: const Icon(Icons.check, size: 16),
                label: Text(t.accept),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => open = true),
                icon: const Icon(
                  Icons.close,
                  size: 16,
                  color: Color(0xFFBE123C),
                ),
                label: Text(
                  t.reject,
                  style: const TextStyle(color: Color(0xFFBE123C)),
                ),
              ),
            ],
          ),
          if (open) ...[
            const SizedBox(height: 8),
            Text(
              widget.taskTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextField(
              controller: reason,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t.rejectReason,
                hintText: t.rejectReasonPh,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => open = false),
                  child: Text(t.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFBE123C),
                  ),
                  onPressed: reason.text.trim().isEmpty
                      ? null
                      : () {
                          try {
                            store.rejectTask(
                              store.user!,
                              widget.handoverId,
                              widget.taskId,
                              reason.text,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t.audit("task_rejected"))),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t.error(e.toString()))),
                            );
                          }
                        },
                  child: Text(t.confirmReject),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Reassign extends StatefulWidget {
  const _Reassign({
    required this.handoverId,
    required this.taskId,
    required this.colleagues,
    required this.excluded,
  });
  final String handoverId;
  final String taskId;
  final List<Employee> colleagues;
  final Set<String> excluded;
  @override
  State<_Reassign> createState() => _ReassignState();
}

class _ReassignState extends State<_Reassign> {
  String? assignee;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = store.t;
    final options = widget.colleagues
        .where((c) => !widget.excluded.contains(c.id))
        .toList();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFECDD3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.newAssignee,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownMenu<String>(
            initialSelection: assignee,
            hintText: t.chooseAssignee,
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              for (final c in options)
                DropdownMenuEntry(
                  value: c.id,
                  label: _personChoice(store, c),
                ),
            ],
            onSelected: (v) => setState(() => assignee = v),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: assignee == null
                ? null
                : () {
                    try {
                      store.reassignTask(
                        store.user!,
                        widget.handoverId,
                        widget.taskId,
                        assignee!,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t.audit("task_reassigned"))),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t.error(e.toString()))),
                      );
                    }
                  },
            child: Text(t.reassign),
          ),
        ],
      ),
    );
  }
}

class _Decision extends StatefulWidget {
  const _Decision({required this.kind, required this.handoverId});
  final String kind;
  final String handoverId;
  @override
  State<_Decision> createState() => _DecisionState();
}

class _DecisionState extends State<_Decision> {
  final comment = TextEditingController();
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = store.t;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: navy.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.kind == "manager" ? t.managerReview : t.hrReview,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              widget.kind == "manager" ? t.managerReviewHint : t.hrReviewHint,
              style: const TextStyle(color: mutedFg, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: comment,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "${t.approvalComment} / ${t.rejectionComment}",
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () {
                    try {
                      if (widget.kind == "manager") {
                        store.managerDecision(
                          store.user!,
                          widget.handoverId,
                          false,
                          comment.text,
                        );
                      } else {
                        store.hrDecision(
                          store.user!,
                          widget.handoverId,
                          false,
                          comment.text,
                        );
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t.audit("${widget.kind}_rejected")),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t.error(e.toString()))),
                      );
                    }
                  },
                  child: Text(
                    t.rejectAndReturn,
                    style: const TextStyle(color: Color(0xFFBE123C)),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    try {
                      if (widget.kind == "manager") {
                        store.managerDecision(
                          store.user!,
                          widget.handoverId,
                          true,
                          comment.text,
                        );
                      } else {
                        store.hrDecision(
                          store.user!,
                          widget.handoverId,
                          true,
                          comment.text,
                        );
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t.audit("${widget.kind}_approved")),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t.error(e.toString()))),
                      );
                    }
                  },
                  child: Text(t.approve),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
