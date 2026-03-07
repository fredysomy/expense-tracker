import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF1B8A5A);

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    ).copyWith(
      surface: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
      surfaceContainerLow:
          isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE),
      surfaceContainer:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8E8),
      surfaceContainerHigh:
          isDark ? const Color(0xFF242424) : const Color(0xFFE0E0E0),
      surfaceContainerHighest:
          isDark ? const Color(0xFF2C2C2C) : const Color(0xFFD8D8D8),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: scheme.surfaceContainerHigh,
      ),
      listTileTheme: const ListTileThemeData(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dividerTheme: DividerThemeData(
        space: 0,
        thickness: 0.5,
        color: scheme.outlineVariant.withOpacity(0.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 56,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11),
        ),
      ),
    );
  }
}
