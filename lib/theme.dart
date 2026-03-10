import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Shadcn-like Color Palette (Light Mode)
  static const Color background = Colors.white;
  static const Color foreground = Color(0xFF09090b);
  static const Color card = Colors.white;
  static const Color cardForeground = Color(0xFF09090b);
  static const Color popover = Colors.white;
  static const Color popoverForeground = Color(0xFF09090b);
  static const Color primary = Color(0xFF18181b);
  static const Color primaryForeground = Color(0xFFfafafa);
  static const Color secondary = Color(0xFFf4f4f5);
  static const Color secondaryForeground = Color(0xFF18181b);
  static const Color muted = Color(0xFFf4f4f5);
  static const Color mutedForeground = Color(0xFF71717a);
  static const Color accent = Color(0xFFf4f4f5);
  static const Color accentForeground = Color(0xFF18181b);
  static const Color destructive = Color(0xFFef4444);
  static const Color destructiveForeground = Color(0xFFfafafa);
  static const Color border = Color(0xFFe4e4e7);
  static const Color input = Color(0xFFe4e4e7);
  static const Color ring = Color(0xFF18181b);

  // Dark Mode Colors (Zinc Palette)
  static const Color darkBackground = Color(0xFF030303);
  static const Color darkForeground = Color(0xFFfafafa);
  static const Color darkCard = Color(0xFF09090b);
  static const Color darkCardForeground = Color(0xFFfafafa);
  static const Color darkPopover = Color(0xFF09090b);
  static const Color darkPopoverForeground = Color(0xFFfafafa);
  static const Color darkPrimary = Color(0xFFfafafa);
  static const Color darkPrimaryForeground = Color(0xFF18181b);
  static const Color darkSecondary = Color(0xFF27272a);
  static const Color darkSecondaryForeground = Color(0xFFfafafa);
  static const Color darkMuted = Color(0xFF27272a);
  static const Color darkMutedForeground = Color(0xFFa1a1aa);
  static const Color darkAccent = Color(0xFF27272a);
  static const Color darkAccentForeground = Color(0xFFfafafa);
  static const Color darkDestructive = Color(0xFF7f1d1d);
  static const Color darkDestructiveForeground = Color(0xFFfafafa);
  static const Color darkBorder = Color(0xFF27272a);
  static const Color darkInput = Color(0xFF27272a);
  static const Color darkRing = Color(0xFFd4d4d8);

  static ThemeData get lightTheme => _createTheme(
    brightness: Brightness.light,
    bg: background,
    fg: foreground,
    primaryColor: primary,
    primaryFg: primaryForeground,
    secondaryColor: secondary,
    secondaryFg: secondaryForeground,
    mutedColor: muted,
    mutedFg: mutedForeground,
    borderColor: border,
    inputColor: input,
  );

  static ThemeData get darkTheme => _createTheme(
    brightness: Brightness.dark,
    bg: darkBackground,
    fg: darkForeground,
    primaryColor: darkPrimary,
    primaryFg: darkPrimaryForeground,
    secondaryColor: darkSecondary,
    secondaryFg: darkSecondaryForeground,
    mutedColor: darkMuted,
    mutedFg: darkMutedForeground,
    borderColor: darkBorder,
    inputColor: darkInput,
  );

  static ThemeData _createTheme({
    required Brightness brightness,
    required Color bg,
    required Color fg,
    required Color primaryColor,
    required Color primaryFg,
    required Color secondaryColor,
    required Color secondaryFg,
    required Color mutedColor,
    required Color mutedFg,
    required Color borderColor,
    required Color inputColor,
  }) {
    final baseTextTheme = GoogleFonts.interTextTheme(
      brightness == Brightness.light
          ? ThemeData.light().textTheme
          : ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
        onPrimary: primaryFg,
        secondary: secondaryColor,
        onSecondary: secondaryFg,
        surface: bg,
        onSurface: fg,
        error: destructive,
        onError: destructiveForeground,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: fg),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: fg),
      ),
      cardTheme: CardThemeData(
        color: brightness == Brightness.light ? card : darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? secondaryColor
            : darkSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: primaryFg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
