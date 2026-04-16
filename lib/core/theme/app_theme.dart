import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Near-black surfaces
  static const _bg              = Color(0xFF080808);
  static const _surface         = Color(0xFF0E0E0E);
  static const _c1              = Color(0xFF141414); // surfaceContainerLow
  static const _c2              = Color(0xFF1A1A1A); // surfaceContainer
  static const _c3              = Color(0xFF212121); // surfaceContainerHigh
  static const _c4              = Color(0xFF2A2A2A); // surfaceContainerHighest

  // Steel blue accent — VS Code / GitHub dark style
  static const _primary         = Color(0xFF4F8FE0);
  static const _onPrimary       = Color(0xFF03111F);
  static const _primaryCont     = Color(0xFF0D1F35); // dark blue container
  static const _onPrimaryCont   = Color(0xFF7AAFED); // soft blue text

  // Muted error red
  static const _error           = Color(0xFFBB4A5A);
  static const _onError         = Color(0xFF300008);
  static const _errorCont       = Color(0xFF280008);
  static const _onErrorCont     = Color(0xFFD97A87);

  // Text & borders — toned down so they don't glare on near-black
  static const _onSurface       = Color(0xFFEAEAEA);
  static const _onSurfaceVar    = Color(0xFF999999);
  static const _outline         = Color(0xFF333333);
  static const _outlineVar      = Color(0xFF222222);

  static ThemeData get lightTheme => darkTheme; // always dark
  static ThemeData get darkTheme => _build();

  static ThemeData _build() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary:              _primary,
      onPrimary:            _onPrimary,
      primaryContainer:     _primaryCont,
      onPrimaryContainer:   _onPrimaryCont,
      secondary:            Color(0xFF6A8DB8),
      onSecondary:          Color(0xFF061220),
      secondaryContainer:   Color(0xFF0C1C2E),
      onSecondaryContainer: Color(0xFF93B4D8),
      tertiary:             Color(0xFF7A8FA8),
      onTertiary:           Color(0xFF091422),
      tertiaryContainer:    Color(0xFF0F1E2E),
      onTertiaryContainer:  Color(0xFFA8BED4),
      error:                _error,
      onError:              _onError,
      errorContainer:       _errorCont,
      onErrorContainer:     _onErrorCont,
      surface:              _surface,
      onSurface:            _onSurface,
      surfaceContainerLow:  _c1,
      surfaceContainer:     _c2,
      surfaceContainerHigh: _c3,
      surfaceContainerHighest: _c4,
      onSurfaceVariant:     _onSurfaceVar,
      outline:              _outline,
      outlineVariant:       _outlineVar,
      shadow:               Color(0xFF000000),
      scrim:                Color(0xFF000000),
      inverseSurface:       Color(0xFFEAEAEA),
      onInverseSurface:     Color(0xFF1A1A1A),
      inversePrimary:       Color(0xFF1A4A82),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        foregroundColor: _onSurface,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: _c1,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: _onSurface,
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
        color: _c3,
      ),
      listTileTheme: const ListTileThemeData(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      dividerTheme: const DividerThemeData(
        space: 0,
        thickness: 0.5,
        color: _outlineVar,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _c2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _outlineVar),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        hintStyle: const TextStyle(color: _onSurfaceVar),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: _onPrimary,
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: const BorderSide(color: _outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _primary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 56,
        backgroundColor: _c1,
        indicatorColor: _primaryCont,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? _onPrimaryCont : const Color(0xFFAAAAAA),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? _onPrimaryCont : const Color(0xFFAAAAAA),
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _c1,
        modalBackgroundColor: _c1,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: _c2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _c4,
        contentTextStyle: const TextStyle(color: _onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
