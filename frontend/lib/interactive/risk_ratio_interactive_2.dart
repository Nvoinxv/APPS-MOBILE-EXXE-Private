import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller/risk_ratio_button.dart';
import '../controller/chart_viewport.dart';
import '../controller/overlay_action_controller.dart';
import '../controller/cloneable_overlay.dart';
import '../dialogs/overlay_context_menu.dart';

// ===========================================================================
// RiskRatioOverlay — data model dalam DATA SPACE
// ===========================================================================

class RiskRatioOverlay implements CloneableOverlay<RiskRatioOverlay> {
  final double entryPrice;
  final double stopLossPrice;
  final double takeProfitPrice;
  final double leftIndexF;
  final double rightIndexF;
  final RiskRatioMode mode;
  final bool isLocked;

  const RiskRatioOverlay({
    required this.entryPrice,
    required this.stopLossPrice,
    required this.takeProfitPrice,
    required this.leftIndexF,
    required this.rightIndexF,
    required this.mode,
    this.isLocked = false,
  });

  double get risk            => (entryPrice - stopLossPrice).abs();
  double get reward          => (takeProfitPrice - entryPrice).abs();
  double get riskRewardRatio => risk == 0 ? 0 : reward / risk;
  String get rrText          => '1:${riskRewardRatio.toStringAsFixed(2)}';
  bool   get isProfitable    => riskRewardRatio >= 1.5;
  double get widthIndex      => rightIndexF - leftIndexF;

  double leftX(ChartViewport vp)   => DataSpacePoint(candleIndexF: leftIndexF,  price: 0).toScreen(vp).dx;
  double rightX(ChartViewport vp)  => DataSpacePoint(candleIndexF: rightIndexF, price: 0).toScreen(vp).dx;
  double entryY(ChartViewport vp)  => vp.priceToY(entryPrice);
  double slY(ChartViewport vp)     => vp.priceToY(stopLossPrice);
  double tpY(ChartViewport vp)     => vp.priceToY(takeProfitPrice);
  double centerX(ChartViewport vp) => (leftX(vp) + rightX(vp)) / 2;
  double width(ChartViewport vp)   => rightX(vp) - leftX(vp);

  // ── CloneableOverlay implementation ──────────────────────────────────────

  @override
  String get overlayId =>
      '${leftIndexF.toStringAsFixed(2)}_${entryPrice.toStringAsFixed(4)}_${mode.name}';

  @override
  RiskRatioOverlay copyWith({
    double? entryPrice,
    double? stopLossPrice,
    double? takeProfitPrice,
    double? leftIndexF,
    double? rightIndexF,
    RiskRatioMode? mode,
    bool? isLocked,
  }) {
    return RiskRatioOverlay(
      entryPrice:      entryPrice      ?? this.entryPrice,
      stopLossPrice:   stopLossPrice   ?? this.stopLossPrice,
      takeProfitPrice: takeProfitPrice ?? this.takeProfitPrice,
      leftIndexF:      leftIndexF      ?? this.leftIndexF,
      rightIndexF:     rightIndexF     ?? this.rightIndexF,
      mode:            mode            ?? this.mode,
      isLocked:        isLocked        ?? this.isLocked,
    );
  }

  @override
  RiskRatioOverlay cloneWithOffset({
    required double candleOffset,
    required double priceOffset,
  }) {
    return RiskRatioOverlay(
      entryPrice:      entryPrice      + priceOffset,
      stopLossPrice:   stopLossPrice   + priceOffset,
      takeProfitPrice: takeProfitPrice + priceOffset,
      leftIndexF:      leftIndexF      + candleOffset,
      rightIndexF:     rightIndexF     + candleOffset,
      mode:            mode,
      isLocked:        false,
    );
  }

  @override
  RiskRatioOverlay reverse() {
    final newMode  = mode == RiskRatioMode.buy ? RiskRatioMode.sell : RiskRatioMode.buy;
    final distToSl = entryPrice - stopLossPrice;
    final distToTp = takeProfitPrice - entryPrice;
    return RiskRatioOverlay(
      entryPrice:      entryPrice,
      stopLossPrice:   entryPrice + distToTp,
      takeProfitPrice: entryPrice - distToSl,
      leftIndexF:      leftIndexF,
      rightIndexF:     rightIndexF,
      mode:            newMode,
      isLocked:        isLocked,
    );
  }

