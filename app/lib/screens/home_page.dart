import "package:material_ui/material_ui.dart";

import "../directory.dart";
import "../main.dart";
import "../models.dart";
import "../theme.dart";
import "handover_page.dart";
import "hr_page.dart";

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final me = store.user!;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.inboxFor(me);
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Image.asset("assets/brand/alfaris-mark.png", height: 28, errorBuilder: (_, _, _) => const SizedBox()),
                const SizedBox(width: 10),
                const Text("تسليم المهام"),
              ],
            ),
            actions: [
              if (me.role == Role.hr)
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrPage())),
                  child: const Text("لوحة الموارد البشرية", style: TextStyle(color: cream)),
                ),
              TextButton(
                onPressed: store.signOut,
                child: Text("${me.nameAr} · خروج", style: const TextStyle(color: cream)),
              ),
            ],
          ),
          body: items.isEmpty
              ? const Center(child: Text("ما فيه طلبات عندك الحين."))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final h = items[index];
                    final owner = byId(h.employeeId)!;
                    return Card(
                      child: ListTile(
                        title: Text("${h.number} · ${owner.nameAr}"),
                        subtitle: Text("${reasonLabel(h.type)} · ${statusLabel(h.status)}"),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => HandoverPage(id: h.id)),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
