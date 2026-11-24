import "package:material_ui/material_ui.dart";

import "../directory.dart";
import "../models.dart";
import "../store.dart";
import "../theme.dart";
import "../widgets/app_header.dart";
import "../widgets/badges.dart";

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
    final inbox = store.inboxFor(user);
    final notices = store.mailFor(user);
    String empName(Handover h) => store.nameSnap(h.employee);

    return Directionality(
      textDirection: t.dir,
      child: AppScaffold(
        user: user,
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 12 : 28,
            24,
            MediaQuery.sizeOf(context).width < 600 ? 12 : 28,
            40,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, box) {
                        final title = Text(
                          t.inboxTitle,
                          style: TextStyle(
                            fontSize: box.maxWidth < 600 ? 22 : 28,
                            fontWeight: FontWeight.w700,
                            color: navy,
                          ),
                        );
                        final action = FilledButton.icon(
                          onPressed: () => _openRequest(context, store),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(t.newRequest),
                        );
                        if (box.maxWidth < 600) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              title,
                              const SizedBox(height: 12),
                              action,
                            ],
                          );
                        }
                        return Row(
                          children: [title, const SizedBox(width: 16), action],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.inboxSubtitle,
                      style: const TextStyle(color: mutedFg),
                    ),
                    const SizedBox(height: 24),
                    if (inbox.isEmpty && notices.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 56),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.inbox_outlined,
                                size: 36,
                                color: mutedFg,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.nothing,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  t.nothingHint,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: mutedFg,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, box) {
                          final two = box.maxWidth >= 860;
                          final sections = <Widget>[
                            if (notices.isNotEmpty)
                              _Section(
                                icon: Icons.notifications_outlined,
                                title: t.notices,
                                highlight: true,
                                children: [
                                  for (final message in notices.take(8))
                                    _Row(
                                      title: message.subject,
                                      meta: message.body
                                          .split("\n")
                                          .take(3)
                                          .join(" · "),
                                      badge: const SizedBox.shrink(),
                                      onTap: () {
                                        final link = message.link;
                                        if (link != null)
                                          Navigator.pushNamed(context, link);
                                      },
                                    ),
                                ],
                              ),
                            if (inbox.raised.isNotEmpty)
                              _Section(
                                icon: Icons.mark_email_unread_outlined,
                                title: t.raisedQueue,
                                highlight: true,
                                children: [
                                  for (final h in inbox.raised)
                                    _Row(
                                      title:
                                          "${empName(h)} · ${t.type(h.type)}",
                                      meta:
                                          "${h.number} · ${t.date(h.lastWorkingDay)}",
                                      badge: HandoverStatusBadge(
                                        status: h.status,
                                        label: t.status(h.status),
                                      ),
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        "/handovers/${h.id}",
                                      ),
                                    ),
                                ],
                              ),
                            if (inbox.toAccept.isNotEmpty)
                              _Section(
                                icon: Icons.back_hand_outlined,
                                title: t.tasksToAccept,
                                highlight: true,
                                children: [
                                  for (final item in inbox.toAccept)
                                    _Row(
                                      title: item.task!.title,
                                      meta:
                                          "${t.from} ${empName(item.handover)} · ${item.handover.number}",
                                      badge: TaskStatusBadge(
                                        status: item.task!.status,
                                        label: t.taskStatus(item.task!.status),
                                      ),
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        "/handovers/${item.handover.id}",
                                      ),
                                    ),
                                ],
                              ),
                            if (inbox.mine.isNotEmpty)
                              _Section(
                                icon: Icons.assignment_outlined,
                                title: t.myHandovers,
                                highlight: true,
                                children: [
                                  for (final h in inbox.mine)
                                    _Row(
                                      title: "${h.number} · ${t.type(h.type)}",
                                      meta:
                                          "${h.requestRef} · ${t.date(h.lastWorkingDay)}",
                                      badge: HandoverStatusBadge(
                                        status: h.status,
                                        label: t.status(h.status),
                                      ),
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        "/handovers/${h.id}",
                                      ),
                                    ),
                                ],
                              ),
                            if (inbox.teamOpen.isNotEmpty)
                              _Section(
                                icon: Icons.groups_outlined,
                                title: t.teamQueue,
                                highlight: true,
                                children: [
                                  for (final h in inbox.teamOpen)
                                    _Row(
                                      title: empName(h),
                                      meta: "${h.number} · ${t.type(h.type)}",
                                      badge: HandoverStatusBadge(
                                        status: h.status,
                                        label: t.status(h.status),
                                      ),
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        "/handovers/${h.id}",
                                      ),
                                    ),
                                ],
                              ),
                            if (inbox.managerQueue.isNotEmpty)
                              _Section(
                                icon: Icons.verified_outlined,
                                title: t.managerQueue,
                                highlight: true,
                                children: [
                                  for (final h in inbox.managerQueue)
                                    _Row(
                                      title: empName(h),
                                      meta: "${h.number} · ${t.type(h.type)}",
                                      badge: HandoverStatusBadge(
                                        status: h.status,
                                        label: t.status(h.status),
                                      ),
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        "/handovers/${h.id}",
                                      ),
                                    ),
                                ],
                              ),
                            if (inbox.hrQueue.isNotEmpty)
                              _Section(
                                icon: Icons.verified_user_outlined,
                                title: t.hrQueue,
                                highlight: true,
                                children: [
                                  for (final h in inbox.hrQueue)
                                    _Row(
                                      title: empName(h),
                                      meta: "${h.number} · ${t.type(h.type)}",
                                      badge: HandoverStatusBadge(
                                        status: h.status,
                                        label: t.status(h.status),
                                      ),
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        "/handovers/${h.id}",
                                      ),
                                    ),
                                ],
                              ),
                            if (inbox.accepted.isNotEmpty)
                              _Section(
                                icon: Icons.check_circle_outline,
                                title: t.acceptedByMe,
                                children: [
                                  for (final item in inbox.accepted)
                                    _Row(
                                      title: item.task!.title,
                                      meta:
                                          "${t.from} ${empName(item.handover)} · ${t.date(item.task!.acceptedAt, withTime: true)}",
                                      badge: TaskStatusBadge(
                                        status: item.task!.status,
                                        label: t.taskStatus(item.task!.status),
                                      ),
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        "/handovers/${item.handover.id}",
                                      ),
                                    ),
                                ],
                              ),
                          ];
                          if (!two) {
                            return Column(
                              children: [
                                for (final s in sections) ...[
                                  s,
                                  const SizedBox(height: 16),
                                ],
                              ],
                            );
                          }
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final s in sections)
                                SizedBox(
                                  width: (box.maxWidth - 16) / 2,
                                  child: s,
                                ),
                            ],
                          );
                        },
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
}

