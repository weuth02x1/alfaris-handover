import "package:material_ui/material_ui.dart";

import "../directory.dart";
import "../main.dart";
import "../models.dart";
import "../theme.dart";

class ReportPage extends StatelessWidget {
  const ReportPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final h = StoreScope.of(context).must(id);
    final owner = byId(h.employeeId)!;
    return Scaffold(
      appBar: AppBar(title: const Text("تقرير تسليم المهام")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Image.asset("assets/brand/alfaris-lockup.png", height: 48, errorBuilder: (_, _, _) => const Text("ALFARIS GROUP")),
          const SizedBox(height: 12),
          Text("إيصال تسليم المهام ${h.number}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: navy)),
          Text("${owner.nameAr} · ${owner.jobTitleAr} · ${owner.departmentAr}"),
          Text("${reasonLabel(h.type)} · ${h.requestRef}"),
          const Divider(height: 32),
          if (h.generalNotes.isNotEmpty) Text("ملاحظات: ${h.generalNotes}"),
          const SizedBox(height: 12),
          DataTable(
            columns: const [
              DataColumn(label: Text("المهمة")),
              DataColumn(label: Text("المستلم")),
              DataColumn(label: Text("الحالة")),
            ],
            rows: [
              for (final task in h.tasks)
                DataRow(
                  cells: [
                    DataCell(Text(task.title)),
                    DataCell(Text(byId(task.assigneeId)?.nameAr ?? task.assigneeId)),
                    DataCell(Text(task.status == TaskStatus.accepted ? "مقبولة" : task.status.name)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text("معتمد من المدير والموارد البشرية. هذا الإصدار التجريبي يعمل على GitHub Pages."),
        ],
      ),
    );
  }
}
