import 'package:flutter/material.dart';

import '../domain/models.dart';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF2F6F9F),
        brightness: brightness,
      ).copyWith(
        surface: dark ? const Color(0xFF0F1418) : const Color(0xFFF4F6F8),
        surfaceContainerLow: dark ? const Color(0xFF172028) : Colors.white,
        surfaceContainer: dark
            ? const Color(0xFF1C2630)
            : const Color(0xFFEBEFF3),
      );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: dark ? 0.25 : 0.45),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      space: 1,
      thickness: 1,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

extension ConfidenceColor on Confidence {
  Color color(Brightness b) {
    final dark = b == Brightness.dark;
    return switch (this) {
      Confidence.alta =>
        dark ? const Color(0xFF6FCF9B) : const Color(0xFF2E9461),
      Confidence.media =>
        dark ? const Color(0xFFE6BB63) : const Color(0xFFC48A1A),
      Confidence.baixa =>
        dark ? const Color(0xFFE88A7E) : const Color(0xFFC9503F),
    };
  }
}
