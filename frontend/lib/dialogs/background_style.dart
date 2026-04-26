import 'package:flutter/material.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum BgMode { solid, gradient, image }

enum BgGradientDirection {
  leftToRight,
  rightToLeft,
  topToBottom,
  bottomToTop,
  topLeftToBottomRight,
  topRightToBottomLeft,
  bottomLeftToTopRight,
  bottomRightToTopLeft,
}

extension BgGradientDirectionExt on BgGradientDirection {
  String get label => switch (this) {
    BgGradientDirection.leftToRight          => '→',
    BgGradientDirection.rightToLeft          => '←',
    BgGradientDirection.topToBottom          => '↓',
    BgGradientDirection.bottomToTop          => '↑',
    BgGradientDirection.topLeftToBottomRight => '↘',
    BgGradientDirection.topRightToBottomLeft => '↙',
    BgGradientDirection.bottomLeftToTopRight => '↗',
    BgGradientDirection.bottomRightToTopLeft => '↖',
  };

  Alignment get begin => switch (this) {
    BgGradientDirection.leftToRight          => Alignment.centerLeft,
    BgGradientDirection.rightToLeft          => Alignment.centerRight,
    BgGradientDirection.topToBottom          => Alignment.topCenter,
    BgGradientDirection.bottomToTop          => Alignment.bottomCenter,
    BgGradientDirection.topLeftToBottomRight => Alignment.topLeft,
    BgGradientDirection.topRightToBottomLeft => Alignment.topRight,
    BgGradientDirection.bottomLeftToTopRight => Alignment.bottomLeft,
    BgGradientDirection.bottomRightToTopLeft => Alignment.bottomRight,
  };

  Alignment get end => switch (this) {
    BgGradientDirection.leftToRight          => Alignment.centerRight,
    BgGradientDirection.rightToLeft          => Alignment.centerLeft,
    BgGradientDirection.topToBottom          => Alignment.bottomCenter,
    BgGradientDirection.bottomToTop          => Alignment.topCenter,
    BgGradientDirection.topLeftToBottomRight => Alignment.bottomRight,
    BgGradientDirection.topRightToBottomLeft => Alignment.bottomLeft,
    BgGradientDirection.bottomLeftToTopRight => Alignment.topRight,
    BgGradientDirection.bottomRightToTopLeft => Alignment.topLeft,
  };
}

enum BgImageFit { cover, contain, fill, none }

extension BgImageFitExt on BgImageFit {
  String get label => switch (this) {
    BgImageFit.cover   => 'Cover',
    BgImageFit.contain => 'Contain',
    BgImageFit.fill    => 'Fill',
    BgImageFit.none    => 'None',
  };

  BoxFit get boxFit => switch (this) {
    BgImageFit.cover   => BoxFit.cover,
    BgImageFit.contain => BoxFit.contain,
    BgImageFit.fill    => BoxFit.fill,
    BgImageFit.none    => BoxFit.none,
  };
}

// ── State ─────────────────────────────────────────────────────────────────────

@immutable
class BackgroundStyleState {
  final BgMode   mode;
  final double   opacity; // 0–1, berlaku di semua mode

  // Solid
  final Color solidColor;

  // Gradient
  final Color                solidColorEnd; // warna kedua gradient
  final BgGradientDirection  gradientDirection;

  // Image
  final String?   imagePath; // URL atau asset path
  final BgImageFit imageFit;
  final double     imageOpacity; // overlay opacity khusus image (0–1)
  final Color      imageOverlayColor; // warna overlay di atas gambar

  const BackgroundStyleState({
    this.mode             = BgMode.solid,
    this.opacity          = 1.0,
    this.solidColor       = const Color(0xFF0A0E17),
    this.solidColorEnd    = const Color(0xFF0D1B2A),
    this.gradientDirection = BgGradientDirection.topToBottom,
    this.imagePath        = null,
    this.imageFit         = BgImageFit.cover,
    this.imageOpacity     = 0.15,
    this.imageOverlayColor = const Color(0xFF0A0E17),
  });

