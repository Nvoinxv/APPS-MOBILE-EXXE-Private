import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

/// GTA V Style Radial Menu - FIXED POSITIONING
class RadialCircleMenu extends StatefulWidget {
  final String activeSection;
  final Function(String) onNavigate;

  const RadialCircleMenu({
    super.key,
    required this.activeSection,
    required this.onNavigate,
  });

  @override
  State<RadialCircleMenu> createState() => _RadialCircleMenuState();
}

class _RadialCircleMenuState extends State<RadialCircleMenu>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;
  Animation<double>? _rotationAnimation;

  // FAB size & radius
  static const double fabSize = 80.0;
  static const double fabBottomPadding = 10.0;

  // ✅ RADIUS DIPERKECIL agar menu item tidak terlalu jauh
  static const double menuRadius = 110.0;

  // Menu items dengan angle dalam derajat (180° = kiri, 90° = atas, 0° = kanan)
  // Setengah lingkaran ke atas: dari 150° ke 30° (3 items merata)
  final List<RadialMenuItem> _menuItems = [
    RadialMenuItem(
      icon: Icons.lightbulb_outline,
      label: 'Trade Ideas',
      section: 'trade_ideas',
      angleDeg: 150.0, // Kiri
    ),
    RadialMenuItem(
      icon: Icons.trending_up_outlined,
      label: 'Market',
      section: 'market_outlook',
      angleDeg: 90.0, // Tengah atas
    ),
    RadialMenuItem(
      icon: Icons.search_outlined,
      label: 'Research Coin',
      section: 'research_coin',
      angleDeg: 30.0, // Kanan
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutBack,
    );

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.85)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_controller!);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_controller == null) return;
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller!.forward();
      } else {
        _controller!.reverse();
      }
    });
  }

  void _selectItem(String section) {
    widget.onNavigate(section);
    _toggleMenu();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null ||
        _scaleAnimation == null ||
        _rotationAnimation == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background Overlay
        if (_isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleMenu,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isExpanded ? 1.0 : 0.0,
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            ),
          ),

        // Gaussian Blur Background (glow)
        if (_isExpanded) _buildBlurBackground(context),

        // ✅ Radial Menu Items — pakai trigonometri
        ..._buildRadialItems(context),

        // Central Button
        _buildCentralButton(context),
      ],
    );
  }

  Widget _buildBlurBackground(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Center X = tengah layar, Center Y = dari bawah = fabBottomPadding + fabSize/2
    final centerX = screenWidth / 2;
    final glowSize = menuRadius * 2.8;

    return AnimatedBuilder(
      animation: _scaleAnimation!,
      builder: (context, child) {
        final scale = _scaleAnimation!.value.clamp(0.0, 1.0);
        return Positioned(
          left: centerX - glowSize / 2,
          // Posisi dari bawah: center tombol dikurangi setengah glow
          bottom: fabBottomPadding + fabSize / 2 - glowSize / 2,
          child: Opacity(
            opacity: scale * 0.85,
            child: Container(
              width: glowSize,
              height: glowSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF5FAD56).withOpacity(0.25),
                    const Color(0xFF2D5A2D).withOpacity(0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.0),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildRadialItems(BuildContext context) {
    return _menuItems.map((item) => _buildRadialMenuItem(item, context)).toList();
  }

  Widget _buildRadialMenuItem(RadialMenuItem item, BuildContext context) {
    final isActive = widget.activeSection == item.section;
    final screenWidth = MediaQuery.of(context).size.width;

    // ✅ Pusat tombol FAB
    final centerX = screenWidth / 2;
    // centerY dari bawah layar
    final centerYFromBottom = fabBottomPadding + fabSize / 2;

    // ✅ Hitung posisi pakai trigonometri
    final angleRad = item.angleDeg * math.pi / 180.0;
    final offsetX = menuRadius * math.cos(angleRad);
    final offsetY = menuRadius * math.sin(angleRad);

    // Item size (70x70 circle + label)
    const itemSize = 70.0;

    return AnimatedBuilder(
      animation: _scaleAnimation!,
      builder: (context, child) {
        final scale = _scaleAnimation!.value.clamp(0.0, 1.0);

        // Animasi scale dari 0 ke target offset
        final animX = offsetX * scale;
        final animY = offsetY * scale;

        // Posisi final item (center item = centerX + animX, dari bawah = centerYFromBottom + animY)
        final itemLeft = centerX + animX - itemSize / 2;
        final itemBottom = centerYFromBottom + animY - itemSize / 2;

        return Positioned(
          left: itemLeft,
          bottom: itemBottom,
          child: Opacity(
            opacity: scale,
            child: GestureDetector(
              onTap: () => _selectItem(item.section),
              child: _buildMenuItemUI(item, isActive),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItemUI(RadialMenuItem item, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: isActive
                  ? [const Color(0xFF5FAD56), const Color(0xFF2D5A2D)]
                  : [Colors.grey[800]!, Colors.grey[900]!],
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? const Color(0xFF5FAD56).withOpacity(0.6)
                    : Colors.black.withOpacity(0.3),
                blurRadius: isActive ? 25 : 10,
                spreadRadius: isActive ? 5 : 0,
              ),
            ],
            border: Border.all(
              color: isActive ? const Color(0xFF5FAD56) : Colors.grey[700]!,
              width: 2,
            ),
          ),
          child: Icon(
            item.icon,
            color: isActive ? Colors.black : Colors.white70,
            size: 28,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? const Color(0xFF5FAD56) : Colors.grey[700]!,
              width: 1.5,
            ),
          ),
          child: Text(
            item.label,
            style: TextStyle(
              color: isActive ? const Color(0xFF5FAD56) : Colors.white70,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCentralButton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fabLeft = (screenWidth / 2) - (fabSize / 2);

    return Positioned(
      bottom: fabBottomPadding,
      left: fabLeft,
      child: GestureDetector(
        onTap: _toggleMenu,
        child: AnimatedBuilder(
          animation: _controller!,
          builder: (context, child) {
            final progress = _controller!.value;
            final scale = _rotationAnimation!.value;

            final borderColor = Color.lerp(
              Colors.white,
              const Color(0xFF5FAD56),
              progress,
            )!;

            final glowColor = Color.lerp(
              Colors.white.withOpacity(0.3),
              const Color(0xFF5FAD56).withOpacity(0.5),
              progress,
            )!;

            return SizedBox(
              width: fabSize,
              height: fabSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (progress > 0.1)
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: fabSize + 40,
                        height: fabSize + 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              glowColor.withOpacity(0.5 * progress),
                              glowColor.withOpacity(0.3 * progress),
                              glowColor.withOpacity(0.1 * progress),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.3, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),
                  if (progress > 0.1)
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: fabSize + 20,
                        height: fabSize + 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              glowColor.withOpacity(0.4 * progress),
                              glowColor.withOpacity(0.2 * progress),
                              Colors.transparent,
                            ],
                            stops: const [0.5, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: fabSize,
                      height: fabSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                        boxShadow: [
                          BoxShadow(
                            color: borderColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: borderColor,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          // ✅ Relative path — tidak pakai absolute path
                          child: Image.asset(
                            'assets/logo_exxe_no_background.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class RadialMenuItem {
  final IconData icon;
  final String label;
  final String section;

  /// Sudut dalam derajat (0° = kanan, 90° = atas, 180° = kiri)
  final double angleDeg;

  RadialMenuItem({
    required this.icon,
    required this.label,
    required this.section,
    required this.angleDeg,
  });
}