Future<void> _openRequest(BuildContext context, AppStore store) async {
  final t = store.t;
  var type = "annual_leave";
  DateTime? start;
  DateTime? end;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          String label(DateTime? value) => value == null
              ? t.pickDate
              : t.date(
                  "${value.year.toString().padLeft(4, "0")}-${value.month.toString().padLeft(2, "0")}-${value.day.toString().padLeft(2, "0")}",
                );
          return Directionality(
            textDirection: t.dir,
            child: AlertDialog(
              title: Text(t.newRequest),
              content: SizedBox(
                width: MediaQuery.sizeOf(context).width < 520
                    ? double.maxFinite
                    : 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t.newRequestHint,
                      style: const TextStyle(color: mutedFg, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    DropdownMenu<String>(
                      initialSelection: type,
                      label: Text(t.typeLabel),
                      expandedInsets: EdgeInsets.zero,
                      dropdownMenuEntries: [
                        for (final reason in exitReasons)
                          DropdownMenuEntry(
                            value: reason,
                            label: t.type(reason),
                          ),
                      ],
                      onSelected: (v) => setLocal(() => type = v ?? type),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: start ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setLocal(() => start = picked);
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text("${t.lastWorkingDay}: ${label(start)}"),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: end ?? start ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setLocal(() => end = picked);
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text("${t.returnDate}: ${label(end)}"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(t.cancel),
                ),
                FilledButton(
                  onPressed: start == null
                      ? null
                      : () => Navigator.pop(context, true),
                  child: Text(t.startRequest),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  final chosenStart = start;
  final chosenEnd = end;
  if (ok != true || chosenStart == null || !context.mounted) return;
  String iso(DateTime value) =>
      "${value.year.toString().padLeft(4, "0")}-${value.month.toString().padLeft(2, "0")}-${value.day.toString().padLeft(2, "0")}";
  final id = store.startOwn(
    store.user!,
    type: type,
    lastWorkingDay: iso(chosenStart),
    returnDate: chosenEnd == null ? null : iso(chosenEnd),
  );
  if (context.mounted) Navigator.pushNamed(context, "/handovers/$id");
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
    this.highlight = false,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: highlight ? navy.withValues(alpha: 0.3) : line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: navy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: navy),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: line),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.meta,
    required this.badge,
    required this.onTap,
  });
  final String title;
  final String meta;
  final Widget badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: mutedFg, fontSize: 12),
                  ),
                ],
              ),
            ),
            badge,
            const SizedBox(width: 8),
            const Icon(Icons.north_east, size: 16, color: mutedFg),
          ],
        ),
      ),
    );
  }
}
