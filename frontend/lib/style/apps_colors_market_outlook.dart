import 'package:flutter/material.dart';

/// Color style untuk MarketOutlook Investing section - Deep Green Version
class MarketOutlookColorStyle {
  // Background colors
  static const Color backgroundColor = Color(0xFF0A0A0A);
  static const Color cardBackground = Color(0xFF141414);
  static const Color cardBackgroundHover = Color(0xFF1A1A1A);
  
  // Primary colors - Replaced Neon Yellow with Deep Emerald Green
  static const Color primaryGreen = Color(0xFF00C853); // Hijau Emerald yang solid
  static const Color greenNeon = Color(0xFF00E676);    // Hijau terang tapi bukan kuning
  static const Color darkGreen = Color(0xFF003311);
  static const Color lightGreen = Color(0xFF69F0AE);
  
  // Chart/Data colors
  static const Color chartGreen = Color(0xFF00E676);
  static const Color chartBlue = Color(0xFF3B82F6);
  static const Color chartLine = Color(0xFF00C853);
  static const Color chartRed = Color(0xFFEF4444);
  
  // Text colors
  static const Color titleText = Color(0xFFFFFFFF);
  static const Color subtitleText = Color(0xFFCCCCCC);
  static const Color descriptionText = Color(0xFF888888);
  static const Color labelText = Color(0xFF00E676); // Konsisten Hijau
  
  // Button colors - Dark Green Theme
  static const Color addButtonBackground = Color(0xFF00C853);
  static const Color addButtonText = Color(0xFF000000);
  static const Color addButtonHover = Color(0xFF00E676);
  
  // Search bar colors
  static const Color searchBackground = Color(0xFF141414);
  static const Color searchBorder = Color(0xFF2A2A2A);
  static const Color searchText = Color(0xFFFFFFFF);
  static const Color searchPlaceholder = Color(0xFF666666);
  
  // Badge colors
  static const Color badgeBackground = Color(0xFF004D20); // Deep forest green
  static const Color badgeText = Color(0xFFFFFFFF);
  
  // Border colors
  static const Color cardBorder = Color(0xFF222222);
  static const Color cardBorderHover = Color(0xFF00C853);
  
  // Gradient overlays - Forest/Deep Greenish
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x33004411), // Dark green transparent
      Color(0x33002610), // Deeper green transparent
    ],
  );
  
  static const LinearGradient textOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0xF5000000),
    ],
    stops: [0.2, 1.0],
  );
  
  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.6),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> get cardShadowHover => [
    BoxShadow(
      color: greenNeon.withOpacity(0.2), // Glow hijau bukan kuning
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.7),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  // Text styles
  static const TextStyle sectionTitleStyle = TextStyle(
    color: titleText,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );
  
  static const TextStyle cardTitleStyle = TextStyle(
    color: titleText,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
  );
  
  static const TextStyle cardSubtitleStyle = TextStyle(
    color: greenNeon, // Hijau neon, bukan kuning neon lagi
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  
  static const TextStyle cardDescriptionStyle = TextStyle(
    color: descriptionText,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle badgeTextStyle = TextStyle(
    color: badgeText,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
  
  static const TextStyle pairStyle = TextStyle(
    color: titleText,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
  );
}

/// Theme data tetap sama (mengikuti perubahan warna di atas secara otomatis)
class MarketOutlookCardTheme {
  static BoxDecoration cardDecoration({bool isHovered = false}) {
    return BoxDecoration(
      color: MarketOutlookColorStyle.cardBackground,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isHovered 
            ? MarketOutlookColorStyle.cardBorderHover 
            : MarketOutlookColorStyle.cardBorder,
        width: isHovered ? 1.5 : 1,
      ),
      boxShadow: isHovered 
          ? MarketOutlookColorStyle.cardShadowHover 
          : MarketOutlookColorStyle.cardShadow,
    );
  }
  
  static BoxDecoration imageOverlayDecoration() {
    return const BoxDecoration(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      gradient: MarketOutlookColorStyle.cardGradient,
    );
  }
  
  static BoxDecoration badgeDecoration() {
    return BoxDecoration(
      color: MarketOutlookColorStyle.badgeBackground,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: MarketOutlookColorStyle.greenNeon.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
  
  static BoxDecoration searchBarDecoration({bool isFocused = false}) {
    return BoxDecoration(
      color: MarketOutlookColorStyle.searchBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isFocused 
            ? MarketOutlookColorStyle.greenNeon 
            : MarketOutlookColorStyle.searchBorder,
        width: isFocused ? 1.5 : 1,
      ),
      boxShadow: isFocused 
          ? [
              BoxShadow(
                color: MarketOutlookColorStyle.greenNeon.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );
  }
}