import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DC {
  // ── Couleurs de fond ────────────────────────────────────────────────────
  static const Color background   = Color(0xFFF8FAFC);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color surface2     = Color(0xFFF1F5F9);
  static const Color surface3     = Color(0xFFE2E8F0);

  // ── Bordures ────────────────────────────────────────────────────────────
  static const Color border       = Color(0xFFE2E8F0);
  static const Color borderLight  = Color(0xFFF1F5F9);

  // ── Texte ───────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary  = Color(0xFF94A3B8);
  static const Color textDisabled  = Color(0xFFCBD5E1);

  // ── Marque ──────────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF3B82F6);
  static const Color primaryDark  = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryBg    = Color(0xFFEFF6FF);

  // ── Sémantique ──────────────────────────────────────────────────────────
  static const Color success       = Color(0xFF10B981);
  static const Color successBg     = Color(0xFFECFDF5);
  static const Color successBorder = Color(0xFFA7F3D0);

  static const Color warning       = Color(0xFFF59E0B);
  static const Color warningBg     = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFDE68A);

  static const Color error         = Color(0xFFEF4444);
  static const Color errorBg       = Color(0xFFFEF2F2);
  static const Color errorBorder   = Color(0xFFFECACA);

  static const Color info          = Color(0xFF3B82F6);
  static const Color infoBg        = Color(0xFFEFF6FF);
  static const Color infoBorder    = Color(0xFFBFDBFE);

  // ── Border radius ───────────────────────────────────────────────────────
  static const double rCard   = 16;
  static const double rBadge  = 10;
  static const double rPill   = 20;
  static const double rChip   = 8;
  static const double rInput  = 12;
  static const double rButton = 14;

  // ── Spacing ─────────────────────────────────────────────────────────────
  static const double screenH = 16;
  static const double cardGap = 10;
  static const double chipGap = 6;

  // ── Card decoration ─────────────────────────────────────────────────────
  static BoxDecoration get card => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(rCard),
        border: Border.all(color: border),
      );

  static BoxDecoration get cardElevated => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(rCard),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // ── Text styles ─────────────────────────────────────────────────────────

  /// Syne — titres, KPI, scores, nom de l'app
  static TextStyle title(double size,
          {FontWeight weight = FontWeight.w700, Color? color}) =>
      GoogleFonts.syne(
        fontSize: size,
        fontWeight: weight,
        color: color ?? textPrimary,
      );

  /// DM Sans — corps de texte, boutons, nav
  static TextStyle body(double size,
          {FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? textPrimary,
      );

  /// IBM Plex Mono — plaques, badges, dates, labels de section
  static TextStyle mono(double size,
          {FontWeight weight = FontWeight.w500, Color? color}) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: weight,
        color: color ?? textSecondary,
      );

  // ── Logo FleetPilote ────────────────────────────────────────────────────
  static Widget logo({double size = 22, bool light = false}) => RichText(
        text: TextSpan(children: [
          TextSpan(
            text: 'Fleet',
            style: GoogleFonts.syne(
              fontSize: size,
              fontWeight: FontWeight.w800,
              color: light ? Colors.white : textPrimary,
            ),
          ),
          TextSpan(
            text: 'Pilote',
            style: GoogleFonts.syne(
              fontSize: size,
              fontWeight: FontWeight.w800,
              color: light ? const Color(0xFFBFDBFE) : primary,
            ),
          ),
        ]),
      );

  // ── Score couleur ───────────────────────────────────────────────────────
  static Color scoreColor(double score) {
    if (score > 70) return success;
    if (score >= 40) return warning;
    return error;
  }

  static Color scoreBg(double score) {
    if (score > 70) return successBg;
    if (score >= 40) return warningBg;
    return errorBg;
  }

  // ── ThemeData global (Light Mode) ───────────────────────────────────────
  static ThemeData get theme {
    final base = ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      fontFamily: 'DMSans',
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: error,
      ),

      // Texte global : DM Sans
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        shadowColor: border,
        titleTextStyle: GoogleFonts.syne(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rCard),
          side: const BorderSide(color: border),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13,
          color: textSecondary,
        ),
        hintStyle: const TextStyle(color: textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),

      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rButton),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rButton),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),

      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primaryBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.dmSans(
            fontSize: 11,
            color: selected ? primary : textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primary
                : textSecondary,
            size: 22,
          );
        }),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rCard),
        ),
        elevation: 8,
      ),

      // BottomSheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rBadge),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: surface2,
        selectedColor: primaryBg,
        labelStyle: GoogleFonts.dmSans(color: textPrimary, fontSize: 12),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rChip),
        ),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary : const Color(0xFFCBD5E1)),
      ),

      // Divider
      dividerTheme: const DividerThemeData(color: border, space: 1),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      // Drawer
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),

      // SegmentedButton
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? primaryBg
                  : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? primary
                  : textSecondary),
          side: WidgetStateProperty.all(const BorderSide(color: border)),
        ),
      ),

      // PopupMenu
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rCard),
          side: const BorderSide(color: border),
        ),
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
      ),

      // Icon
      iconTheme: const IconThemeData(color: textSecondary, size: 20),
    );
  }
}
