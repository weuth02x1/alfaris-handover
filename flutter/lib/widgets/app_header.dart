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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: gold)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 1100;
              final roomy = box.maxWidth >= 1280;
              final brand = InkWell(
                onTap: () => Navigator.of(context).pushNamedAndRemoveUntil("/", (_) => false),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrandLockup(height: wide ? 40 : 28, markOnly: box.maxWidth < 700),
                    if (roomy) ...[
                      const SizedBox(width: 12),
                      Container(width: 1, height: 28, color: gold.withValues(alpha: 0.7)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.appName, style: const TextStyle(color: cream, fontWeight: FontWeight.w600, fontSize: 13)),
                          const Text("ALFARIS HR", style: TextStyle(color: gold, fontSize: 10, letterSpacing: 1.6)),
                        ],
                      ),
                    ],
                  ],
                ),
              );
              final nav = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Nav(icon: Icons.inbox_outlined, label: t.navInbox, selected: current == "inbox", compact: !wide, onTap: () => Navigator.of(context).pushNamedAndRemoveUntil("/", (_) => false)),
                  if (user.isHr) ...[
                    const SizedBox(width: 4),
                    _Nav(icon: Icons.verified_user_outlined, label: roomy ? t.navHr : t.navHrShort, selected: current == "hr", compact: !wide, onTap: () => Navigator.of(context).pushNamed("/hr")),
                  ],
                  const SizedBox(width: 4),
                  _Nav(icon: Icons.mail_outline, label: t.navOutbox, selected: current == "outbox", compact: !wide, onTap: () => Navigator.of(context).pushNamed("/outbox")),
                ],
              );
              final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(store.nameOf(user), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: cream, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    "${t.pick(user.jobTitleAr, user.jobTitleEn)} · ${t.pick(user.departmentAr, user.departmentEn)} · ${user.displayId}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: gold, fontSize: 11),
                  ),
                ],
              );
              final language = box.maxWidth < 700
                  ? IconButton(
                      onPressed: store.toggleLocale,
                      tooltip: t.navLanguage,
                      icon: const Icon(Icons.language, color: cream, size: 18),
                    )
                  : TextButton.icon(
                      onPressed: store.toggleLocale,
                      icon: const Icon(Icons.language, color: cream, size: 16),
                      label: Text(t.navLanguage, style: const TextStyle(color: cream)),
                    );
              final logout = wide
                  ? OutlinedButton.icon(
                      onPressed: store.logout,
                      icon: const Icon(Icons.logout, size: 16, color: cream),
                      label: Text(t.navLogout, style: const TextStyle(color: cream)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: gold.withValues(alpha: 0.5)), visualDensity: VisualDensity.compact),
                    )
                  : IconButton(
                      onPressed: store.logout,
                      tooltip: t.navLogout,
                      icon: const Icon(Icons.logout, color: cream, size: 18),
                    );

              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        brand,
                        const Spacer(),
                        language,
                        logout,
                      ],
                    ),
                    const SizedBox(height: 4),
                    identity,
                    const SizedBox(height: 4),
                    SingleChildScrollView(scrollDirection: Axis.horizontal, child: nav),
                  ],
                );
              }
              return SizedBox(
                height: 56,
                child: Row(
                  children: [
                    brand,
                    const SizedBox(width: 20),
                    nav,
                    const SizedBox(width: 16),
                    Expanded(child: identity),
                    language,
                    const SizedBox(width: 8),
                    logout,
                  ],
                ),
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
    this.compact = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool compact;

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
        style: TextStyle(color: cream.withValues(alpha: selected ? 1 : 0.8), fontSize: compact ? 12 : 14),
      ),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        backgroundColor: selected ? Colors.white.withValues(alpha: 0.1) : null,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
      ),
    );
  }
}
