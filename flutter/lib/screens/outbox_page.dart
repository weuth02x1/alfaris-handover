import "package:material_ui/material_ui.dart";

import "../store.dart";
import "../theme.dart";
import "../widgets/app_header.dart";

class OutboxPage extends StatelessWidget {
  const OutboxPage({super.key});

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
    final mail = store.mailFor(user);
    return Directionality(
      textDirection: t.dir,
      child: AppScaffold(
        user: user,
        current: "outbox",
        body: ListView(
          padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < 600 ? 12 : 28, 24, MediaQuery.sizeOf(context).width < 600 ? 12 : 28, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.outboxTitle,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.outboxSubtitle,
                      style: const TextStyle(color: mutedFg),
                    ),
                    const SizedBox(height: 20),
                    if (mail.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 56),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.mail_outline,
                                size: 36,
                                color: mutedFg,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.outboxEmpty,
                                style: const TextStyle(color: mutedFg),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      for (final m in mail)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.subject,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${t.outboxTo}: ${m.to} · ${t.date(m.at, withTime: true)}",
                                    style: const TextStyle(
                                      color: mutedFg,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    m.body,
                                    style: const TextStyle(
                                      color: mutedFg,
                                      height: 1.5,
                                    ),
                                  ),
                                  if (m.link != null) ...[
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pushNamed(context, m.link!),
                                      child: Text(t.open),
                                    ),
                                  ],
                                ],
                              ),
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
