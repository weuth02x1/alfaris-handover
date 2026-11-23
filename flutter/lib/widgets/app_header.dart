import "package:material_ui/material_ui.dart";

import "../models.dart";
import "../store.dart";
import "../theme.dart";
import "brand.dart";

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.user,
    required this.body,
    this.current = "inbox",
  });
  final Employee user;
  final Widget body;
  final String current;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(user: user, current: current),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.user, this.current = "inbox"});
  final Employee user;
  final String current;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = store.t;
    return Material(
      color: navy,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: gold)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, box) {
              final brand = InkWell(
                onTap: () =>
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil("/", (_) => false),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandLockup(height: 36),
                    if (box.maxWidth > 720) ...[
                      const SizedBox(width: 12),
                      Container(
                        width: 1,
                        height: 28,
                        color: gold.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.appName,
                            style: const TextStyle(
                              color: cream,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const Text(
                            "ALFARIS HR",
                            style: TextStyle(
                              color: gold,
                              fontSize: 10,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
              final nav = Wrap(
                spacing: 4,
                children: [
                  _Nav(
                    icon: Icons.inbox_outlined,
                    label: t.navInbox,
                    selected: current == "inbox",
                    onTap: () =>
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil("/", (_) => false),
                  ),
                  if (user.isHr)
                    _Nav(
                      icon: Icons.verified_user_outlined,
                      label: t.navHr,
                      selected: current == "hr",
                      onTap: () => Navigator.of(context).pushNamed("/hr"),
                    ),
                  _Nav(
                    icon: Icons.mail_outline,
                    label: t.navOutbox,
                    selected: current == "outbox",
                    onTap: () => Navigator.of(context).pushNamed("/outbox"),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: store.toggleLocale,
                    icon: const Icon(Icons.language, color: cream, size: 16),
                    label: Text(
                      t.navLanguage,
                      style: const TextStyle(color: cream),
                    ),
                  ),
                  if (box.maxWidth > 640)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          store.nameOf(user),
                          style: const TextStyle(
                            color: cream,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "${t.pick(user.jobTitleAr, user.jobTitleEn)} · ${t.pick(user.departmentAr, user.departmentEn)} · ${user.displayId}",
                          style: const TextStyle(color: gold, fontSize: 11),
                        ),
                      ],
                    ),
                  OutlinedButton.icon(
                    onPressed: store.logout,
                    icon: const Icon(Icons.logout, size: 16, color: cream),
                    label: Text(
                      t.navLogout,
                      style: const TextStyle(color: cream),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: gold.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              );
              return Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [brand, nav, actions],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.selected,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 16,
        color: cream.withValues(alpha: selected ? 1 : 0.8),
      ),
      label: Text(
        label,
        style: TextStyle(color: cream.withValues(alpha: selected ? 1 : 0.8)),
      ),
      style: TextButton.styleFrom(
        backgroundColor: selected ? Colors.white.withValues(alpha: 0.1) : null,
      ),
    );
  }
}
