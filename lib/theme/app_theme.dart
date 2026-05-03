import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors extracted from your awesome new logo!
  static const Color primaryNeon = Color(0xFFD61899); // Vibrant Magenta/Pink
  static const Color secondaryNeon = Color(0xFF5B1DAF); // Deep Purple
  static const Color backgroundDark = Color(0xFF0D0D0D); // True Black/Charcoal
  static const Color surfaceDark = Color(0xFF1A1A1A); // Slightly lighter for cards

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primaryNeon,
      colorScheme: const ColorScheme.dark(
        primary: primaryNeon,
        secondary: secondaryNeon,
        surface: surfaceDark,
      ),
      // Sleek transparent AppBars
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Colors.white,
        ),
      ),
      // Modern rounded buttons with glowing drop shadows
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNeon,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: primaryNeon.withOpacity(0.6),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
      // Sleek outlined buttons with purple accents
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: secondaryNeon, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      // Smooth, pill-shaped text inputs with subtle fill
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primaryNeon, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white60),
        hintStyle: const TextStyle(color: Colors.white38),
      ),
      // Glass-like floating cards
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 8,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
      // Floating Action Buttons matching the primary color
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryNeon,
        foregroundColor: Colors.white,
        elevation: 12,
      ),
    );
  }
}
