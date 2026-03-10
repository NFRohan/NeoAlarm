import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const background = Color(0xFFF4EDE1);
  const surface = Color(0xFFFFFBF4);
  const ink = Color(0xFF1C160F);
  const accent = Color(0xFFC85C3D);
  const secondary = Color(0xFF2B6A6C);

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        surface: surface,
      ).copyWith(
        primary: accent,
        secondary: secondary,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: ink,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: ink,
      displayColor: ink,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
    ),
  );
}
