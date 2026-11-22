import "package:material_ui/material_ui.dart";

import "screens/home_page.dart";
import "screens/hr_page.dart";
import "screens/login_page.dart";
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
            title: "مجموعة الفارس | تسليم المهام",
            debugShowCheckedModeBanner: false,
            theme: alfarisTheme(),
            locale: const Locale("ar"),
            supportedLocales: const [Locale("ar"), Locale("en")],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox.shrink(),
            ),
            home: store.user == null ? const LoginPage() : const HomePage(),
            routes: {
              "/hr": (_) => const HrPage(),
            },
          );
        },
      ),
    );
  }
}

class StoreScope extends InheritedWidget {
  const StoreScope({super.key, required this.store, required super.child});

  final AppStore store;

  static AppStore of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StoreScope>()!.store;
  }

  @override
  bool updateShouldNotify(StoreScope oldWidget) => store != oldWidget.store;
}