  BackgroundStyleState copyWith({
    BgMode?               mode,
    double?               opacity,
    Color?                solidColor,
    Color?                solidColorEnd,
    BgGradientDirection?  gradientDirection,
    String?               imagePath,
    bool                  clearImage = false,
    BgImageFit?           imageFit,
    double?               imageOpacity,
    Color?                imageOverlayColor,
  }) {
    return BackgroundStyleState(
      mode:              mode              ?? this.mode,
      opacity:           opacity           ?? this.opacity,
      solidColor:        solidColor        ?? this.solidColor,
      solidColorEnd:     solidColorEnd     ?? this.solidColorEnd,
      gradientDirection: gradientDirection ?? this.gradientDirection,
      imagePath:         clearImage ? null : (imagePath ?? this.imagePath),
      imageFit:          imageFit          ?? this.imageFit,
      imageOpacity:      imageOpacity      ?? this.imageOpacity,
      imageOverlayColor: imageOverlayColor ?? this.imageOverlayColor,
    );
  }

  // Presets
  static const dark    = BackgroundStyleState();
  static const midnight = BackgroundStyleState(solidColor: Color(0xFF0D1B2A));
  static const matrix  = BackgroundStyleState(solidColor: Color(0xFF0D0208), solidColorEnd: Color(0xFF020802));
  static const ocean   = BackgroundStyleState(
    mode: BgMode.gradient,
    solidColor: Color(0xFF011627), solidColorEnd: Color(0xFF041E34),
    gradientDirection: BgGradientDirection.topToBottom,
  );
  static const sunset  = BackgroundStyleState(
    mode: BgMode.gradient,
    solidColor: Color(0xFF1A1A2E), solidColorEnd: Color(0xFF2D1B4E),
    gradientDirection: BgGradientDirection.bottomToTop,
  );
  static const light   = BackgroundStyleState(solidColor: Color(0xFFFAFAFA), solidColorEnd: Color(0xFFF0F4FF));

  // Konversi ke Color (untuk backward compat dgn CandlestickStyle.backgroundColor)
  Color get primaryColor => solidColor;
}

// ── Background Layer widget ───────────────────────────────────────────────────
// Bungkus chart dengan widget ini supaya background bisa image/gradient/solid.

class BackgroundLayer extends StatelessWidget {
  final BackgroundStyleState style;
  final Widget               child;

  const BackgroundLayer({super.key, required this.style, required this.child});

  bool get _isUrl =>
      (style.imagePath ?? '').startsWith('http://') ||
      (style.imagePath ?? '').startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: Base background ─────────────────────────────────────
        Opacity(
          opacity: style.opacity,
          child: _buildBase(),
        ),

        // ── Layer 2: Image overlay (if image mode) ────────────────────────
        if (style.mode == BgMode.image &&
            style.imagePath != null &&
            style.imagePath!.isNotEmpty) ...[
          Opacity(
            opacity: style.imageOpacity,
            child: _buildImage(),
          ),
          // Dark overlay di atas image biar chart tetap terbaca
          Container(color: style.imageOverlayColor.withOpacity(0.45)),
        ],

        // ── Layer 3: Chart content ────────────────────────────────────────
        child,
      ],
    );
  }

  Widget _buildBase() {
    switch (style.mode) {
      case BgMode.solid:
        return Container(color: style.solidColor);

      case BgMode.gradient:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [style.solidColor, style.solidColorEnd],
              begin:  style.gradientDirection.begin,
              end:    style.gradientDirection.end,
            ),
          ),
        );

      case BgMode.image:
        // Image mode: base tetap solid/gelap supaya chart terbaca
        return Container(color: style.solidColor);
    }
  }

  Widget _buildImage() {
    if (_isUrl) {
      return Image.network(
        style.imagePath!,
        fit:         style.imageFit.boxFit,
        errorBuilder: (_, __, ___) => Container(color: style.solidColor),
      );
    }
    return Image.asset(
      style.imagePath!,
      fit:         style.imageFit.boxFit,
      errorBuilder: (_, __, ___) => Container(color: style.solidColor),
    );
  }
}

// ── Presets list ──────────────────────────────────────────────────────────────

class BackgroundPreset {
  final String              name;
  final BackgroundStyleState state;
  const BackgroundPreset({required this.name, required this.state});

  static List<BackgroundPreset> all() => const [
    BackgroundPreset(name: 'Dark',     state: BackgroundStyleState.dark),
    BackgroundPreset(name: 'Midnight', state: BackgroundStyleState.midnight),
    BackgroundPreset(name: 'Matrix',   state: BackgroundStyleState.matrix),
    BackgroundPreset(name: 'Ocean',    state: BackgroundStyleState.ocean),
    BackgroundPreset(name: 'Sunset',   state: BackgroundStyleState.sunset),
    BackgroundPreset(name: 'Light',    state: BackgroundStyleState.light),
  ];
}