// lib/utils/theme.dart
import 'package:flutter/material.dart';  // ← THIS WAS MISSING!

class ColorPalette {
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color secondaryGreen = Color(0xFF4CAF50);
  static const Color lightGreen = Color(0xFFC8E6C9);
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color successGreen = Color(0xFF388E3C);
  static const Color warningYellow = Color(0xFFFFA000);
  static const Color infoBlue = Color(0xFF1976D2);
}

// You can also add your app theme here
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primarySwatch: Colors.green,
    primaryColor: ColorPalette.primaryGreen,
    colorScheme: const ColorScheme.light(
      primary: ColorPalette.primaryGreen,
      secondary: ColorPalette.secondaryGreen,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ColorPalette.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColorPalette.primaryGreen, width: 2),
      ),
    ),
  );
}