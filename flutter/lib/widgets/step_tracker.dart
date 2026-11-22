import "package:material_ui/material_ui.dart";

import "../theme.dart";

const _order = ["draft", "pending_acceptance", "pending_manager", "pending_hr", "approved"];

class StepTracker extends StatelessWidget {
  const StepTracker({super.key, required this.status, required this.labels});
  final String status;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final current = status == "returned" ? 0 : _order.indexOf(status);
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: i == 0 ? const SizedBox() : Container(height: 2, color: i <= current ? navy : line)),
                    _dot(i, current),
                    Expanded(
                      child: i == labels.length - 1 ? const SizedBox() : Container(height: 2, color: i < current || status == "approved" ? navy : line),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == current && status != "approved" ? FontWeight.w700 : FontWeight.w400,
                    color: i == current && status != "approved" ? navy : mutedFg,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(int i, int current) {
    final done = i < current || status == "approved";
    final active = i == current && status != "approved";
    final returned = active && status == "returned";
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? navy : cardBg,
        border: Border.all(color: returned ? const Color(0xFFEF4444) : (done || active ? navy : line), width: 2),
        boxShadow: active
            ? [BoxShadow(color: (returned ? const Color(0xFFEF4444) : navy).withValues(alpha: 0.15), blurRadius: 0, spreadRadius: 4)]
            : null,
      ),
      child: done
          ? const Icon(Icons.check, size: 16, color: cream)
          : Text(
              "${i + 1}",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: returned ? const Color(0xFFE11D48) : (active ? navy : mutedFg),
              ),
            ),
    );
  }
}
