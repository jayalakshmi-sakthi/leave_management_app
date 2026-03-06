// lib/config/app_theme.dart (Assuming filename)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- App Colors ---

class AppColors {
  // Deep Indigo (Primary) - Used for major actions and headers
  static const primary = Color(0xFF283593); // Indigo 700
  // Teal (Accent/Secondary) - Used for FAB, progress, secondary actions
  static const accent = Color(0xFF009688); // Teal 500
  // Light off-white for cards/surfaces
  static const surface = Color(0xFFF6F8FB);
  // Slightly darker off-white for main background
  static const bg = Color(0xFFF3F6FB);
  // Dark text for titles and main body
  static const textPrimary = Color(0xFF1F2A44);
  // Grey text for hints, captions, and secondary info
  static const textSecondary = Color(0xFF6B7280);
  // Red for errors, rejection
  static const danger = Color(0xFFE53935); // Red 600
}

// --- Theme Builder Function ---

ThemeData buildAppTheme() {
  // Start with Material 3 light defaults
  final base = ThemeData.light(useMaterial3: true);

  // Define required constant values
  const borderRadius = BorderRadius.all(Radius.circular(12));
  const cardBorderRadius = BorderRadius.all(Radius.circular(14));

  return base.copyWith(
    // Global properties
    scaffoldBackgroundColor: AppColors.bg,

    // Add visual feedback colors (important for InkWell/buttons)
    splashColor: AppColors.primary.withOpacity(0.1),
    highlightColor: AppColors.primary.withOpacity(0.05),

    // 1. Color Scheme
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      background: AppColors.bg,
      error: AppColors.danger,
      onPrimary: Colors.white,
    ),

    // 2. Typography
    textTheme: GoogleFonts.poppinsTextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),

    // 3. AppBar
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 1,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),

    // 4. Buttons (Elevated)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: const RoundedRectangleBorder(
          borderRadius: borderRadius, // Use defined const
        ),
      ),
    ),

    // 5. Buttons (Text)
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
      ),
    ),

    // 6. Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 4,
    ),

    // 7. Input Fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,

      // FIX: Added cursor color for better UX
      // cursorColor: AppColors.primary,

      // Use BorderSide.none for default/enabled state
      border: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
    ),

    // 8. Cards
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: const RoundedRectangleBorder(
        borderRadius: cardBorderRadius, // Use defined const
      ),
    ),

    // 9. Icons
    iconTheme: const IconThemeData(color: AppColors.primary),
  );
}
