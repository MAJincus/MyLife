import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  /// Indigo profond, moderne — sobre pour une app finance/santé.
  static const seed = Color(0xFF4F46E5);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.inter(
          fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.inter(
          fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineSmall: GoogleFonts.inter(
          fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w600),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
    );

    final cardColor = isDark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLowest;

    return base.copyWith(
      scaffoldBackgroundColor:
          isDark ? scheme.surface : const Color(0xFFF6F6FB),
      textTheme: text,
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor:
            isDark ? scheme.surface : const Color(0xFFF6F6FB),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: isDark
            ? scheme.surfaceContainer
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHighest
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),
    );
  }
}

/// Palette par module — teintes cohérentes et un peu plus douces.
class ModuleColors {
  static const finance = Color(0xFF2E9E6B);
  static const health = Color(0xFFE05260);
  static const diet = Color(0xFFF08A24);
  static const agenda = Color(0xFF3B82F6);
  static const assistant = Color(0xFF7C5CFC);
}

/// Petits dégradés réutilisables (en-têtes, cartes accent).
class AppGradients {
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B5BEF), Color(0xFF7C5CFC)],
  );
  static const assistant = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C5CFC), Color(0xFF9D6BFF)],
  );
}
