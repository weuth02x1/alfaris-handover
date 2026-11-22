import "package:material_ui/material_ui.dart";

const navy = Color(0xFF0B1F3A);
const gold = Color(0xFFC9A227);
const cream = Color(0xFFF7F1E6);

ThemeData alfarisTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: "Tahoma",
    colorScheme: ColorScheme.fromSeed(
      seedColor: navy,
      primary: navy,
      secondary: gold,
      surface: Colors.white,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF4F1EC),
    appBarTheme: const AppBarTheme(
      backgroundColor: navy,
      foregroundColor: cream,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: cream,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
