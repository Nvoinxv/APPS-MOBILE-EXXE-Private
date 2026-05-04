import 'package:flutter/material.dart';
import '../candle/candle_normal.dart';
import '../controller/risk_ratio_button.dart';
import '../trading_screen/tradingviewcodeeditor_screen.dart';

/// ChartControls - Bottom bar dengan popup Tools menu
class ChartControls extends StatefulWidget {
  final CandlestickStyle style;

  final bool showVolume;
  final bool showGrid;
  final bool showCrosshair;
  final bool isFibonacciMode;
  final bool isRiskRatioMode;
  final RiskRatioMode riskRatioMode;

  final VoidCallback onToggleVolume;
  final VoidCallback onToggleGrid;
  final VoidCallback onToggleCrosshair;
  final VoidCallback onToggleFibonacci;
  final VoidCallback onToggleRiskRatio;
  final VoidCallback onSwitchRiskRatioMode;
  final VoidCallback onSettings;
  final VoidCallback onReset;
  final VoidCallback onOpenCodeEditor; // ← NEW
  final Widget?      strategy2Button;

  const ChartControls({
    Key? key,
    required this.style,
    required this.showVolume,
    required this.showGrid,
    required this.showCrosshair,
    required this.isFibonacciMode,
    required this.isRiskRatioMode,
    required this.riskRatioMode,
    required this.onToggleVolume,
    required this.onToggleGrid,
    required this.onToggleCrosshair,
    required this.onToggleFibonacci,
    required this.onToggleRiskRatio,
    required this.onSwitchRiskRatioMode,
    required this.onSettings,
    required this.onReset,
    required this.onOpenCodeEditor, // ← NEW
    this.strategy2Button,
  }) : super(key: key);

  @override
  State<ChartControls> createState() => _ChartControlsState();
}

