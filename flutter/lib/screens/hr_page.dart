import "package:material_ui/material_ui.dart";

import "../directory.dart";
import "../store.dart";
import "../theme.dart";
import "../widgets/app_header.dart";
import "../widgets/badges.dart";

class HrPage extends StatelessWidget {
  const HrPage({super.key});

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
    if (!user.isHr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil("/", (_) => false);
      });
      return const SizedBox.shrink();
    }
    final started = store.handovers.map((h) => h.requestRef).toSet();
    final handovers = [...store.handovers]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Directionality(
      textDirection: t.dir,
      child: AppScaffold(
        user: user,
        current: "hr",
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        SizedBox(
                          width: 640,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.hrTitle,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: navy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.hrSubtitle,
                                style: const TextStyle(color: mutedFg),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: line),
                            borderRadius: BorderRadius.circular(999),
                            color: cardBg,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.storage,
                                size: 14,
                                color: mutedFg,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${t.source}: ${t.sourceMock}",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.approvedRequests,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.approvedRequestsHint,
                              style: const TextStyle(
                                color: mutedFg,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: mutedFg,
                                  fontSize: 12,
                                ),
                                columns: [
                                  DataColumn(label: Text(t.ref)),
                                  DataColumn(label: Text(t.employee)),
                                  DataColumn(label: Text(t.typeLabel)),
                                  DataColumn(label: Text(t.fromDate)),
                                  DataColumn(label: Text(t.toDate)),
                                  const DataColumn(label: Text("")),
                                ],
                                rows: [
                                  for (final r in mockApprovedRequests)
                                    DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            r.ref,
                                            style: const TextStyle(
                                              fontFamily: "monospace",
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            store.nameOf(
                                              store.person(r.employeeId),
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(t.type(r.type))),
                                        DataCell(Text(t.date(r.startDate))),
                                        DataCell(Text(t.date(r.endDate))),
                                        DataCell(
                                          started.contains(r.ref)
                                              ? Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: muted,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    t.alreadyStarted,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                )
                                              : FilledButton(
                                                  onPressed: () {
                                                    try {
                                                      store.initiateClearance(
                                                        user,
                                                        r.ref,
                                                      );
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            t.audit(
                                                              "link_sent",
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            t.error(
                                                              e.toString(),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  child: Text(t.startClearance),
                                                ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.task_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  t.allHandovers,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (handovers.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    t.noHandovers,
                                    style: const TextStyle(color: mutedFg),
                                  ),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingTextStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: mutedFg,
                                    fontSize: 12,
                                  ),
                                  columns: [
                                    DataColumn(label: Text(t.number)),
                                    DataColumn(label: Text(t.employee)),
                                    DataColumn(label: Text(t.typeLabel)),
                                    DataColumn(label: Text(t.progress)),
                                    DataColumn(label: Text(t.statusLabel)),
                                  ],
                                  rows: [
                                    for (final h in handovers)
                                      DataRow(
                                        cells: [
                                          DataCell(
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pushNamed(
                                                    context,
                                                    "/handovers/${h.id}",
                                                  ),
                                              child: Text(
                                                h.number,
                                                style: const TextStyle(
                                                  fontFamily: "monospace",
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(store.nameSnap(h.employee)),
                                          ),
                                          DataCell(Text(t.type(h.type))),
                                          DataCell(
                                            Text(
                                              h.tasks.isEmpty
                                                  ? t.dash
                                                  : t.fmt(t.progressFmt, {
                                                      "a": h.tasks
                                                          .where(
                                                            (x) =>
                                                                x.status ==
                                                                "accepted",
                                                          )
                                                          .length,
                                                      "b": h.tasks.length,
                                                    }),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: mutedFg,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            HandoverStatusBadge(
                                              status: h.status,
                                              label: t.status(h.status),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
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
}
