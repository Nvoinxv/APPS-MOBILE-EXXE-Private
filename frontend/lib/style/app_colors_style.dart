import 'package:flutter/material.dart';

// Color palette inspired by "The LAB" design
// Elegant dark theme with vibrant green accents
class AppColors {
  // Background colors - Deep dark blacks for that premium feel
  static const Color primaryBackground = Color(0xFF0A0A0A); // Almost pure black
  static const Color cardBackground = Color(0xFF151515); // Slightly lighter black for cards
  static const Color secondaryBackground = Color(0xFF1A1A1A); // Alternative background
  
  // Text colors - Clean whites and greys
  static const Color primaryText = Color(0xFFFFFFFF); // Pure white for main text
  static const Color secondaryText = Color(0xFF8A8A8A); // Medium grey for secondary text
  static const Color tertiaryText = Color(0xFF5A5A5A); // Darker grey for tertiary text
  
  // Button colors
  static const Color primaryButton = Color(0xFF00FF94); // Vibrant neon green
  static const Color secondaryButton = Color(0xFF1F1F1F); // Dark grey button
  static const Color googleButton = Color(0xFF1F1F1F); // Dark grey for Google button
  static const Color buttonHover = Color(0xFF00CC77); // Darker green for hover
  static const Color buttonDisabled = Color(0xFF2A2A2A); // Disabled button
  
  // Accent colors - The signature neon green palette
  static const Color accentGreen = Color(0xFF00FF94); // Main neon green
  static const Color accentGreenLight = Color(0xFF33FFAA); // Lighter variant
  static const Color accentGreenDark = Color(0xFF00CC77); // Darker variant
  static const Color accentGreenGlow = Color(0x4000FF94); // Green with transparency for glow effects
  
  // Input field colors
  static const Color inputBackground = Color(0xFF1F1F1F); // Dark input background
  static const Color inputBorder = Color(0xFF2A2A2A); // Subtle border
  static const Color inputFocused = Color(0xFF00FF94); // Neon green when focused
  static const Color inputError = Color(0xFFFF4757); // Red for errors
  
  // Icon colors
  static const Color iconColor = Color(0xFF00FF94); // Neon green icons
  static const Color iconSecondary = Color(0xFF8A8A8A); // Grey icons
  
  // Status colors
  static const Color success = Color(0xFF00FF94); // Success green
  static const Color error = Color(0xFFFF4757); // Error red
  static const Color warning = Color(0xFFFFB800); // Warning amber
  static const Color info = Color(0xFF00A8FF); // Info blue
  
  // Chart/Graph colors (for trading UI like in the image)
  static const Color chartGreen = Color(0xFF00FF94);
  static const Color chartRed = Color(0xFFFF4757);
  static const Color chartLine = Color(0xFF2A2A2A);
  static const Color chartGrid = Color(0xFF1A1A1A);
  
  // Overlay colors
  static const Color overlay = Color(0x80000000); // Black with 50% opacity
  static const Color overlayLight = Color(0x40000000); // Black with 25% opacity
  
  // Gradient colors for premium effects
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00FF94), Color(0xFF00CC77)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Glow effect color for neon elements
  static BoxShadow get neonGlow => BoxShadow(
    color: accentGreenGlow,
    blurRadius: 20,
    spreadRadius: 2,
  );
  
  static BoxShadow get cardShadow => const BoxShadow(
    color: Color(0x40000000),
    blurRadius: 10,
    spreadRadius: 0,
    offset: Offset(0, 4),
  );
}