class _ChartControlsState extends State<ChartControls>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  OverlayEntry? _overlayEntry;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final GlobalKey _toolsBtnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _removeOverlay();
    _animController.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _openMenu() {
    final renderBox =
        _toolsBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final btnPosition = renderBox.localToGlobal(Offset.zero);
    final btnSize     = renderBox.size;

    setState(() => _isOpen = true);

    _overlayEntry = OverlayEntry(
      builder: (context) => _OverlayMenu(
        style:           widget.style,
        btnPosition:     btnPosition,
        btnSize:         btnSize,
        fadeAnim:        _fadeAnim,
        slideAnim:       _slideAnim,
        showVolume:      widget.showVolume,
        showGrid:        widget.showGrid,
        showCrosshair:   widget.showCrosshair,
        isFibonacciMode: widget.isFibonacciMode,
        isRiskRatioMode: widget.isRiskRatioMode,
        riskRatioMode:   widget.riskRatioMode,
        onClose:             _closeMenu,
        onToggleVolume:      () { widget.onToggleVolume();      _closeMenu(); },
        onToggleGrid:        () { widget.onToggleGrid();        _closeMenu(); },
        onToggleCrosshair:   () {
          if (!widget.isFibonacciMode && !widget.isRiskRatioMode) {
            widget.onToggleCrosshair();
          }
          _closeMenu();
        },
        onToggleFibonacci:     () { widget.onToggleFibonacci();     _closeMenu(); },
        onToggleRiskRatio:     () { widget.onToggleRiskRatio();     _closeMenu(); },
        onSwitchRiskRatioMode: () { widget.onSwitchRiskRatioMode(); _closeMenu(); },
        onSettings:            () { widget.onSettings();            _closeMenu(); },
        onOpenCodeEditor:      () { widget.onOpenCodeEditor();      _closeMenu(); }, // ← NEW
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward(from: 0);
  }

  void _closeMenu() {
    _animController.reverse().then((_) {
      _removeOverlay();
      if (mounted) setState(() => _isOpen = false);
    });
  }

  void _toggleMenu() => _isOpen ? _closeMenu() : _openMenu();

  @override
  Widget build(BuildContext context) {
    String? activeLabel;
    if (widget.isFibonacciMode) {
      activeLabel = 'Fibonacci';
    } else if (widget.isRiskRatioMode) {
      activeLabel = widget.riskRatioMode == RiskRatioMode.buy
          ? 'Risk Ratio  ·  Buy'
          : 'Risk Ratio  ·  Sell';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:  widget.style.backgroundColor,
        border: Border(top: BorderSide(color: widget.style.gridColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BarButton(
            icon:     Icons.refresh_rounded,
            label:    'Reset',
            isActive: false,
            style:    widget.style,
            onTap:    widget.onReset,
          ),

          if (widget.strategy2Button != null) ...[
            const SizedBox(width: 8),
            widget.strategy2Button!,
          ],

          if (activeLabel != null) ...[
            const SizedBox(width: 8),
            _ActiveIndicator(
              icon: widget.isFibonacciMode
                  ? Icons.show_chart
                  : (widget.riskRatioMode == RiskRatioMode.buy
                      ? Icons.trending_up
                      : Icons.trending_down),
              label: activeLabel,
              style: widget.style,
              isBuy: widget.riskRatioMode == RiskRatioMode.buy,
            ),
          ],

          const Spacer(),

          _BarButton(
            key:      _toolsBtnKey,
            icon:     _isOpen ? Icons.close_rounded : Icons.tune_rounded,
            label:    _isOpen ? 'Close' : 'Tools',
            isActive: _isOpen,
            style:    widget.style,
            onTap:    _toggleMenu,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Popup menu di Overlay layer
// ─────────────────────────────────────────────
class _OverlayMenu extends StatelessWidget {
  final CandlestickStyle  style;
  final Offset            btnPosition;
  final Size              btnSize;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final bool              showVolume;
  final bool              showGrid;
  final bool              showCrosshair;
  final bool              isFibonacciMode;
  final bool              isRiskRatioMode;
  final RiskRatioMode     riskRatioMode;
  final VoidCallback      onClose;
  final VoidCallback      onToggleVolume;
  final VoidCallback      onToggleGrid;
  final VoidCallback      onToggleCrosshair;
  final VoidCallback      onToggleFibonacci;
  final VoidCallback      onToggleRiskRatio;
  final VoidCallback      onSwitchRiskRatioMode;
  final VoidCallback      onSettings;
  final VoidCallback      onOpenCodeEditor; // ← NEW

  const _OverlayMenu({
    required this.style,
    required this.btnPosition,
    required this.btnSize,
    required this.fadeAnim,
    required this.slideAnim,
    required this.showVolume,
    required this.showGrid,
    required this.showCrosshair,
    required this.isFibonacciMode,
    required this.isRiskRatioMode,
    required this.riskRatioMode,
    required this.onClose,
    required this.onToggleVolume,
    required this.onToggleGrid,
    required this.onToggleCrosshair,
    required this.onToggleFibonacci,
    required this.onToggleRiskRatio,
    required this.onSwitchRiskRatioMode,
    required this.onSettings,
    required this.onOpenCodeEditor, // ← NEW
  });

  @override
  Widget build(BuildContext context) {
    const menuWidth = 220.0;
    final menuRight =
        MediaQuery.of(context).size.width - btnPosition.dx - btnSize.width;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap:    onClose,
            behavior: HitTestBehavior.translucent,
            child:    const ColoredBox(color: Colors.transparent),
          ),
        ),
        Positioned(
          bottom: MediaQuery.of(context).size.height - btnPosition.dy + 8,
          right:  menuRight,
          child: FadeTransition(
            opacity: fadeAnim,
            child: SlideTransition(
              position: slideAnim,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width:   menuWidth,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color:        style.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: style.gridColor),
                    boxShadow: [
                      BoxShadow(
                        color:      Colors.black.withOpacity(0.5),
                        blurRadius: 16,
                        offset:     const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize:       MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          'CHART TOOLS',
                          style: TextStyle(
                            color:         style.textColor.withOpacity(0.4),
                            fontSize:      10,
                            fontWeight:    FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      Divider(color: style.gridColor, height: 1),
                      const SizedBox(height: 4),

                      _MenuItem(
                        icon: Icons.bar_chart_rounded, label: 'Volume',
                        isActive: showVolume, style: style, onTap: onToggleVolume,
                      ),
                      _MenuItem(
                        icon: Icons.grid_4x4_rounded, label: 'Grid',
                        isActive: showGrid, style: style, onTap: onToggleGrid,
                      ),
                      _MenuItem(
                        icon: Icons.control_camera_rounded, label: 'Crosshair',
                        isActive: showCrosshair && !isFibonacciMode && !isRiskRatioMode,
                        style: style, onTap: onToggleCrosshair,
                      ),
                      _MenuItem(
                        icon: Icons.show_chart_rounded, label: 'Fibonacci',
                        isActive: isFibonacciMode, style: style, onTap: onToggleFibonacci,
                      ),
                      _MenuItem(
                        icon: riskRatioMode == RiskRatioMode.buy
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        label: 'Risk Ratio  ·  '
                            '${riskRatioMode == RiskRatioMode.buy ? 'Buy' : 'Sell'}',
                        isActive:    isRiskRatioMode,
                        style:       style,
                        onTap:       onToggleRiskRatio,
                        onLongPress: onSwitchRiskRatioMode,
                        activeColor: riskRatioMode == RiskRatioMode.buy
                            ? style.bullishColor
                            : style.bearishColor,
                      ),

                      Divider(color: style.gridColor, height: 12),

                      // ── Pine Script Editor ────────────────────────────────
                      _MenuItem(
                        icon:     Icons.code_rounded,
                        label:    'Pine Script Editor',
                        isActive: false,
                        style:    style,
                        onTap:    onOpenCodeEditor,
                      ),

                      _MenuItem(
                        icon: Icons.palette_outlined, label: 'Style Settings',
                        isActive: false, style: style, onTap: onSettings,
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Tombol bottom bar
// ─────────────────────────────────────────────
class _BarButton extends StatelessWidget {
  final IconData         icon;
  final String           label;
  final bool             isActive;
  final CandlestickStyle style;
  final VoidCallback     onTap;

  const _BarButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.style,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activeColor = style.bullishColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withOpacity(0.12)
              : style.gridColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor : style.gridColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16,
                color: isActive ? activeColor : style.textColor),
            const SizedBox(width: 6),
            Text(label,
              style: TextStyle(
                color:      isActive ? activeColor : style.textColor,
                fontSize:   12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Active indicator
// ─────────────────────────────────────────────
class _ActiveIndicator extends StatelessWidget {
  final IconData         icon;
  final String           label;
  final CandlestickStyle style;
  final bool             isBuy;

  const _ActiveIndicator({
    required this.icon, required this.label,
    required this.style, required this.isBuy,
  });

  @override
  Widget build(BuildContext context) {
    final color = style.bullishColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
            style: TextStyle(
              color: color, fontSize: 11,
              fontWeight: FontWeight.w600, letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Menu item popup
// ─────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData         icon;
  final String           label;
  final bool             isActive;
  final CandlestickStyle style;
  final VoidCallback     onTap;
  final VoidCallback?    onLongPress;
  final Color?           activeColor;

  const _MenuItem({
    required this.icon, required this.label,
    required this.isActive, required this.style, required this.onTap,
    this.onLongPress, this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? style.bullishColor;
    return GestureDetector(
      onTap:       onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin:   const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color.withOpacity(0.35) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18,
                color: isActive ? color : style.textColor.withOpacity(0.7)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                style: TextStyle(
                  color:      isActive ? color : style.textColor,
                  fontSize:   13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isActive) Icon(Icons.check_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}