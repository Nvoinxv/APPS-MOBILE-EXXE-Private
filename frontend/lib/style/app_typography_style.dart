import 'package:flutter/material.dart';
import 'app_colors_style.dart';

// Typography system inspired by "The LAB" design
// Modern, clean, and readable with proper hierarchy
class AppTypography {
  // Font family - Use SF Pro, Inter, or system default
  static const String fontFamily = 'Inter'; // Or 'SF Pro Display' for iOS feel
  
  // ============ DISPLAY STYLES ============
  // For large hero numbers like "+2.38R" in the design
  static const TextStyle displayLarge = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.bold,
    color: AppColors.accentGreen,
    letterSpacing: -2,
    height: 1.1,
  );
  
  static const TextStyle displayMedium = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
    letterSpacing: -1.5,
    height: 1.1,
  );
  
  static const TextStyle displaySmall = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
    letterSpacing: -1,
    height: 1.2,
  );
  
  // ============ HEADLINE STYLES ============
  // For main titles and headers
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
    letterSpacing: -0.5,
    height: 1.3,
  );
  
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    letterSpacing: -0.3,
    height: 1.3,
  );
  
  // ============ TITLE STYLES ============
  // For section titles and card headers
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    letterSpacing: 0,
    height: 1.4,
  );
  
  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    letterSpacing: 0,
    height: 1.4,
  );
  
  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    letterSpacing: 0,
    height: 1.4,
  );
  
  // ============ BODY STYLES ============
  // For main content and descriptions
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryText,
    letterSpacing: 0.2,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryText,
    letterSpacing: 0.2,
    height: 1.5,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.secondaryText,
    letterSpacing: 0.3,
    height: 1.5,
  );
  
  // ============ LABEL STYLES ============
  // For labels, captions, and metadata
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
    letterSpacing: 0.5,
    height: 1.4,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
    letterSpacing: 0.5,
    height: 1.4,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.tertiaryText,
    letterSpacing: 0.5,
    height: 1.4,
  );
  
  // ============ LEGACY/COMPATIBILITY STYLES ============
  // These match your original style names for backward compatibility
  static const TextStyle title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
    letterSpacing: -0.5,
    height: 1.3,
  );
  
  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.secondaryText,
    letterSpacing: 0.2,
    height: 1.5,
  );
  
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    letterSpacing: 0.5,
    height: 1.2,
  );
  
  static const TextStyle input = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryText,
    letterSpacing: 0.2,
    height: 1.4,
  );
  
  static const TextStyle link = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.accentGreen,
    decoration: TextDecoration.none, // No underline for modern look
    letterSpacing: 0.2,
    height: 1.4,
  );
  
  // ============ SPECIAL STYLES ============
  // For specific use cases like the design
  
  // For trading pairs like "HYPE/USDT"
  static const TextStyle tradingPair = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    letterSpacing: 0.5,
    height: 1.2,
  );
  
  // For price displays with neon effect
  static const TextStyle priceDisplay = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    color: AppColors.accentGreen,
    letterSpacing: -1,
    height: 1.1,
    shadows: [
      Shadow(
        color: AppColors.accentGreenGlow,
        blurRadius: 20,
      ),
    ],
  );
  
  // For status badges like "LONG"
  static const TextStyle badge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
    letterSpacing: 1,
    height: 1.2,
  );
  
  // For monospaced numbers (trading data)
  static const TextStyle monospace = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryText,
    letterSpacing: 0.5,
    height: 1.4,
    fontFamily: 'Courier', // Monospace font
  );
  
  // For timestamp/metadata
  static const TextStyle timestamp = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: AppColors.tertiaryText,
    letterSpacing: 0.3,
    height: 1.4,
  );
}