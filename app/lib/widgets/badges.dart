import "package:material_ui/material_ui.dart";

import "../theme.dart";

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});
  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.bg,
        border: Border.all(color: tone.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: tone.fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class HandoverStatusBadge extends StatelessWidget {
  const HandoverStatusBadge({super.key, required this.status, required this.label});
  final String status;
  final String label;
  @override
  Widget build(BuildContext context) => StatusBadge(label: label, tone: handoverTones[status]!);
}

class TaskStatusBadge extends StatelessWidget {
  const TaskStatusBadge({super.key, required this.status, required this.label});
  final String status;
  final String label;
  @override
  Widget build(BuildContext context) => StatusBadge(label: label, tone: taskTones[status]!);
}
