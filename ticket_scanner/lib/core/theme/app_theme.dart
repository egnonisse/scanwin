import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system PharmaScan.
///
/// Validé par LEO le 20/08/2026 :
/// - Titres : Poppins (AppBar, titres de sections, noms, valeurs)
/// - Corps : Inter (descriptions, dates, sous-titres)
/// - Primaire : vert pharmacie #0E7A5F
/// - Secondaire : vert clair #19B28A (dégradés)
/// - Fond : blanc cassé #F8FAF9
/// - Niveaux : Bronze #9C6B30 · Argent #8E9AAF · Or #D4AF37
/// - Icônes : Material (Symbols Rounded dans les maquettes)
/// - Arrondis : 5px (cartes, boutons, champs) — AppBar carrée
/// - Ombres : douces (0 1px 3px)
/// - Slogan : « Comparez. Payez juste. »
abstract final class AppColors {
  static const Color primary = Color(0xFF0E7A5F);
  static const Color secondary = Color(0xFF19B28A);
  static const Color background = Color(0xFFF8FAF9);
  static const Color surface = Colors.white;
  static const Color onPrimary = Colors.white;
  static const Color textPrimary = Color(0xFF1A2E28);
  static const Color textSecondary = Color(0xFF6B7D75);
  static const Color textMuted = Color(0xFF8A9A93);
  static const Color divider = Color(0xFFF0F4F2);
  static const Color chipBg = Color(0xFFE8EFE9);
  static const Color iconBg = Color(0xFFE6F4EF);

  // Niveaux contributeur.
  static const Color bronze = Color(0xFF9C6B30);
  static const Color silver = Color(0xFF8E9AAF);
  static const Color gold = Color(0xFFD4AF37);

  // AppBar.
  static const Color appBarStart = Color(0xFF0E7A5F);
  static const Color appBarEnd = Color(0xFF0A5C48);

  // Scanner (fond sombre pour lisibilité caméra).
  static const Color scanBg = Color(0xFF1A2E28);
  static const Color scanFrame = Color(0xFF7EE0C8);

  static const Color error = Color(0xFFB3261E);
}

/// Formes : 5px partout, AppBar carrée (0).
abstract final class AppRadii {
  static const double card = 5;
  static const double button = 5;
  static const double field = 5;
  static const double chip = 5;
  static const double icon = 5;
  static const double appBar = 0;
}

/// Ombres douces (équivalent 0 1px 3px).
abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A104834), // rgba(16,72,52,.04)
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> searchBar = [
    BoxShadow(
      color: Color(0x0D000000), // rgba(0,0,0,.05)
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];
}

/// Thème Material 3 complet de l'application.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
  );

  final textTheme = base.textTheme
      .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary)
      .copyWith(
        // Titres : Poppins.
        headlineSmall: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        // Corps : Inter.
        bodyLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.onPrimary,
        ),
        labelMedium: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.onPrimary,
      ),
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textMuted,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: Color(0xFFCFE0D8)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
  );
}
