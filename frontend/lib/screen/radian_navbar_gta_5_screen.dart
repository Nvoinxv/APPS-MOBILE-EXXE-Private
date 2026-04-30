import 'package:flutter/material.dart';
import 'dart:ui';

/// GTA V Style Radial Menu - WITH DEBUG MODE
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

  // 🔴 DEBUG MODE - Set true untuk lihat posisi
  static const bool DEBUG_MODE = false;

  // MANUAL POSITIONING - Test values
  final List<RadialMenuItem> _menuItems = [
  RadialMenuItem(
    icon: Icons.lightbulb_outline,
    label: 'Trade Ideas',
    section: 'trade_ideas',
    offsetX: -120.0,  // KIRI
    offsetY: 60.0,    
  ),
  RadialMenuItem(
    icon: Icons.trending_up_outlined,
    label: 'Market',
    section: 'market_outlook',
    offsetX: 0.0,     // TENGAH PUNCAK
    offsetY: 140.0,   
  ),
  RadialMenuItem(
    icon: Icons.search_outlined,
    label: 'Research Coin',
    section: 'research_coin',
    offsetX: 120.0,   // KANAN
    offsetY: 60.0,    
  ),
];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
    // 🔴 DEBUG: Print saat widget dibuat
    if (DEBUG_MODE) {
      print('🔴 RadialCircleMenu initialized');
      for (var item in _menuItems) {
        print('  ${item.label}: X=${item.offsetX}, Y=${item.offsetY}');
      }
    }
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
        tween: Tween<double>(begin: 1.0, end: 0.7)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.7, end: 1.0)
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
    
    // 🔴 DEBUG
    if (DEBUG_MODE) {
      print('🔴 Menu ${_isExpanded ? 'EXPANDED' : 'COLLAPSED'}');
    }
  }

  void _selectItem(String section) {
    widget.onNavigate(section);
    _toggleMenu();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || _scaleAnimation == null || _rotationAnimation == null) {
      return const SizedBox.shrink();
    }

    return Stack(
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
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
            ),
          ),
        
        // Gaussian Blur Background
        if (_isExpanded)
          _buildBlurBackground(),
        
        // Radial Menu Items
        ..._buildRadialItems(),
        
        // Central Button
        _buildCentralButton(),
        
        // 🔴 DEBUG OVERLAY
        if (DEBUG_MODE && _isExpanded)
          _buildDebugOverlay(),
      ],
    );
  }

  // 🔴 DEBUG OVERLAY
  Widget _buildDebugOverlay() {
    const fabSize = 80.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final fabLeft = (screenWidth / 2) - (fabSize / 2);
    final centerX = fabLeft + fabSize / 2;
    final centerY = 10 + fabSize / 2;

    return Positioned(
      left: 10,
      top: 100,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔴 DEBUG MODE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text('Center: ($centerX, $centerY)', style: const TextStyle(color: Colors.white, fontSize: 11)),
            const SizedBox(height: 8),
            ..._menuItems.map((item) => Text(
              '${item.label}: (${item.offsetX}, ${item.offsetY})',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurBackground() {
    const fabSize = 80.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final fabLeft = (screenWidth / 2) - (fabSize / 2);
    final centerX = fabLeft + fabSize / 2;
    final centerY = 10 + fabSize / 2;

    return AnimatedBuilder(
      animation: _scaleAnimation!,
      builder: (context, child) {
        final scale = _scaleAnimation!.value.clamp(0.0, 1.0);
        
        return Positioned(
          left: centerX - 150,
          bottom: centerY - 150,
          child: Opacity(
            opacity: scale * 0.9,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF5FAD56).withOpacity(0.3),
                    const Color(0xFF2D5A2D).withOpacity(0.2),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
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

  List<Widget> _buildRadialItems() {
    return _menuItems.map((item) {
      return _buildRadialMenuItem(item);
    }).toList();
  }

  Widget _buildRadialMenuItem(RadialMenuItem item) {
    final isActive = widget.activeSection == item.section;

    const fabSize = 80.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final fabLeft = (screenWidth / 2) - (fabSize / 2);
    final centerX = fabLeft + fabSize / 2;
    final centerY = 10 + fabSize / 2;

    return AnimatedBuilder(
      animation: _scaleAnimation!,
      builder: (context, child) {
        final scale = _scaleAnimation!.value.clamp(0.0, 1.0);
        
        final x = item.offsetX * scale;
        final y = item.offsetY * scale;

        // 🔴 DEBUG: Print position
        if (DEBUG_MODE && scale > 0.9) {
          print('  ${item.label}: finalX=$x, finalY=$y');
        }

        return Positioned(
          left: centerX + x - 35,
          bottom: centerY + y - 35,
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
            size: 30,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? const Color(0xFF5FAD56) : Colors.grey[700]!,
              width: 1.5,
            ),
          ),
          child: Text(
            item.label,
            style: TextStyle(
              color: isActive ? const Color(0xFF5FAD56) : Colors.white70,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCentralButton() {
    const fabSize = 80.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final fabLeft = (screenWidth / 2) - (fabSize / 2);

    return Positioned(
      bottom: 10,
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
                          child: Image.asset(
                            '/home/nvoinxv/Documents/APPS-MOBILE-EXXE-Private/frontend/assets/logo_exxe_no_background.png',
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
  final double offsetX;
  final double offsetY;

  RadialMenuItem({
    required this.icon,
    required this.label,
    required this.section,
    required this.offsetX,
    required this.offsetY,
  });
}