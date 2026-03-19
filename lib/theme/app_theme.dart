import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';

/// App theme configuration - Coral & Ivory Light Theme
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Font family
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,

      // Color scheme - Light theme with Coral accents
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentPrimary, // Coral
        secondary: AppColors.accentSecondary, // Emerald
        surface: AppColors.surface, // White
        error: AppColors.moodAnxious, // Soft red
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textHighContrast, // Dark slate
        onError: Colors.white,
        background: AppColors.background, // Ivory
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.background,

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineMedium.copyWith(
          color: AppColors.textHighContrast,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textHighContrast,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Floating Action Button - Coral
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.secondarySoft,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.accentPrimary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.moodAnxious,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textMuted,
        ),
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(
          color: AppColors.textHighContrast,
        ),
        displayMedium: AppTypography.displayMedium.copyWith(
          color: AppColors.textHighContrast,
        ),
        displaySmall: AppTypography.displaySmall.copyWith(
          color: AppColors.textHighContrast,
        ),
        headlineLarge: AppTypography.headlineLarge.copyWith(
          color: AppColors.textHighContrast,
        ),
        headlineMedium: AppTypography.headlineMedium.copyWith(
          color: AppColors.textHighContrast,
        ),
        headlineSmall: AppTypography.headlineSmall.copyWith(
          color: AppColors.textHighContrast,
        ),
        titleLarge: AppTypography.titleLarge.copyWith(
          color: AppColors.textHighContrast,
        ),
        titleMedium: AppTypography.titleMedium.copyWith(
          color: AppColors.textHighContrast,
        ),
        titleSmall: AppTypography.titleSmall.copyWith(
          color: AppColors.textHighContrast,
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(
          color: AppColors.textHighContrast,
        ),
        bodyMedium: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: AppColors.textMuted,
        ),
        labelLarge: AppTypography.labelLarge.copyWith(
          color: AppColors.textHighContrast,
        ),
        labelMedium: AppTypography.labelMedium.copyWith(
          color: AppColors.textMuted,
        ),
        labelSmall: AppTypography.labelSmall.copyWith(
          color: AppColors.textMuted,
        ),
      ),

      // Elevated Button - Coral
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      // Icon Button
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textHighContrast,
          padding: const EdgeInsets.all(12),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.secondarySoft,
        thickness: 1,
        space: 1,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accentPrimary,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: AppTypography.labelSmall,
        unselectedLabelStyle: AppTypography.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  // Legacy darkTheme property for backward compatibility
  static ThemeData get darkTheme => lightTheme;
}
