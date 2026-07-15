import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Roboto type scale per the UI design system (§2.4).
///
/// Display/Logo 28-32/900 · H1 24/700 · H2 20/700 · H3 18/500 ·
/// Body 14-16/400 · Small 12/400 · Micro/Badge 10-11/500-700 · Button 14/500.
class AppTextStyles {
  AppTextStyles._();

  static TextTheme textTheme(Color fg) {
    final muted = fg.withValues(alpha: 0.65);
    return TextTheme(
      // Display / Logo
      displayLarge: GoogleFonts.roboto(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: fg,
      ),
      displayMedium: GoogleFonts.roboto(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: fg,
      ),
      // Headings
      headlineMedium: GoogleFonts.roboto(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: fg,
      ),
      titleLarge: GoogleFonts.roboto(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: fg,
      ),
      titleMedium: GoogleFonts.roboto(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: fg,
      ),
      // Body
      bodyLarge: GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: fg,
      ),
      bodyMedium: GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: fg,
      ),
      bodySmall: GoogleFonts.roboto(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      // Micro / badge
      labelSmall: GoogleFonts.roboto(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
      // Button
      labelLarge: GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: fg,
      ),
    );
  }
}
