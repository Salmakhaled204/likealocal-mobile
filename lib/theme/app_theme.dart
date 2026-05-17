import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Palette ─────────────────────────────────────────────────────────────────
  static const Color background   = Color(0xFFFAF9F7); // warm cream
  static const Color surface      = Color(0xFFFFFFFF); // white cards
  static const Color surfaceWarm  = Color(0xFFF5F3F0); // warm input bg
  static const Color surfaceCard  = Color(0xFFFFFEFD); // card tint

  static const Color primary      = Color(0xFF8B7DC4); // dusty lavender
  static const Color primaryLight = Color(0xFFEDE8F8); // lavender tint
  static const Color primaryDim   = Color(0xFFD5CEEE); // medium lavender

  static const Color mint         = Color(0xFF7CC4A8); // soft mint
  static const Color mintLight    = Color(0xFFDFF3EC); // mint tint
  static const Color peach        = Color(0xFFE8A47C); // warm peach
  static const Color peachLight   = Color(0xFFFDF2E8); // peach tint
  static const Color dustyPink    = Color(0xFFD4849A); // dusty rose
  static const Color softBlue     = Color(0xFF85A8C8); // periwinkle blue

  static const Color textDark     = Color(0xFF2A2A3C); // deep charcoal
  static const Color textMid      = Color(0xFF6A6A82); // medium gray
  static const Color textLight    = Color(0xFFA5A5BB); // muted gray

  // Backward-compatible aliases used by older screens.
  static const Color surfaceHigh  = surfaceWarm;
  static const Color textPrimary  = textDark;
  static const Color textSec      = textMid;
  static const Color textMuted    = textLight;

  static const Color border       = Color(0xFFEBE8F5); // lavender-gray
  static const Color borderStrong = Color(0xFFD8D4EC); // slightly darker
  static const Color amber        = Color(0xFFF5A623); // star rating
  static const Color errorColor   = Color(0xFFE07878); // soft coral

  // Reusable card shadow
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.07),
          blurRadius: 20,
          offset: const Offset(0, 6),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  // ── Theme ────────────────────────────────────────────────────────────────────
  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.poppins(
        color: textDark,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: GoogleFonts.poppins(
        color: textDark,
        fontWeight: FontWeight.bold,
      ),
      headlineLarge: GoogleFonts.poppins(
        color: textDark,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: GoogleFonts.poppins(
        color: textDark,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.poppins(
        color: textDark,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.poppins(
        color: textDark,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.poppins(color: textMid),
      bodyMedium: GoogleFonts.poppins(color: textMid),
      bodySmall: GoogleFonts.poppins(color: textLight),
      labelLarge: GoogleFonts.poppins(
        color: textDark,
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        secondary: mint,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textDark,
        surfaceContainerHighest: surfaceWarm,
        outline: border,
        error: errorColor,
        onError: Colors.white,
      ),
      cardColor: surface,
      textTheme: textTheme,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textDark),
        titleTextStyle: GoogleFonts.poppins(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // ── Inputs ──────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWarm,
        hintStyle: GoogleFonts.poppins(color: textLight, fontSize: 14),
        labelStyle: GoogleFonts.poppins(color: textMid, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Elevated button ─────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 52),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      // ── Outlined button ─────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primaryDim),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),

      // ── Text button ─────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
      ),

      // ── Chip ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: surfaceWarm,
        selectedColor: primaryLight,
        showCheckmark: false,
        side: const BorderSide(color: border),
        labelStyle: GoogleFonts.poppins(fontSize: 13, color: textMid),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Bottom app bar ──────────────────────────────────────────────────
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: surface,
        elevation: 0,
      ),

      // ── FAB ─────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // ── Dialog ──────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.poppins(
          color: textDark,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: GoogleFonts.poppins(color: textMid, fontSize: 14),
      ),

      // ── Snack bar ────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textDark,
        contentTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),

      // ── Popup menu ───────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border),
        ),
        textStyle: GoogleFonts.poppins(color: textDark, fontSize: 13),
        elevation: 4,
        shadowColor: Colors.black12,
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      // ── Switch ───────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primaryLight
              : const Color(0xFFDDDAEA),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
