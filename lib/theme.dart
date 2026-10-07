import 'package:flutter/material.dart';

class AppThemes {
  // 🌊 Teal Theme (default)
  static ThemeData get tealTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF006D77), // Deep Teal
    scaffoldBackgroundColor: const Color.fromARGB(
      255,
      255,
      255,
      255,
    ), // Mint Green
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF006D77), // Deep Teal
      secondary: Color(0xFF83C5BE), // Soft Teal
      tertiary: Color(0xFF3A7D7C), // Muted Teal
      error: Color(0xFFFF6B6B), // Mint
      surface: Color(0xFFFFFFFF), // White
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Color(0xFF2E2E2E)), // Charcoal Black
      bodyLarge: TextStyle(color: Color(0xFF555555)), // Dark Gray
      bodyMedium: TextStyle(color: Color(0xFF2E2E2E)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF006D77),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF006D77),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
  );
}
