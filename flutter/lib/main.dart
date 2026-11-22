import "package:material_ui/material_ui.dart";

import "screens/handover_page.dart";
import "screens/home_page.dart";
import "screens/hr_page.dart";
import "screens/login_page.dart";
import "screens/outbox_page.dart";
import "screens/report_page.dart";
import "store.dart";
import "theme.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(HandoverApp(store: AppStore()));
}

class HandoverApp extends StatelessWidget {
  const HandoverApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          return MaterialApp(
            key: ValueKey("${store.user?.id}-${store.locale}"),
            title: "مجموعة الفارس | تسليم المهام",
            debugShowCheckedModeBanner: false,
            theme: alfarisTheme(),
            locale: Locale(store.locale),
            supportedLocales: const [Locale("ar"), Locale("en")],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => Directionality(
              textDirection: store.t.dir,
              child: child ?? const SizedBox.shrink(),
            ),
            onGenerateRoute: (settings) {
              if (store.user == null) {
                return MaterialPageRoute(builder: (_) => const LoginPage(), settings: settings);
              }
              final name = settings.name ?? "/";
              if (name == "/hr") {
                return MaterialPageRoute(builder: (_) => const HrPage(), settings: settings);
              }
              if (name == "/outbox") {
                return MaterialPageRoute(builder: (_) => const OutboxPage(), settings: settings);
              }
              final handover = RegExp(r"^/handovers/([^/]+)$").firstMatch(name);
              if (handover != null) {
                return MaterialPageRoute(builder: (_) => HandoverPage(id: handover.group(1)!), settings: settings);
              }
              final report = RegExp(r"^/handovers/([^/]+)/report$").firstMatch(name);
              if (report != null) {
                return MaterialPageRoute(builder: (_) => ReportPage(id: report.group(1)!), settings: settings);
              }
              return MaterialPageRoute(builder: (_) => const HomePage(), settings: settings);
            },
          );
        },
      ),
    );
  }
}
