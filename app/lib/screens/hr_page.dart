import "package:material_ui/material_ui.dart";

import "../directory.dart";
import "../main.dart";
import "../models.dart";
import "handover_page.dart";

class HrPage extends StatelessWidget {
  const HrPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text("لوحة الموارد البشرية")),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text("طلبات معتمدة تنتظر بدء إخلاء الطرف", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              for (final request in approvedRequests)
                Card(
                  child: ListTile(
                    title: Text("${request.ref} · ${byId(request.employeeId)?.nameAr ?? request.employeeId}"),
                    subtitle: Text("${reasonLabel(request.type)} · ${request.startDate}"),
                    trailing: FilledButton(
                      onPressed: store.handovers.any((h) => h.requestRef == request.ref)
                          ? null
                          : () {
                              try {
                                final h = store.startClearance(request);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => HandoverPage(id: h.id)));
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
                              }
                            },
                      child: Text(store.handovers.any((h) => h.requestRef == request.ref) ? "بدأ" : "ابدأ إخلاء الطرف"),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
