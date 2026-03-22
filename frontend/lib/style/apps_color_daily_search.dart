import 'package:flutter/material.dart';

/// Color style untuk Daily Research section
class DailySearchColorStyle {
  // Background colors
  static const Color backgroundColor = Color(0xFF0A0A0A);
  static const Color cardBackground = Color(0xFF141414);
  static const Color cardBackgroundHover = Color(0xFF1A1A1A);
  
  // Primary brand colors
  static const Color primaryGreen = Color(0xFFBEFF00);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color darkGreen = Color(0xFF1A2410);
  
  // Chart colors
  static const Color chartGreen = Color(0xFF00FF41);
  static const Color chartRed = Color(0xFFFF1744);
  static const Color chartLine = Color(0xFF4AFF4A);
  static const Color chartArea = Color(0x4000FF41);
  
  // Text colors
  static const Color titleText = Color(0xFFFFFFFF);
  static const Color subtitleText = Color(0xFF888888);
  static const Color labelText = Color(0xFFBEFF00);
  static const Color descriptionText = Color(0xFF666666);
  
  // Button colors
  static const Color addButtonBackground = Color(0xFFBEFF00);
  static const Color addButtonText = Color(0xFF000000);
  static const Color addButtonHover = Color(0xFFD4FF33);
  
  // Border colors
  static const Color cardBorder = Color(0xFF222222);
  static const Color cardBorderHover = Color(0xFFBEFF00);
  
  // Gradient for card overlays
  static const LinearGradient cardOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0xEE000000),
    ],
  );
  
  // Shadow for cards
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.5),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];
  
  static List<BoxShadow> get cardShadowHover => [
    BoxShadow(
      color: primaryGreen.withOpacity(0.15),
      blurRadius: 20,
      offset: const Offset(0, 6),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.6),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];
  
  // Text styles
  static const TextStyle cardTitleStyle = TextStyle(
    color: titleText,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
  );
  
  static const TextStyle cardDescriptionStyle = TextStyle(
    color: descriptionText,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  
  static const TextStyle categoryLabelStyle = TextStyle(
    color: labelText,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
  
  static const TextStyle sectionTitleStyle = TextStyle(
    color: titleText,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );
}

/// Theme data untuk Daily Research cards
class DailySearchCardTheme {
  static BoxDecoration cardDecoration({bool isHovered = false}) {
    return BoxDecoration(
      color: DailySearchColorStyle.cardBackground,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isHovered 
            ? DailySearchColorStyle.cardBorderHover 
            : DailySearchColorStyle.cardBorder,
        width: isHovered ? 1.5 : 1,
      ),
      boxShadow: isHovered 
          ? DailySearchColorStyle.cardShadowHover 
          : DailySearchColorStyle.cardShadow,
    );
  }
  
  static BoxDecoration imageOverlayDecoration() {
    return const BoxDecoration(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      gradient: DailySearchColorStyle.cardOverlayGradient,
    );
  }
  
  static BoxDecoration categoryBadgeDecoration() {
    return BoxDecoration(
      color: DailySearchColorStyle.darkGreen,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: DailySearchColorStyle.primaryGreen.withOpacity(0.3),
        width: 0.5,
      ),
    );
  }
}