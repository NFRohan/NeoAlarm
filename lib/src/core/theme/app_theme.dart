import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NeoColors {
  static const paper = Color(0xFFF8F8F5);
  static const panel = Color(0xFFFFFFFF);
  static const warm = Color(0xFFF4EBD3);
  static const ink = Color(0xFF111111);
  static const subtext = Color(0xFF3F4654);
  static const primary = Color(0xFFFFFF00);
  static const cyan = Color(0xFF16E0E7);
  static const orange = Color(0xFFFF7A00);
  static const success = Color(0xFF34C759);
  static const disabled = Color(0xFFD6D6D0);
  static const muted = Color(0xFFEAE7DD);
}

BorderSide get neoBorderSide =>
    const BorderSide(color: NeoColors.ink, width: 3);

List<BoxShadow> neoShadow({
  Offset offset = const Offset(4, 4),
  Color color = Colors.black,
}) {
  return [BoxShadow(color: color, offset: offset, blurRadius: 0)];
}

RoundedRectangleBorder neoShape({double width = 3}) {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.zero,
    side: BorderSide(color: NeoColors.ink, width: width),
  );
}

BoxDecoration neoPanelDecoration({
  Color color = NeoColors.panel,
  double borderWidth = 3,
  Offset shadowOffset = const Offset(4, 4),
}) {
  return BoxDecoration(
    color: color,
    border: Border.all(color: NeoColors.ink, width: borderWidth),
    boxShadow: neoShadow(offset: shadowOffset),
  );
}

ThemeData buildAppTheme() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: NeoColors.primary,
      onPrimary: NeoColors.ink,
      secondary: NeoColors.cyan,
      onSecondary: NeoColors.ink,
      surface: NeoColors.panel,
      onSurface: NeoColors.ink,
      error: NeoColors.orange,
      onError: NeoColors.ink,
    ),
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    displayLarge: GoogleFonts.inter(
      fontSize: 64,
      fontWeight: FontWeight.w900,
      height: 0.95,
      letterSpacing: -2.6,
      color: NeoColors.ink,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: 44,
      fontWeight: FontWeight.w900,
      height: 0.95,
      letterSpacing: -1.8,
      color: NeoColors.ink,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: 34,
      fontWeight: FontWeight.w900,
      height: 0.98,
      letterSpacing: -1.2,
      color: NeoColors.ink,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: 32,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      letterSpacing: -1.0,
      color: NeoColors.ink,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      letterSpacing: -0.8,
      color: NeoColors.ink,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.4,
      color: NeoColors.ink,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.4,
      color: NeoColors.ink,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: NeoColors.ink,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: NeoColors.ink,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: NeoColors.ink,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: NeoColors.ink,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: NeoColors.subtext,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.4,
      color: NeoColors.ink,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.6,
      color: NeoColors.subtext,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: NeoColors.paper,
    textTheme: textTheme,
    cardTheme: CardThemeData(
      color: NeoColors.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: neoShape(),
      clipBehavior: Clip.antiAlias,
    ),
    dividerColor: NeoColors.ink,
    iconTheme: const IconThemeData(color: NeoColors.ink, size: 22),
    appBarTheme: const AppBarTheme(
      backgroundColor: NeoColors.paper,
      foregroundColor: NeoColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NeoColors.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: textTheme.labelLarge?.copyWith(color: NeoColors.subtext),
      hintStyle: textTheme.bodyMedium?.copyWith(color: NeoColors.subtext),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: neoBorderSide,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: neoBorderSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: NeoColors.ink, width: 4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: NeoColors.primary,
        foregroundColor: NeoColors.ink,
        shape: neoShape(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: NeoColors.ink,
        textStyle: textTheme.labelLarge,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: NeoColors.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: NeoColors.primary,
      ),
      shape: neoShape(),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
