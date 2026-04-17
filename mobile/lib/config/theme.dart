import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // -- Brand colors --
  static const Color primaryGold = Color(0xFFD4A017);
  static const Color primaryAmber = Color(0xFFF5A623);
  static const Color primaryDark = Color(0xFFB8860B);
  static const Color accentGreen = Color(0xFF009E60); // Gabon flag green
  static const Color accentBlue = Color(0xFF3A75C4); // Gabon flag blue
  static const Color accentYellow = Color(0xFFFCD116); // Gabon flag yellow

  // -- Neutrals --
  static const Color scaffoldDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF2A2A2A);
  static const Color scaffoldLight = Color(0xFFF5F0E8);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFF8EE);

  // -- Text --
  static const Color textOnDark = Color(0xFFF5F5F5);
  static const Color textSecondaryOnDark = Color(0xFFB0B0B0);
  static const Color textOnLight = Color(0xFF1A1A1A);
  static const Color textSecondaryOnLight = Color(0xFF6B6B6B);

  // -- Status --
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF3498DB);

  // -- Swatch --
  static const MaterialColor primarySwatch = MaterialColor(0xFFD4A017, {
    50: Color(0xFFFDF6E3),
    100: Color(0xFFFBEAB9),
    200: Color(0xFFF8DC8C),
    300: Color(0xFFF5CE5E),
    400: Color(0xFFF2C33C),
    500: Color(0xFFD4A017),
    600: Color(0xFFC49315),
    700: Color(0xFFB08312),
    800: Color(0xFF9C740F),
    900: Color(0xFF7A5A09),
  });

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: primarySwatch,
      colorScheme: ColorScheme.light(
        primary: primaryGold,
        onPrimary: Colors.white,
        secondary: accentGreen,
        onSecondary: Colors.white,
        tertiary: accentBlue,
        surface: surfaceLight,
        onSurface: textOnLight,
        error: error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: scaffoldLight,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        foregroundColor: textOnLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textOnLight,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGold,
          side: const BorderSide(color: primaryGold),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGold,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        hintStyle: const TextStyle(color: textSecondaryOnLight, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondaryOnLight),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: primaryGold,
        unselectedItemColor: textSecondaryOnLight,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFFFF3D6),
        labelStyle: const TextStyle(color: primaryDark, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8E0D0),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: primarySwatch,
      colorScheme: ColorScheme.dark(
        primary: primaryAmber,
        onPrimary: Colors.black,
        secondary: accentGreen,
        onSecondary: Colors.white,
        tertiary: accentBlue,
        surface: surfaceDark,
        onSurface: textOnDark,
        error: error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: scaffoldDark,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: textOnDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textOnDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAmber,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAmber,
          side: const BorderSide(color: primaryAmber),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryAmber),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF444444)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF444444)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryAmber, width: 2),
        ),
        hintStyle: const TextStyle(color: textSecondaryOnDark, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryAmber,
        unselectedItemColor: textSecondaryOnDark,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF333333),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
