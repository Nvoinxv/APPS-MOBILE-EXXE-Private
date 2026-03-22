import 'package:flutter/material.dart';

/// Color style untuk Research Coin Section - CONSISTENT GREEN THEME
class ResearchCoinColorStyle {
  // ==================== BACKGROUND COLORS ====================
  static const Color backgroundColor = Color(0xFF0A0A0A);
  static const Color cardBackground = Color(0xFF1A1A1A);
  
  // ==================== GREEN THEME (CONSISTENT DENGAN SECTIONS LAIN) ====================
  static const Color greenPrimary = Color(0xFF5FAD56);      // ✅ Sama dengan Daily Research
  static const Color greenLight = Color(0xFF7AC474);        // ✅ Light variant
  static const Color greenDark = Color(0xFF2D5A2D);         // ✅ Dark variant
  static const Color greenOverlay = Color(0x995FAD56);      // ✅ Overlay
  static const Color greenNeon = Color(0xFF5FAD56);         // ✅ Neon effect sama aja
  
  // ==================== BADGE COLORS ====================
  static const Color badgeBackground = Color(0xFF5FAD56);   // ✅ HIJAU, bukan kuning!
  static const Color badgeText = Color(0xFF000000);
  
  // ==================== TEXT COLORS ====================
  static const Color titleText = Color(0xFFFFFFFF);
  static const Color subtitleText = Color(0xFFCCCCCC);
  static const Color sourceText = Color(0xFF888888);
  static const Color highlightText = Color(0xFF5FAD56);     // ✅ HIJAU
  static const Color descriptionText = Color(0xFF999999);
  
  // ==================== BUTTON COLORS ====================
  static const Color addButtonBackground = Color(0xFF5FAD56); // ✅ HIJAU
  static const Color addButtonText = Color(0xFF000000);
  
  // ==================== SEARCH BAR COLORS ====================
  static const Color searchBackground = Color(0xFF1A1A1A);
  static const Color searchBorder = Color(0xFF2A2A2A);
  static const Color searchText = Color(0xFFFFFFFF);
  static const Color searchPlaceholder = Color(0xFF666666);
  
  // ==================== CHART COLORS ====================
  static const Color chartGreen = Color(0xFF5FAD56);        // ✅ HIJAU
  static const Color chartArea = Color(0x335FAD56);         // ✅ HIJAU transparent
  static const Color cardBorder = Color(0xFF2A2A2A);
  
  // ==================== CARD GRADIENTS (HIJAU GELAP) ====================
  static const LinearGradient cardGradient1 = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x331A3A1A),  // ✅ Hijau gelap transparent
      Color(0xCC0D1F0D),  // ✅ Hijau sangat gelap
    ],
    stops: [0.0, 0.8],
  );
  
  static const LinearGradient cardGradient2 = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x33264D26),  // ✅ Hijau gelap variant 2
      Color(0xCC122612),  // ✅ Hijau sangat gelap variant 2
    ],
    stops: [0.0, 0.8],
  );
  
  static const LinearGradient cardGradient3 = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x332D5A2D),  // ✅ Hijau gelap variant 3
      Color(0xCC162D16),  // ✅ Hijau sangat gelap variant 3
    ],
    stops: [0.0, 0.8],
  );
  
  // ==================== TEXT OVERLAY GRADIENT ====================
  static const LinearGradient textOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0xF5000000),
    ],
    stops: [0.2, 1.0],
  );
  
  // ==================== IMAGE OVERLAY GRADIENT ====================
  static const LinearGradient imageOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0x99000000),
    ],
    stops: [0.4, 1.0],
  );
  
  // ==================== CARD SHADOWS ====================
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
      color: greenNeon.withOpacity(0.3),  // ✅ Hijau glow
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
  
  // ==================== TEXT STYLES ====================
  static const TextStyle cardTitleStyle = TextStyle(
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
  
  static const TextStyle cardSubtitleStyle = TextStyle(
    color: highlightText,  // ✅ Hijau
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
  
  static const TextStyle cardDescriptionStyle = TextStyle(
    color: descriptionText,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.1,
  );
  
  static const TextStyle cardSourceStyle = TextStyle(
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
    color: badgeText,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
  
  static const TextStyle categoryLabelStyle = TextStyle(
    color: badgeText,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );
}

/// Theme data untuk Research Coin cards
class ResearchCoinCardTheme {
  static BoxDecoration cardDecoration({
    int index = 0,
    bool isHovered = false,
  }) {
    // Rotate through different green gradients
    LinearGradient gradient;
    switch (index % 3) {
      case 0:
        gradient = ResearchCoinColorStyle.cardGradient1;
        break;
      case 1:
        gradient = ResearchCoinColorStyle.cardGradient2;
        break;
      default:
        gradient = ResearchCoinColorStyle.cardGradient3;
    }
    
    return BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(16),
      boxShadow: isHovered 
          ? ResearchCoinColorStyle.cardShadowHover 
          : ResearchCoinColorStyle.cardShadow,
      border: Border.all(
        color: isHovered 
            ? ResearchCoinColorStyle.greenNeon.withOpacity(0.4)
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
      gradient: ResearchCoinColorStyle.textOverlayGradient,
    );
  }
  
  static BoxDecoration imageOverlayDecoration() {
    return const BoxDecoration(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      gradient: ResearchCoinColorStyle.imageOverlayGradient,
    );
  }
  
  static BoxDecoration badgeDecoration() {
    return BoxDecoration(
      color: ResearchCoinColorStyle.badgeBackground,  // ✅ Hijau sekarang
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: ResearchCoinColorStyle.badgeBackground.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
  
  static BoxDecoration categoryBadgeDecoration() {
    return BoxDecoration(
      color: ResearchCoinColorStyle.badgeBackground,  // ✅ Hijau sekarang
      borderRadius: BorderRadius.circular(6),
      boxShadow: [
        BoxShadow(
          color: ResearchCoinColorStyle.badgeBackground.withOpacity(0.2),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
  
  static BoxDecoration searchBarDecoration({bool isFocused = false}) {
    return BoxDecoration(
      color: ResearchCoinColorStyle.searchBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isFocused 
            ? ResearchCoinColorStyle.greenNeon  // ✅ Hijau border
            : ResearchCoinColorStyle.searchBorder,
        width: isFocused ? 1.5 : 1,
      ),
      boxShadow: isFocused 
          ? [
              BoxShadow(
                color: ResearchCoinColorStyle.greenNeon.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );
  }
}