import 'package:flutter/material.dart';

/// Color style untuk Trade Ideas section
class TradeIdeasColorStyle {
  // Background colors
  static const Color backgroundColor = Color(0xFF0A0A0A);
  static const Color cardBackground = Color(0xFF1A1A1A);
  
  // Green theme variations untuk Trade Ideas cards
  static const Color greenPrimary = Color(0xFF00CC44);
  static const Color greenLight = Color(0xFF33FF66);
  static const Color greenDark = Color(0xFF005522);
  static const Color greenOverlay = Color(0x99004411);
  static const Color greenNeon = Color(0xFFBEFF00);
  
  // Trade Ideas badge colors
  static const Color tradeIdeasBadgeBackground = Color(0xFFBEFF00);
  static const Color tradeIdeasBadgeText = Color(0xFF000000);
  
  // Text colors
  static const Color titleText = Color(0xFFFFFFFF);
  static const Color subtitleText = Color(0xFFCCCCCC);
  static const Color sourceText = Color(0xFF888888);
  static const Color highlightText = Color(0xFFBEFF00);
  
  // Button colors
  static const Color addButtonBackground = Color(0xFFBEFF00);
  static const Color addButtonText = Color(0xFF000000);
  
  // Search bar colors
  static const Color searchBackground = Color(0xFF1A1A1A);
  static const Color searchBorder = Color(0xFF2A2A2A);
  static const Color searchText = Color(0xFFFFFFFF);
  static const Color searchPlaceholder = Color(0xFF666666);
  
  // Green gradient overlays for Trade Ideas cards - Enhanced
  static const LinearGradient tradeIdeasCardGradient1 = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x33003311),
      Color(0xCC001A0D),
    ],
    stops: [0.0, 0.8],
  );
  
  static const LinearGradient tradeIdeasCardGradient2 = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x33004422),
      Color(0xCC002211),
    ],
    stops: [0.0, 0.8],
  );
  
  static const LinearGradient tradeIdeasCardGradient3 = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x33005533),
      Color(0xCC002A1A),
    ],
    stops: [0.0, 0.8],
  );
  
  // Bottom text overlay gradient - Enhanced
  static const LinearGradient textOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0xF5000000),
    ],
    stops: [0.2, 1.0],
  );
  
  // Card shadow
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.6),
      blurRadius: 16,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];
  
  static List<BoxShadow> get cardShadowHover => [
    BoxShadow(
      color: greenNeon.withOpacity(0.2),
      blurRadius: 24,
      offset: const Offset(0, 10),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.7),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];
  
  // Text styles
  static const TextStyle tradeIdeasTitleStyle = TextStyle(
    color: titleText,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: -0.3,
    shadows: [
      Shadow(
        color: Color(0xCC000000),
        offset: Offset(0, 2),
        blurRadius: 8,
      ),
    ],
  );
  
  static const TextStyle tradeIdeasSubtitleStyle = TextStyle(
    color: highlightText,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0,
    shadows: [
      Shadow(
        color: Color(0x99000000),
        offset: Offset(0, 1),
        blurRadius: 4,
      ),
    ],
  );
  
  static const TextStyle tradeIdeasSourceStyle = TextStyle(
    color: sourceText,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );
  
  static const TextStyle sectionTitleStyle = TextStyle(
    color: titleText,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );
  
  static const TextStyle badgeTextStyle = TextStyle(
    color: tradeIdeasBadgeText,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
}

/// Theme data untuk trade ideas cards
class tradeIdeasCardTheme {
  static BoxDecoration cardDecoration({
    required int index,
    bool isHovered = false,
  }) {
    // Rotate through different green gradients
    LinearGradient gradient;
    switch (index % 3) {
      case 0:
        gradient = TradeIdeasColorStyle.tradeIdeasCardGradient1;
        break;
      case 1:
        gradient = TradeIdeasColorStyle.tradeIdeasCardGradient2;
        break;
      default:
        gradient = TradeIdeasColorStyle.tradeIdeasCardGradient3;
    }
    
    return BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(16),
      boxShadow: isHovered 
          ? TradeIdeasColorStyle.cardShadowHover 
          : TradeIdeasColorStyle.cardShadow,
      border: Border.all(
        color: isHovered 
            ? TradeIdeasColorStyle.greenNeon.withOpacity(0.4)
            : Colors.transparent,
        width: isHovered ? 1.5 : 1,
      ),
    );
  }
  
  static BoxDecoration textOverlayDecoration() {
    return const BoxDecoration(
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      gradient: TradeIdeasColorStyle.textOverlayGradient,
    );
  }
  
  static BoxDecoration tradeIdeasBadgeDecoration() {
    return BoxDecoration(
      color: TradeIdeasColorStyle.tradeIdeasBadgeBackground,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: TradeIdeasColorStyle.tradeIdeasBadgeBackground.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
  
  static BoxDecoration searchBarDecoration({bool isFocused = false}) {
    return BoxDecoration(
      color: TradeIdeasColorStyle.searchBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isFocused 
            ? TradeIdeasColorStyle.greenNeon 
            : TradeIdeasColorStyle.searchBorder,
        width: isFocused ? 1.5 : 1,
      ),
      boxShadow: isFocused 
          ? [
              BoxShadow(
                color: TradeIdeasColorStyle.greenNeon.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );
  }
}