  factory RiskRatioOverlay.defaultForViewport(ChartViewport vp, RiskRatioMode mode,
      {double offsetFactor = 0.0}) {
    final mid   = (vp.minPrice + vp.maxPrice) / 2;
    final step  = (vp.maxPrice - vp.minPrice) * 0.10;
    final entry = mid + (vp.maxPrice - vp.minPrice) * offsetFactor * 0.08;
    final sl    = mode == RiskRatioMode.buy ? entry - step : entry + step;
    final tp    = mode == RiskRatioMode.buy ? entry + step : entry - step;

    final totalVisible = vp.lastVisibleIndex - vp.firstVisibleIndex;
    final centerIdx    = (vp.firstVisibleIndex + vp.lastVisibleIndex) / 2.0;
    final halfWidth    = totalVisible * 0.20;
    final hOffset      = totalVisible * offsetFactor * 0.05;

    return RiskRatioOverlay(
      entryPrice:      entry,
      stopLossPrice:   sl,
      takeProfitPrice: tp,
      leftIndexF:      centerIdx - halfWidth + hOffset,
      rightIndexF:     centerIdx + halfWidth + hOffset,
      mode:            mode,
    );
  }
}

// ===========================================================================
// Drag anchor
// ===========================================================================

enum RRDragHandle { none, entry, stopLoss, takeProfit, leftEdge, rightEdge, wholeBox }

class _DragAnchor {
  final double entryPrice;
  final double slPrice;
  final double tpPrice;
  final double leftIndexF;
  final double rightIndexF;
  final double anchorCandleF;
  final double anchorPrice;

  const _DragAnchor({
    required this.entryPrice,
    required this.slPrice,
    required this.tpPrice,
    required this.leftIndexF,
    required this.rightIndexF,
    required this.anchorCandleF,
    required this.anchorPrice,
  });

  factory _DragAnchor.fromOverlay(RiskRatioOverlay ov, Offset screen, ChartViewport vp) {
    return _DragAnchor(
      entryPrice:    ov.entryPrice,
      slPrice:       ov.stopLossPrice,
      tpPrice:       ov.takeProfitPrice,
      leftIndexF:    ov.leftIndexF,
      rightIndexF:   ov.rightIndexF,
      anchorCandleF: vp.xToIndexF(screen.dx),
      anchorPrice:   vp.yToPrice(screen.dy),
    );
  }
}

// ===========================================================================
// Widget utama
// ===========================================================================

class RiskRatioInteractive extends StatefulWidget {
  final ChartViewport viewport;
  final Color accentColor;
  final Color backgroundColor;
  final Color textColor;
  final RiskRatioMode initialMode;

  const RiskRatioInteractive({
    Key? key,
    required this.viewport,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
    this.initialMode = RiskRatioMode.buy,
  }) : super(key: key);

  @override
  State<RiskRatioInteractive> createState() => RiskRatioInteractiveState();
}

