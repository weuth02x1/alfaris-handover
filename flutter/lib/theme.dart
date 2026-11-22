import "package:material_ui/material_ui.dart";

const navy = Color(0xFF0B114F);
const gold = Color(0xFFA49787);
const cream = Color(0xFFF4EFE4);
const pageBg = Color(0xFFF6F3EC);
const cardBg = Color(0xFFFFFCF7);
const muted = Color(0xFFEFE8DA);
const mutedFg = Color(0xFF5C584F);
const line = Color(0xFFE3D9C8);

ThemeData alfarisTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: navy, primary: navy, surface: cardBg).copyWith(
    secondary: gold,
    onPrimary: cream,
    onSecondary: navy,
    onSurface: navy,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: "Tahoma",
    colorScheme: scheme,
    scaffoldBackgroundColor: pageBg,
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: line),
      ),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: cream, elevation: 0),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: navy,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: gold, width: 1.4)),
    ),
  );
}

class StatusTone {
  const StatusTone(this.bg, this.fg, this.border);
  final Color bg;
  final Color fg;
  final Color border;
}

const handoverTones = {
  "draft": StatusTone(Color(0xFFF1F5F9), Color(0xFF334155), Color(0xFFE2E8F0)),
  "pending_acceptance": StatusTone(Color(0xFFFFFBEB), Color(0xFF92400E), Color(0xFFFDE68A)),
  "pending_manager": StatusTone(Color(0xFFF0F9FF), Color(0xFF075985), Color(0xFFBAE6FD)),
  "pending_hr": StatusTone(Color(0xFFF5F3FF), Color(0xFF5B21B6), Color(0xFFDDD6FE)),
  "returned": StatusTone(Color(0xFFFFF1F2), Color(0xFF9F1239), Color(0xFFFECDD3)),
  "approved": StatusTone(Color(0xFFECFDF5), Color(0xFF065F46), Color(0xFFA7F3D0)),
};

const taskTones = {
  "draft": StatusTone(Color(0xFFF1F5F9), Color(0xFF334155), Color(0xFFE2E8F0)),
  "pending": StatusTone(Color(0xFFFFFBEB), Color(0xFF92400E), Color(0xFFFDE68A)),
  "accepted": StatusTone(Color(0xFFECFDF5), Color(0xFF065F46), Color(0xFFA7F3D0)),
  "rejected": StatusTone(Color(0xFFFFF1F2), Color(0xFF9F1239), Color(0xFFFECDD3)),
};
