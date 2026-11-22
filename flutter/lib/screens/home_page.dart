import "package:material_ui/material_ui.dart";

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
    String empName(Handover h) => store.nameSnap(h.employee);

    return Directionality(
      textDirection: t.dir,
      child: Scaffold(
        appBar: AppHeader(user: user),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.inboxTitle, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: navy)),
                    const SizedBox(height: 4),
                    Text(t.inboxSubtitle, style: const TextStyle(color: mutedFg)),
                    const SizedBox(height: 24),
                    if (inbox.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 56),
                          child: Column(
                            children: [
                              const Icon(Icons.inbox_outlined, size: 36, color: mutedFg),
                              const SizedBox(height: 8),
                              Text(t.nothing, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(t.nothingHint, textAlign: TextAlign.center, style: const TextStyle(color: mutedFg, fontSize: 13)),
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
                            if (inbox.toAccept.isNotEmpty)
                              _Section(
                                icon: Icons.back_hand_outlined,
                                title: t.tasksToAccept,
                                highlight: true,
                                children: [
                                  for (final item in inbox.toAccept)
                                    _Row(
                                      title: item.task!.title,
                                      meta: "${t.from} ${empName(item.handover)} · ${item.handover.number}",
                                      badge: TaskStatusBadge(status: item.task!.status, label: t.taskStatus(item.task!.status)),
                                      onTap: () => Navigator.pushNamed(context, "/handovers/${item.handover.id}"),
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
                                      meta: "${h.requestRef} · ${t.date(h.lastWorkingDay)}",
                                      badge: HandoverStatusBadge(status: h.status, label: t.status(h.status)),
                                      onTap: () => Navigator.pushNamed(context, "/handovers/${h.id}"),
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
                                      badge: HandoverStatusBadge(status: h.status, label: t.status(h.status)),
                                      onTap: () => Navigator.pushNamed(context, "/handovers/${h.id}"),
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
                                      badge: HandoverStatusBadge(status: h.status, label: t.status(h.status)),
                                      onTap: () => Navigator.pushNamed(context, "/handovers/${h.id}"),
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
                                      meta: "${t.from} ${empName(item.handover)} · ${t.date(item.task!.acceptedAt, withTime: true)}",
                                      badge: TaskStatusBadge(status: item.task!.status, label: t.taskStatus(item.task!.status)),
                                      onTap: () => Navigator.pushNamed(context, "/handovers/${item.handover.id}"),
                                    ),
                                ],
                              ),
                          ];
                          if (!two) {
                            return Column(children: [for (final s in sections) ...[s, const SizedBox(height: 16)]]);
                          }
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final s in sections) SizedBox(width: (box.maxWidth - 16) / 2, child: s),
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

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children, this.highlight = false});
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
                  decoration: BoxDecoration(color: navy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Icon(icon, size: 16, color: navy),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
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
  const _Row({required this.title, required this.meta, required this.badge, required this.onTap});
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
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: mutedFg, fontSize: 12)),
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