class RiskRatioInteractiveState extends State<RiskRatioInteractive>
    with TickerProviderStateMixin {

  final List<RiskRatioOverlay> overlays = [];

  // Action controller untuk Copy/Clone/Reverse/Paste
  final _actionCtrl = OverlayActionController<RiskRatioOverlay>();

  RiskRatioMode currentMode = RiskRatioMode.buy;

  bool    isDrawing          = false;
  Offset? _drawStartScreen;
  Offset? _drawCurrentScreen;

  int          _activeOverlayIndex  = -1;
  RRDragHandle _activeHandle        = RRDragHandle.none;
  RRDragHandle _hoveredHandle       = RRDragHandle.none;
  int          _hoveredOverlayIndex = -1;
  _DragAnchor? _dragAnchor;
  ChartViewport? _dragViewport;

  AnimationController? _pulseCtrl;
  AnimationController? _appearCtrl;
  Animation<double> _pulseAnim  = const AlwaysStoppedAnimation(0.5);
  Animation<double> _appearAnim = const AlwaysStoppedAnimation(1.0);

  static const double _lineHitPx   = 16.0;
  static const double _handleHitPx = 22.0;
  static const double _edgeHitPx   = 18.0;

  @override
  void initState() {
    super.initState();
    currentMode = widget.initialMode;
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _appearCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300),
    );
    _pulseAnim  = CurvedAnimation(parent: _pulseCtrl!,  curve: Curves.easeInOut);
    _appearAnim = CurvedAnimation(parent: _appearCtrl!, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _pulseCtrl?.dispose();
    _appearCtrl?.dispose();
    super.dispose();
  }

  ChartViewport get _vp => widget.viewport;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  void initializeDefault() {
    final offsetFactor = overlays.length.toDouble();
    setState(() => overlays.add(
      RiskRatioOverlay.defaultForViewport(_vp, currentMode, offsetFactor: offsetFactor),
    ));
    _appearCtrl?.forward(from: 0);
  }

  void clearRiskRatio() {
    setState(() {
      overlays.clear();
      isDrawing             = false;
      _drawStartScreen      = null;
      _drawCurrentScreen    = null;
      _activeHandle         = RRDragHandle.none;
      _activeOverlayIndex   = -1;
      _dragAnchor           = null;
      _dragViewport         = null;
      _hoveredHandle        = RRDragHandle.none;
      _hoveredOverlayIndex  = -1;
    });
    _appearCtrl?.reset();
  }

  void removeOverlayAt(int index) {
    if (index < 0 || index >= overlays.length) return;
    setState(() => overlays.removeAt(index));
  }

  void setMode(RiskRatioMode mode) {
    setState(() {
      currentMode = mode;
      for (var i = 0; i < overlays.length; i++) {
        overlays[i] = overlays[i].copyWith(mode: mode);
      }
    });
  }

  void toggleLock() {
    if (_activeOverlayIndex >= 0 && _activeOverlayIndex < overlays.length) {
      final ov = overlays[_activeOverlayIndex];
      setState(() => overlays[_activeOverlayIndex] = ov.copyWith(isLocked: !ov.isLocked));
    } else if (overlays.isNotEmpty) {
      final last = overlays.last;
      setState(() => overlays[overlays.length - 1] = last.copyWith(isLocked: !last.isLocked));
    }
  }

  bool get isLocked {
    if (_activeOverlayIndex >= 0 && _activeOverlayIndex < overlays.length) {
      return overlays[_activeOverlayIndex].isLocked;
    }
    return overlays.isNotEmpty && overlays.last.isLocked;
  }

  RiskRatioOverlay? get overlay => overlays.isNotEmpty ? overlays.last : null;

  // ---------------------------------------------------------------------------
  // handleRightClick — dipanggil dari TradeViewScreen saat kSecondaryMouseButton
  // ---------------------------------------------------------------------------

  void handleRightClick(BuildContext context, Offset localPos) {
    final hit    = _detectHandleAll(localPos);
    final target = hit.index >= 0 ? overlays[hit.index] : null;

    // Konversi local → global supaya menu muncul di posisi cursor yang benar
    final renderBox = this.context.findRenderObject() as RenderBox?;
    final globalPos = renderBox?.localToGlobal(localPos) ?? localPos;

    _actionCtrl.handleRightClick(
      context:        context,
      globalPosition: globalPos,
      hitOverlay:     target,
      isLocked:       target?.isLocked ?? false,
      onClone: (cloned) => setState(() => overlays.add(cloned)),
      onReverse: (reversed) {
        if (hit.index >= 0) setState(() => overlays[hit.index] = reversed);
      },
      onDelete: () {
        if (hit.index >= 0) {
          setState(() {
            overlays.removeAt(hit.index);
            if (_activeOverlayIndex == hit.index) {
              _activeOverlayIndex = -1;
              _activeHandle       = RRDragHandle.none;
            }
          });
        }
      },
      onPaste: () {},   // sudah di-handle internal di OverlayActionController
      onLock:  target != null ? toggleLock : null,
    );
  }

  // ---------------------------------------------------------------------------
  // handleKeyEvent — dipanggil dari KeyboardListener di TradeViewScreen
  // ---------------------------------------------------------------------------

  void handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    // Ctrl+C — Copy overlay aktif
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyC) {
      if (_activeOverlayIndex >= 0 && _activeOverlayIndex < overlays.length) {
        _actionCtrl.copy(overlays[_activeOverlayIndex]);
      }
      return;
    }

    // Ctrl+D — Clone overlay aktif
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyD) {
      if (_activeOverlayIndex >= 0 && _activeOverlayIndex < overlays.length) {
        final cloned = _actionCtrl.clone(overlays[_activeOverlayIndex]);
        if (cloned != null) setState(() => overlays.add(cloned));
      }
      return;
    }

    // Ctrl+V — Paste dari clipboard
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyV) {
      final pasted = _actionCtrl.paste();
      if (pasted != null) {
        setState(() => overlays.add(pasted));
        _appearCtrl?.forward(from: 0);
      }
      return;
    }

    // Ctrl+R — Reverse overlay aktif
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyR) {
      if (_activeOverlayIndex >= 0 && _activeOverlayIndex < overlays.length) {
        final reversed = _actionCtrl.reverse(overlays[_activeOverlayIndex]);
        setState(() => overlays[_activeOverlayIndex] = reversed);
      }
      return;
    }

    // Delete — Hapus overlay aktif
    if (event.logicalKey == LogicalKeyboardKey.delete) {
      if (_activeOverlayIndex >= 0 && _activeOverlayIndex < overlays.length) {
        setState(() {
          overlays.removeAt(_activeOverlayIndex);
          _activeOverlayIndex = -1;
          _activeHandle       = RRDragHandle.none;
        });
      }
      return;
    }
  }

  // ---------------------------------------------------------------------------
  // Hit testing
  // ---------------------------------------------------------------------------

  ({int index, RRDragHandle handle}) _detectHandleAll(Offset screen) {
    for (int i = overlays.length - 1; i >= 0; i--) {
      final handle = _detectHandleForOverlay(screen, overlays[i]);
      if (handle != RRDragHandle.none) return (index: i, handle: handle);
    }
    return (index: -1, handle: RRDragHandle.none);
  }

  RRDragHandle _detectHandleForOverlay(Offset screen, RiskRatioOverlay ov) {
    final lx  = ov.leftX(_vp);
    final rx  = ov.rightX(_vp);
    final eY  = ov.entryY(_vp);
    final sY  = ov.slY(_vp);
    final tY  = ov.tpY(_vp);
    final top = [eY, sY, tY].reduce(math.min);
    final bot = [eY, sY, tY].reduce(math.max);

    final handleX = rx;
    if ((screen - Offset(handleX, sY)).distance < _handleHitPx) return RRDragHandle.stopLoss;
    if ((screen - Offset(handleX, eY)).distance < _handleHitPx) return RRDragHandle.entry;
    if ((screen - Offset(handleX, tY)).distance < _handleHitPx) return RRDragHandle.takeProfit;

    final inY = screen.dy >= top - 20 && screen.dy <= bot + 20;
    if ((screen.dx - lx).abs() < _edgeHitPx && inY) return RRDragHandle.leftEdge;
    if ((screen.dx - rx).abs() < _edgeHitPx && inY) return RRDragHandle.rightEdge;

    final inX = screen.dx >= lx && screen.dx <= rx;
    if (!inX) return RRDragHandle.none;

    if ((screen.dy - sY).abs() < _lineHitPx) return RRDragHandle.stopLoss;
    if ((screen.dy - eY).abs() < _lineHitPx) return RRDragHandle.entry;
    if ((screen.dy - tY).abs() < _lineHitPx) return RRDragHandle.takeProfit;

    if (inX && inY) return RRDragHandle.wholeBox;
    return RRDragHandle.none;
  }

  bool isInsideInteractiveArea(Offset screen) =>
      _detectHandleAll(screen).handle != RRDragHandle.none;

  // ---------------------------------------------------------------------------
  // Pointer events
  // ---------------------------------------------------------------------------

  bool handlePointerDown(Offset screen) {
    final result = _detectHandleAll(screen);
    if (result.handle == RRDragHandle.none) return false;

    final ov = overlays[result.index];
    if (ov.isLocked) return false;

    final currentVp = _vp;
    setState(() {
      _activeOverlayIndex = result.index;
      _activeHandle       = result.handle;
      _dragAnchor         = _DragAnchor.fromOverlay(ov, screen, currentVp);
      _dragViewport       = currentVp;
    });
    return true;
  }

  void handlePointerMove(Offset screen) {
    if (isDrawing) {
      setState(() => _drawCurrentScreen = screen);
      return;
    }
    if (_activeHandle != RRDragHandle.none && _activeOverlayIndex >= 0) {
      _handleDrag(screen);
      return;
    }
    final result = _detectHandleAll(screen);
    if (result.handle != _hoveredHandle || result.index != _hoveredOverlayIndex) {
      setState(() {
        _hoveredHandle       = result.handle;
        _hoveredOverlayIndex = result.index;
      });
    }
  }

  void handlePointerUp(Offset screen) {
    if (isDrawing) {
      _finishDrawing();
    } else {
      setState(() {
        _activeHandle       = RRDragHandle.none;
        _activeOverlayIndex = -1;
        _dragAnchor         = null;
        _dragViewport       = null;
      });
    }
  }

  void handlePointerCancel() {
    if (isDrawing) {
      setState(() {
        isDrawing          = false;
        _drawStartScreen   = null;
        _drawCurrentScreen = null;
      });
    } else {
      setState(() {
        _activeHandle       = RRDragHandle.none;
        _activeOverlayIndex = -1;
        _dragAnchor         = null;
        _dragViewport       = null;
      });
    }
  }

  void startDrawing(Offset screen) {
    setState(() {
      isDrawing          = true;
      _drawStartScreen   = screen;
      _drawCurrentScreen = screen;
    });
  }

  // ---------------------------------------------------------------------------
  // Drag
  // ---------------------------------------------------------------------------

  void _handleDrag(Offset currentScreen) {
    final anchor = _dragAnchor;
    final vp     = _dragViewport;
    if (anchor == null || vp == null) return;
    if (_activeOverlayIndex < 0 || _activeOverlayIndex >= overlays.length) return;

    final ov = overlays[_activeOverlayIndex];

    final currentCandleF = vp.xToIndexF(currentScreen.dx);
    final currentPrice   = vp.yToPrice(currentScreen.dy);
    final dCandleF = currentCandleF - anchor.anchorCandleF;
    final dPrice   = currentPrice   - anchor.anchorPrice;

    final totalC      = vp.totalCandles.toDouble();
    final extraMargin = totalC * 2.0;
    final hardLeft    = -extraMargin;
    final hardRight   = totalC + extraMargin;

    final RiskRatioOverlay updated;

    switch (_activeHandle) {
      case RRDragHandle.entry:
        updated = ov.copyWith(
          entryPrice: (anchor.entryPrice + dPrice).clamp(vp.minPrice, vp.maxPrice),
        );
      case RRDragHandle.stopLoss:
        updated = ov.copyWith(
          stopLossPrice: (anchor.slPrice + dPrice).clamp(vp.minPrice, vp.maxPrice),
        );
      case RRDragHandle.takeProfit:
        updated = ov.copyWith(
          takeProfitPrice: (anchor.tpPrice + dPrice).clamp(vp.minPrice, vp.maxPrice),
        );
      case RRDragHandle.leftEdge:
        final newLeft = (anchor.leftIndexF + dCandleF)
            .clamp(hardLeft, anchor.rightIndexF - 5.0);
        updated = ov.copyWith(leftIndexF: newLeft);
      case RRDragHandle.rightEdge:
        final newRight = (anchor.rightIndexF + dCandleF)
            .clamp(anchor.leftIndexF + 5.0, hardRight);
        updated = ov.copyWith(rightIndexF: newRight);
      case RRDragHandle.wholeBox:
        final newLeft  = anchor.leftIndexF  + dCandleF;
        final newRight = anchor.rightIndexF + dCandleF;
        updated = ov.copyWith(
          leftIndexF:      newLeft.clamp(hardLeft,  anchor.rightIndexF  + extraMargin),
          rightIndexF:     newRight.clamp(anchor.leftIndexF - extraMargin, hardRight),
          entryPrice:      (anchor.entryPrice + dPrice).clamp(vp.minPrice, vp.maxPrice),
          stopLossPrice:   (anchor.slPrice    + dPrice).clamp(vp.minPrice, vp.maxPrice),
          takeProfitPrice: (anchor.tpPrice    + dPrice).clamp(vp.minPrice, vp.maxPrice),
        );
      default:
        return;
    }

    setState(() => overlays[_activeOverlayIndex] = updated);
  }

  void _finishDrawing() {
    final startScreen   = _drawStartScreen;
    final currentScreen = _drawCurrentScreen;
    if (startScreen == null || currentScreen == null) return;

    final startPoint   = DataSpacePoint.fromScreen(startScreen,   _vp);
    final currentPoint = DataSpacePoint.fromScreen(currentScreen, _vp);

    final lx = math.min(startPoint.candleIndexF, currentPoint.candleIndexF);
    final rx = math.max(startPoint.candleIndexF, currentPoint.candleIndexF);

    if (rx - lx < 5) {
      setState(() {
        isDrawing          = false;
        _drawStartScreen   = null;
        _drawCurrentScreen = null;
        _dragAnchor        = null;
        _dragViewport      = null;
      });
      return;
    }

    final entryPrice  = startPoint.price;
    final targetPrice = currentPoint.price;
    final diff        = (targetPrice - entryPrice).abs();

    double sl, tp;
    if (currentMode == RiskRatioMode.buy) {
      if (targetPrice > entryPrice) { tp = targetPrice; sl = entryPrice - diff; }
      else                          { sl = targetPrice; tp = entryPrice + diff; }
    } else {
      if (targetPrice < entryPrice) { tp = targetPrice; sl = entryPrice + diff; }
      else                          { sl = targetPrice; tp = entryPrice - diff; }
    }

    setState(() {
      overlays.add(RiskRatioOverlay(
        entryPrice:      entryPrice,
        stopLossPrice:   sl,
        takeProfitPrice: tp,
        leftIndexF:      lx,
        rightIndexF:     rx,
        mode:            currentMode,
      ));
      isDrawing          = false;
      _drawStartScreen   = null;
      _drawCurrentScreen = null;
      _dragAnchor        = null;
      _dragViewport      = null;
    });
    _appearCtrl?.forward(from: 0);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _appearAnim]),
      builder: (_, __) {
        return CustomPaint(
          painter: _RiskRatioPainter(
            overlays:            overlays,
            activeOverlayIndex:  _activeOverlayIndex,
            hoveredOverlayIndex: _hoveredOverlayIndex,
            viewport:            _vp,
            isDrawing:           isDrawing,
            drawStart:           _drawStartScreen,
            drawCurrent:         _drawCurrentScreen,
            accentColor:         widget.accentColor,
            bgColor:             widget.backgroundColor,
            textColor:           widget.textColor,
            activeHandle:        _activeHandle,
            hoveredHandle:       _hoveredHandle,
            pulseValue:          _pulseAnim.value,
            appearValue:         _appearAnim.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

// ===========================================================================
// Painter
// ===========================================================================

class _RiskRatioPainter extends CustomPainter {
  final List<RiskRatioOverlay> overlays;
  final int                    activeOverlayIndex;
  final int                    hoveredOverlayIndex;
  final ChartViewport          viewport;
  final bool                   isDrawing;
  final Offset?                drawStart;
  final Offset?                drawCurrent;
  final Color                  accentColor;
  final Color                  bgColor;
  final Color                  textColor;
  final RRDragHandle           activeHandle;
  final RRDragHandle           hoveredHandle;
  final double                 pulseValue;
  final double                 appearValue;

  static const _slColor     = Color(0xFFFF4D6D);
  static const _tpColor     = Color(0xFF00D09C);
  static const _entryBuy    = Color(0xFF00D09C);
  static const _entrySell   = Color(0xFFFF4D6D);
  static const _bgDark      = Color(0xFF0B0E17);
  static const _minLabelGap = 18.0;

  _RiskRatioPainter({
    required this.overlays,
    required this.activeOverlayIndex,
    required this.hoveredOverlayIndex,
    required this.viewport,
    required this.isDrawing,
    required this.drawStart,
    required this.drawCurrent,
    required this.accentColor,
    required this.bgColor,
    required this.textColor,
    required this.activeHandle,
    required this.hoveredHandle,
    required this.pulseValue,
    required this.appearValue,
  });

  Color _entryColor(RiskRatioOverlay ov) =>
      ov.mode == RiskRatioMode.buy ? _entryBuy : _entrySell;

  @override
  void paint(Canvas canvas, Size size) {
    if (isDrawing && drawStart != null && drawCurrent != null) {
      _paintPreview(canvas, size);
    }
    for (int i = 0; i < overlays.length; i++) {
      _paintOverlay(canvas, size, overlays[i],
          i == activeOverlayIndex, i == hoveredOverlayIndex, i);
    }
  }

  void _paintPreview(Canvas canvas, Size size) {
    final s = drawStart!;
    final c = drawCurrent!;
    _drawDashedH(canvas, s.dy, size, Paint()
      ..color = accentColor.withOpacity(0.55)
      ..strokeWidth = 1.2);
    _drawDashedH(canvas, c.dy, size, Paint()
      ..color = accentColor.withOpacity(0.28)
      ..strokeWidth = 1.0);
    canvas.drawRect(
      Rect.fromLTRB(0, math.min(s.dy, c.dy), size.width, math.max(s.dy, c.dy)),
      Paint()..color = accentColor.withOpacity(0.05),
    );
  }

  void _paintOverlay(Canvas canvas, Size size, RiskRatioOverlay ov,
      bool isActive, bool isHovered, int overlayIndex) {
    final lx  = ov.leftX(viewport);
    final rx  = ov.rightX(viewport);
    final eY  = ov.entryY(viewport);
    final sY  = ov.slY(viewport);
    final tY  = ov.tpY(viewport);
    final top = [eY, sY, tY].reduce(math.min);
    final bot = [eY, sY, tY].reduce(math.max);

    final doAnimate = appearValue < 1.0 && overlayIndex == overlays.length - 1;
    if (doAnimate) {
      canvas.save();
      final sc     = 0.93 + 0.07 * appearValue;
      final pivotY = (top + bot) / 2;
      canvas.translate(0, pivotY);
      canvas.scale(1.0, sc);
      canvas.translate(0, -pivotY);
    }

    canvas.drawRect(
      Rect.fromLTRB(lx, math.min(eY, sY), rx, math.max(eY, sY)),
      Paint()..color = _slColor.withOpacity(0.09),
    );
    canvas.drawRect(
      Rect.fromLTRB(lx, math.min(eY, tY), rx, math.max(eY, tY)),
      Paint()..color = _tpColor.withOpacity(0.08),
    );

    final leftActive = isActive && activeHandle == RRDragHandle.leftEdge;
    canvas.drawLine(
      Offset(lx, top - 2), Offset(lx, bot + 2),
      Paint()
        ..color       = accentColor.withOpacity(leftActive ? 1.0 : 0.40)
        ..strokeWidth = leftActive ? 1.8 : 1.0,
    );
    for (final dy in [top - 2.0, bot + 2.0]) {
      canvas.drawCircle(
        Offset(lx, dy),
        leftActive ? 3.5 : 2.5,
        Paint()..color = accentColor.withOpacity(leftActive ? 1.0 : 0.45),
      );
    }

    _paintLine(canvas, size, sY,  _slColor,         RRDragHandle.stopLoss,   isActive);
    _paintLine(canvas, size, eY,  _entryColor(ov),  RRDragHandle.entry,      isActive);
    _paintLine(canvas, size, tY,  _tpColor,         RRDragHandle.takeProfit, isActive);

    _paintLabelsLeft(canvas, ov, eY, sY, tY, isActive);

    _paintHandle(canvas, Offset(rx, sY), _slColor,         RRDragHandle.stopLoss,   isActive);
    _paintHandle(canvas, Offset(rx, eY), _entryColor(ov),  RRDragHandle.entry,      isActive);
    _paintHandle(canvas, Offset(rx, tY), _tpColor,         RRDragHandle.takeProfit, isActive);

    _paintBadgeInside(canvas, lx, rx, eY, tY, ov);
    _paintDotGrid(canvas, (lx + rx) / 2, (top + bot) / 2,
        isActive && activeHandle == RRDragHandle.wholeBox);

    if (ov.isLocked) _paintLockIcon(canvas, (lx + rx) / 2, top - 22);
    if (doAnimate) canvas.restore();
  }

  void _paintLine(Canvas canvas, Size size, double y, Color color,
      RRDragHandle handle, bool overlayActive) {
    final isActive  = overlayActive && activeHandle  == handle;
    final isHovered = hoveredHandle == handle;
    canvas.drawLine(
      Offset(0, y), Offset(size.width, y),
      Paint()
        ..color       = color.withOpacity(isActive ? 1.0 : isHovered ? 0.85 : 0.65)
        ..strokeWidth = isActive ? 1.6 : 1.0,
    );
  }

  void _paintLabelsLeft(Canvas canvas, RiskRatioOverlay ov,
      double eY, double sY, double tY, bool overlayActive) {
    final items = [
      _LabelItem(y: tY, label: 'TP',    price: ov.takeProfitPrice, color: _tpColor,         handle: RRDragHandle.takeProfit),
      _LabelItem(y: eY, label: 'ENTRY', price: ov.entryPrice,      color: _entryColor(ov),  handle: RRDragHandle.entry),
      _LabelItem(y: sY, label: 'SL',    price: ov.stopLossPrice,   color: _slColor,         handle: RRDragHandle.stopLoss),
    ]..sort((a, b) => a.y.compareTo(b.y));

    for (var i = 1; i < items.length; i++) {
      if (items[i].y - items[i - 1].y < _minLabelGap) {
        items[i] = items[i].copyWithY(items[i - 1].y + _minLabelGap);
      }
    }
    for (final item in items) _paintOneLabel(canvas, item, overlayActive);
  }

  void _paintOneLabel(Canvas canvas, _LabelItem item, bool overlayActive) {
    final isActive = overlayActive && activeHandle == item.handle;
    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(
          text: item.label,
          style: TextStyle(
            color: item.color, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6,
          ),
        ),
        TextSpan(
          text: '  ${_formatPrice(item.price)}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.82), fontSize: 9.5, fontWeight: FontWeight.w500,
          ),
        ),
      ]),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    const xPad = 5.0;
    final bw   = tp.width + 14.0;
    const bh   = 18.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(xPad, item.y - bh / 2, bw, bh), const Radius.circular(3),
    );
    canvas.drawRRect(rect, Paint()..color = _bgDark.withOpacity(0.92));
    canvas.drawRRect(rect, Paint()
      ..color       = item.color.withOpacity(isActive ? 0.80 : 0.35)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 0.8);
    tp.paint(canvas, Offset(xPad + 7, item.y - tp.height / 2));
  }

  void _paintHandle(Canvas canvas, Offset center, Color color,
      RRDragHandle handle, bool overlayActive) {
    final isActive  = overlayActive && activeHandle  == handle;
    final isHovered = hoveredHandle == handle;
    final r = _handleR(handle);

    if (isActive) {
      canvas.drawCircle(center, r + 7 + pulseValue * 4,
        Paint()
          ..color       = color.withOpacity(0.10 * (1 - pulseValue))
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    }
    if (isActive || isHovered) {
      canvas.drawCircle(center, r + 4,
        Paint()
          ..color      = color.withOpacity(isActive ? 0.20 : 0.08)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, isActive ? 5 : 3));
    }
    canvas.drawCircle(center, r + 1.5, Paint()..color = _bgDark);
    canvas.drawCircle(center, r,       Paint()..color = color);

    final letter = _handleLetter(color);
    if (letter != null) {
      final lp = TextPainter(
        text: TextSpan(text: letter,
          style: TextStyle(color: _bgDark, fontSize: r * 0.85, fontWeight: FontWeight.w900)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      lp.paint(canvas, Offset(center.dx - lp.width / 2, center.dy - lp.height / 2));
    }
  }

  double _handleR(RRDragHandle h) {
    if (activeHandle  == h) return 11.0;
    if (hoveredHandle == h) return 9.0;
    return 7.0;
  }

  String? _handleLetter(Color color) {
    if (color == _slColor)                         return 'S';
    if (color == _tpColor)                         return 'T';
    if (color == _entryBuy || color == _entrySell) return 'E';
    return null;
  }

  void _paintBadgeInside(Canvas canvas, double lx, double rx,
      double eY, double tY, RiskRatioOverlay ov) {
    final isBuy     = ov.mode == RiskRatioMode.buy;
    final modeColor = isBuy ? _tpColor : _slColor;
    final modeStr   = isBuy ? '▲  LONG' : '▼  SHORT';
    final rrColor   = ov.isProfitable ? _tpColor : const Color(0xFFFFB347);
    final rrStr     = 'R:R  ${ov.rrText}';

    final modeTp = _makeTp(modeStr, modeColor, 10.5, FontWeight.w800);
    final rrTp   = _makeTp(rrStr,   rrColor,   11.5, FontWeight.w700);
    modeTp.layout(); rrTp.layout();

    final bw   = math.max(modeTp.width, rrTp.width) + 28.0;
    const bh   = 46.0;
    final boxW = rx - lx;
    if (boxW < bw + 10) return;

    final badgeCx = lx + boxW * 0.67;
    final badgeCy = (math.min(eY, tY) + math.max(eY, tY)) / 2;
    final left    = (badgeCx - bw / 2).clamp(lx + 4, rx - bw - 4);
    final top     = badgeCy - bh / 2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, bw, bh), const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = _bgDark.withOpacity(0.88));
    canvas.drawRRect(rect, Paint()
      ..color       = modeColor.withOpacity(0.40)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, top, bw, 2.0), const Radius.circular(6)),
      Paint()..color = modeColor.withOpacity(0.70),
    );
    modeTp.paint(canvas, Offset(left + (bw - modeTp.width) / 2, top + 8));
    rrTp.paint(  canvas, Offset(left + (bw - rrTp.width)   / 2, top + 8 + modeTp.height + 5));
  }

  TextPainter _makeTp(String text, Color color, double fontSize, FontWeight weight) =>
      TextPainter(
        text: TextSpan(text: text,
          style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight)),
        textDirection: ui.TextDirection.ltr,
      );

  void _paintDotGrid(Canvas canvas, double cx, double cy, bool isActive) {
    final color = (isActive ? accentColor : Colors.white)
        .withOpacity(isActive ? 0.80 : 0.28);
    for (final col in [-4.5, 0.0, 4.5]) {
      for (final row in [-4.5, 0.0, 4.5]) {
        canvas.drawCircle(Offset(cx + col, cy + row),
            isActive ? 2.2 : 1.5, Paint()..color = color);
      }
    }
  }

  void _paintLockIcon(Canvas canvas, double cx, double y) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.lock_rounded.codePoint),
        style: TextStyle(fontSize: 15, fontFamily: Icons.lock_rounded.fontFamily,
            color: Colors.amber.withOpacity(0.9)),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, y - tp.height / 2));
  }

  void _drawDashedH(Canvas canvas, double y, Size size, Paint paint) {
    const dash = 5.0, gap = 3.5;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y),
          Offset(math.min(x + dash, size.width), y), paint);
      x += dash + gap;
    }
  }

  String _formatPrice(double p) {
    if (p >= 10000) return p.toStringAsFixed(1);
    if (p >= 1000)  return p.toStringAsFixed(2);
    if (p >= 1)     return p.toStringAsFixed(3);
    return p.toStringAsFixed(5);
  }

  @override
  bool shouldRepaint(_RiskRatioPainter old) =>
      old.overlays            != overlays            ||
      old.activeOverlayIndex  != activeOverlayIndex  ||
      old.hoveredOverlayIndex != hoveredOverlayIndex ||
      old.viewport            != viewport            ||
      old.isDrawing           != isDrawing           ||
      old.drawStart           != drawStart           ||
      old.drawCurrent         != drawCurrent         ||
      old.activeHandle        != activeHandle        ||
      old.hoveredHandle       != hoveredHandle       ||
      old.pulseValue          != pulseValue          ||
      old.appearValue         != appearValue;
}

// ===========================================================================
// Helper
// ===========================================================================

class _LabelItem {
  final double       y;
  final String       label;
  final double       price;
  final Color        color;
  final RRDragHandle handle;

  const _LabelItem({
    required this.y, required this.label,
    required this.price, required this.color, required this.handle,
  });

  _LabelItem copyWithY(double newY) =>
      _LabelItem(y: newY, label: label, price: price, color: color, handle: handle);
}