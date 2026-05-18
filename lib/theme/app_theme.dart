import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Teal/Travel Palette ────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF2E8B7A); // deep teal
  static const Color primaryDark   = Color(0xFF1F6B5E); // darker teal
  static const Color primaryLight  = Color(0xFFE0F2EE); // teal tint
  static const Color primaryDim    = Color(0xFFB2DDD7); // medium teal tint
  static const Color accent        = Color(0xFF26A69A); // bright teal accent

  static const Color background    = Color(0xFFF5F7FA); // light grey-white
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceCard   = Color(0xFFFFFFFF);
  static const Color surfaceWarm   = Color(0xFFF0F4F3); // very light teal-grey
  static const Color surfaceHigh   = Color(0xFFE6EEEC);

  // Semantic
  static const Color mint          = Color(0xFF26A69A);
  static const Color mintLight     = Color(0xFFE0F2EE);
  static const Color peach         = Color(0xFFFF7043); // orange for errors/heart
  static const Color peachLight    = Color(0xFFFBE9E7);
  static const Color dustyPink     = Color(0xFFFF5252);
  static const Color softBlue      = Color(0xFF42A5F5);
  static const Color amber         = Color(0xFFFFB300);
  static const Color errorColor    = Color(0xFFE53935);

  // Text
  static const Color textDark      = Color(0xFF1A2B2A); // very dark teal-black
  static const Color textMid       = Color(0xFF4A6360);
  static const Color textLight     = Color(0xFF8AADA9);
  static const Color textPrimary   = textDark;
  static const Color textSec       = textMid;
  static const Color textMuted     = textLight;

  // Borders
  static const Color border        = Color(0xFFE0ECEA);
  static const Color borderStrong  = Color(0xFFC5DAD7);

  // Header dark teal (matches the reference top section)
  static const Color headerBg      = Color(0xFF1E6B5E);
  static const Color headerBg2     = Color(0xFF2E8B7A);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1A5C52), Color(0xFF2E8B7A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2E8B7A), Color(0xFF26A69A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Colors.transparent, Color(0xCC1A2B2A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.4, 1.0],
  );

  // ── Shadows ────────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(color: const Color(0xFF2E8B7A).withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 8)),
    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> get softShadow => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> get tealShadow => [
    BoxShadow(color: const Color(0xFF2E8B7A).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
  ];

  // ── System UI ──────────────────────────────────────────────────────────────
  static SystemUiOverlayStyle get overlayDark => const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFF5F7FA),
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static SystemUiOverlayStyle get overlayLight => const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFF5F7FA),
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  // ── ThemeData ──────────────────────────────────────────────────────────────
  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      displayLarge:  GoogleFonts.poppins(color: textDark, fontWeight: FontWeight.w800),
      displayMedium: GoogleFonts.poppins(color: textDark, fontWeight: FontWeight.bold),
      headlineLarge: GoogleFonts.poppins(color: textDark, fontWeight: FontWeight.bold),
      headlineMedium:GoogleFonts.poppins(color: textDark, fontWeight: FontWeight.w600),
      titleLarge:    GoogleFonts.poppins(color: textDark, fontWeight: FontWeight.w600),
      titleMedium:   GoogleFonts.poppins(color: textDark, fontWeight: FontWeight.w500),
      bodyLarge:     GoogleFonts.poppins(color: textMid),
      bodyMedium:    GoogleFonts.poppins(color: textMid),
      bodySmall:     GoogleFonts.poppins(color: textLight),
      labelLarge:    GoogleFonts.poppins(color: textDark, fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textDark,
        surfaceContainerHighest: surfaceWarm,
        outline: border,
        error: errorColor,
        onError: Colors.white,
      ),
      cardColor: surfaceCard,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textDark),
        titleTextStyle: GoogleFonts.poppins(color: textDark, fontSize: 19, fontWeight: FontWeight.bold),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: GoogleFonts.poppins(color: textLight, fontSize: 14),
        labelStyle: GoogleFonts.poppins(color: textMid, fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: errorColor)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: errorColor, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(double.infinity, 52),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primaryDim),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceWarm,
        selectedColor: primaryLight,
        showCheckmark: false,
        side: const BorderSide(color: border),
        labelStyle: GoogleFonts.poppins(fontSize: 13, color: textMid),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      bottomAppBarTheme: const BottomAppBarThemeData(color: surface, elevation: 0),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: GoogleFonts.poppins(color: textDark, fontSize: 17, fontWeight: FontWeight.bold),
        contentTextStyle: GoogleFonts.poppins(color: textMid, fontSize: 14),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: textDark,
        contentTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: border)),
        textStyle: GoogleFonts.poppins(color: textDark, fontSize: 13),
        elevation: 4,
      ),

      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : textLight),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : surfaceHigh),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      listTileTheme: const ListTileThemeData(tileColor: Colors.transparent, textColor: textDark, iconColor: textMid),
    );
  }
}