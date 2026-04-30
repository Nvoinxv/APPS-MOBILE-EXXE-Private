// ============================================================
// FILE: lib/style/payment_color_style.dart
// ============================================================
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT COLOR STYLE
// Sinkron sama StreetViewColorStyle — dark green neon theme
// ─────────────────────────────────────────────────────────────────────────────
class PaymentColorStyle {
  PaymentColorStyle._(); // non-instantiable

  // ── Background ──────────────────────────────────────────────────────────────
  static const Color backgroundColor = Color(0xFF0A0A0A);
  static const Color surfaceColor    = Color(0xFF111111);
  static const Color cardBackground  = Color(0xFF1A1A1A);

  // ── Green theme ─────────────────────────────────────────────────────────────
  static const Color greenPrimary = Color(0xFF00CC44);
  static const Color greenLight   = Color(0xFF33FF66);
  static const Color greenDark    = Color(0xFF005522);
  static const Color greenOverlay = Color(0x99004411);
  static const Color greenNeon    = Color(0xFF00CC44);
  static const Color greenDim     = Color(0x2200CC44);

  // ── Accent / state ──────────────────────────────────────────────────────────
  static const Color errorRed   = Color(0xFFEF4444);
  static const Color goldAccent = Color(0xFFFFCC00);
  static const Color dimGold    = Color(0x33FFCC00);

  // ── Text ────────────────────────────────────────────────────────────────────
  static const Color titleText     = Color(0xFFFFFFFF);
  static const Color subtitleText  = Color(0xFFCCCCCC);
  static const Color bodyText      = Color(0xFF888888);
  static const Color highlightText = Color(0xFF00CC44);
  static const Color disabledText  = Color(0xFF444444);

  // ── Border ──────────────────────────────────────────────────────────────────
  static const Color borderColor = Color(0xFF2A2A2A);
  static const Color borderFocus = Color(0xFF00CC44);

  // ── Gradients ───────────────────────────────────────────────────────────────
  static const LinearGradient planCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1E1E), Color(0xFF141414)],
  );

  static const LinearGradient selectedPlanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF003A1A), Color(0xFF001A0D)],
  );

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF00CC44), Color(0xFF00AA33)],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x33003311), Color(0x00000000)],
  );

  // ── Shadows — pakai getter karena withOpacity tidak bisa const ───────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.5),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get selectedCardShadow => [
    BoxShadow(
      color: greenNeon.withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 6),
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.6),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get ctaShadow => [
    BoxShadow(
      color: greenNeon.withOpacity(0.35),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: 2,
    ),
  ];

  // ── Text styles — static final karena referensi Color dari class yang sama ───
  // ⚠️ TIDAK BISA const: Dart tidak izinkan const TextStyle yang referensi
  //    static const Color dari class lain sebagai compile-time constant.
  //    Solusi: pakai static final.
  static final TextStyle displayStyle = const TextStyle(
    color: titleText,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    height: 1.1,
  );

  static final TextStyle headingStyle = const TextStyle(
    color: titleText,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static final TextStyle labelStyle = const TextStyle(
    color: subtitleText,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static final TextStyle captionStyle = const TextStyle(
    color: bodyText,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
  );

  static final TextStyle greenBadgeStyle = const TextStyle(
    color: backgroundColor,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
  );

  static final TextStyle priceStyle = const TextStyle(
    color: titleText,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  static final TextStyle pricePeriodStyle = const TextStyle(
    color: bodyText,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );
}