import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';

import '../chart/candle_info_panel.dart';
import '../chart/price_header.dart';
import '../chart/volume_section.dart';

import '../controller/chart_controller_2.dart';
import '../controller/chart_controls.dart';
import '../controller/interval_selector.dart';
import '../controller/risk_ratio_button.dart';
import '../controller/ticker_selector.dart';
import '../controller/chart_viewport.dart';
import '../controller/fibonacci_button.dart';

import '../dialogs/style_settings.dart';
import '../dialogs/chart_style.dart';

import '../interactive/interactive_candlestick_chart.dart';
import '../interactive/risk_ratio_interactive_2.dart';
import '../interactive/volume_interactive.dart';
import '../interactive/cross_interactive.dart';
import '../interactive/grid_interactive.dart';
import '../interactive/fibonacci_interactive.dart';

import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/role_guard.dart';

import '../candle/candle_normal.dart';

import '../pages/tradingview_pages.dart';
import '../style/apps_colors_tradingview.dart';
import 'tradingviewcodeeditor_screen.dart';
import 'tradingview/resizable_divider.dart';
import '../models/script_file.dart';
import '../models/script_folder.dart';

class TradeViewScreen extends StatefulWidget {
  final String token;
  const TradeViewScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<TradeViewScreen> createState() => _TradeViewScreenState();
}

class _TradeViewScreenState extends State<TradeViewScreen> {
  late ChartController _controller;
  late final IsolatedTradingViewHook _editorHook;

  final GlobalKey<RiskRatioInteractiveState> _riskRatioKey = GlobalKey();
  final GlobalKey<FibonacciInteractiveState> _fibonacciKey = GlobalKey();

  final ValueNotifier<Offset?> _crosshairNotifier = ValueNotifier(null);

  final Map<int, bool>   _pointerOwnership = {};
  final Map<int, Offset> _pendingDraw      = {};
  static const double    _drawThreshold    = 8.0;

  final Set<int>  _activePointers = {};
  final FocusNode _chartFocus     = FocusNode();

  bool _isFibonacciMode = false;

  ChartStyleState _chartStyle = const ChartStyleState();

  Size           _lastChartSize = Size.zero;
  ChartViewport? _lastViewport;

  double _scaleBase  = 1.0;
  Offset _scaleFocal = Offset.zero;

  int    _lastCandleCount = 0;
  String _lastTicker      = '';
  String _lastInterval    = '';
  double _lastScale       = 1.0;
  double _lastOffsetX     = 0.0;
  double _lastOffsetY     = 0.0;

  // ── Panel layout state ────────────────────────────────────────────────────
  // _bottomHeight  : tinggi aktual panel editor saat ini
  // _bottomExpanded: toggle collapse/expand (cukup hide panel, divider tetap ada)
  // _minBottom     : tinggi minimum — cukup untuk toolbar editor keliatan
  // maxBottom & halfBottom dihitung dinamis dari screen height di _buildChartArea

  double _bottomHeight   = 220.0;
  bool   _bottomExpanded = true;

  static const double _minBottom = 48.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _controller = ChartController(
      availableTickers:   CryptoPairs.major,
      availableIntervals: TimeframeConstants.common,
    );
    _controller.addListener(_onControllerUpdate);

    _editorHook = IsolatedTradingViewHook(
      permission: EditorPermission(
        userId: widget.token,
        role:   UserRole.exclusive,
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _crosshairNotifier.dispose();
    _chartFocus.dispose();
    _editorHook.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    final state = _controller.state;

    final candleCountChanged = state.candles.length != _lastCandleCount;
    final tickerChanged      = state.selectedTicker  != _lastTicker;
    final intervalChanged    = state.selectedInterval != _lastInterval;
    final scaleChanged       = (state.scale   - _lastScale).abs()   > 0.001;
    final offsetChanged      = (state.offsetX - _lastOffsetX).abs() > 0.5 ||
                               (state.offsetY - _lastOffsetY).abs() > 0.5;

    if (tickerChanged || intervalChanged || state.isLoading) {
      _lastTicker   = state.selectedTicker;
      _lastInterval = state.selectedInterval;
      setState(() {});
      return;
    }

    if (candleCountChanged || scaleChanged) {
      _lastCandleCount = state.candles.length;
      _lastScale       = state.scale;
      setState(() {});
      return;
    }

    if (offsetChanged) {
      _lastOffsetX = state.offsetX;
      _lastOffsetY = state.offsetY;
      setState(() {});
      return;
    }

    if (state.selectedCandle != null) setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Risk Ratio helpers
  // ═══════════════════════════════════════════════════════════════════════════

  RiskRatioInteractiveState? get _rrState => _riskRatioKey.currentState;

  bool get _rrVisible {
    if (_controller.state.isRiskRatioMode) return true;
    final rr = _rrState;
    return rr != null && rr.overlays.isNotEmpty;
  }

  bool _rrOwnsImmediately(Offset pos) {
    final rr = _rrState;
    if (rr == null || rr.overlays.isEmpty) return false;
    return rr.isInsideInteractiveArea(pos);
  }

  void _toggleRiskRatioMode() {
    if (!_controller.state.isRiskRatioMode && _isFibonacciMode) {
      _toggleFibonacciMode();
    }
    final wasActive = _controller.state.isRiskRatioMode;
    _controller.toggleRiskRatioMode();
    if (!wasActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_lastChartSize != Size.zero) {
          _riskRatioKey.currentState?.initializeDefault();
        }
      });
    }
  }

  void _onRiskRatioModeChanged(RiskRatioMode newMode) {
    if (_controller.state.riskRatioMode != newMode) {
      _controller.switchRiskRatioMode();
    }
    if (!_controller.state.isRiskRatioMode) {
      _toggleRiskRatioMode();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _riskRatioKey.currentState?.setMode(newMode);
      });
      setState(() {});
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Fibonacci helpers
  // ═══════════════════════════════════════════════════════════════════════════

  FibonacciInteractiveState? get _fibState => _fibonacciKey.currentState;

  bool get _fibVisible {
    if (_isFibonacciMode) return true;
    final fib = _fibState;
    return fib != null && fib.overlays.isNotEmpty;
  }

  bool _fibOwnsImmediately(Offset pos) {
    final fib = _fibState;
    if (fib == null || fib.overlays.isEmpty) return false;
    return fib.isInsideInteractiveArea(pos);
  }

  void _toggleFibonacciMode() {
    if (!_isFibonacciMode && _controller.state.isRiskRatioMode) {
      _controller.toggleRiskRatioMode();
    }
    setState(() => _isFibonacciMode = !_isFibonacciMode);
    if (_isFibonacciMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_lastChartSize != Size.zero) {
          _fibonacciKey.currentState?.initializeDefault();
        }
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Style settings
  // ═══════════════════════════════════════════════════════════════════════════

  void _showStyleSettings() {
    StyleSettingsPanel.show(
      context,
      currentStyle: _chartStyle,
      onChanged:    (next) => setState(() => _chartStyle = next),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Back navigation
  // ═══════════════════════════════════════════════════════════════════════════

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home', arguments: widget.token);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Pointer handling
  // ═══════════════════════════════════════════════════════════════════════════

  void _onPointerDown(PointerDownEvent e) {
    if (e.buttons == kSecondaryMouseButton) {
      if (_rrVisible)  _rrState?.handleRightClick(context, e.localPosition);
      if (_fibVisible) _fibState?.handleRightClick(context, e.localPosition);
      return;
    }

    _activePointers.add(e.pointer);
    final pos   = e.localPosition;
    final state = _controller.state;

    if (_fibVisible && _fibOwnsImmediately(pos)) {
      final claimed = _fibState?.handlePointerDown(pos) ?? false;
      _pointerOwnership[e.pointer] = claimed;
      return;
    }

    if (_fibVisible && _isFibonacciMode && _fibState != null && !(_fibState!.isDrawing)) {
      _pendingDraw[e.pointer]      = pos;
      _pointerOwnership[e.pointer] = false;
      return;
    }

    if (_rrVisible && _rrOwnsImmediately(pos)) {
      final claimed = _rrState?.handlePointerDown(pos) ?? false;
      _pointerOwnership[e.pointer] = claimed;
      return;
    }

    if (_rrVisible && state.isRiskRatioMode && _rrState != null && !(_rrState!.isDrawing)) {
      _pendingDraw[e.pointer]      = pos;
      _pointerOwnership[e.pointer] = false;
      return;
    }

    _pointerOwnership[e.pointer] = false;
  }

  void _onPointerMove(PointerMoveEvent e) {
    final pos   = e.localPosition;
    final owned = _pointerOwnership[e.pointer];

    if (owned == true) {
      if (_fibState?.isDrawing == true || _fibOwnsImmediately(pos)) {
        _fibState?.handlePointerMove(pos);
      } else {
        _rrState?.handlePointerMove(pos);
      }
      return;
    }

    final drawStart = _pendingDraw[e.pointer];
    if (drawStart != null) {
      if ((pos - drawStart).distance >= _drawThreshold) {
        _pendingDraw.remove(e.pointer);
        _pointerOwnership[e.pointer] = true;
        if (_isFibonacciMode) {
          _fibState?.startDrawing(drawStart);
          _fibState?.handlePointerMove(pos);
        } else {
          _rrState?.startDrawing(drawStart);
          _rrState?.handlePointerMove(pos);
        }
      }
      return;
    }

    final state = _controller.state;
    if (!state.isRiskRatioMode && !_isFibonacciMode && _activePointers.length == 1) {
      _controller.applyPanDelta(e.delta.dx, 0);
    }

    if ((state.isRiskRatioMode || _isFibonacciMode) && _activePointers.length == 1) {
      final rrHit  = _rrVisible  && _rrOwnsImmediately(pos);
      final fibHit = _fibVisible && _fibOwnsImmediately(pos);
      if (!rrHit && !fibHit) _controller.applyPanDelta(e.delta.dx, 0);
    }

    if (state.showCrosshair && !state.isRiskRatioMode && !_isFibonacciMode) {
      _crosshairNotifier.value = pos;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _activePointers.remove(e.pointer);
    _pendingDraw.remove(e.pointer);

    final owned = _pointerOwnership.remove(e.pointer);
    if (owned == true) {
      if (_fibState?.isDrawing == true) {
        _fibState?.handlePointerUp(e.localPosition);
      } else {
        _rrState?.handlePointerUp(e.localPosition);
        _fibState?.handlePointerUp(e.localPosition);
      }
    } else {
      _crosshairNotifier.value = null;
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _activePointers.remove(e.pointer);
    _pendingDraw.remove(e.pointer);

    final owned = _pointerOwnership.remove(e.pointer);
    if (owned == true) {
      _rrState?.handlePointerCancel();
      _fibState?.handlePointerCancel();
    } else {
      _crosshairNotifier.value = null;
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    if (d.pointerCount >= 2) {
      _scaleBase  = _controller.state.scale;
      _scaleFocal = d.localFocalPoint;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      _controller.updateScale(
        _scaleBase * d.scale,
        focalPoint: _scaleFocal,
        chartSize:  _lastChartSize,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Style helpers
  // ═══════════════════════════════════════════════════════════════════════════

  CandlestickStyle _toCandlestickStyle(ChartStyleState s) {
    return CandlestickStyle(
      bullishColor:    s.bullishColor,
      bearishColor:    s.bearishColor,
      backgroundColor: s.backgroundColor,
      gridColor:       s.gridColor.withOpacity(s.gridOpacity),
      textColor:       s.textColor,
      crosshairColor:  s.crosshairColor,
      bullishStyle:    s.bodyStyle,
      bearishStyle:    s.bodyStyle,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final style = _toCandlestickStyle(_chartStyle);

    return Scaffold(
      backgroundColor: _chartStyle.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            RepaintBoundary(child: _buildTopControls(style)),

            if (DataValidator.isCandlesValid(state.candles))
              RepaintBoundary(
                child: PriceHeader(
                  candles:          state.candles,
                  selectedTicker:   state.selectedTicker,
                  selectedInterval: state.selectedInterval,
                  chartStyle:       style,
                ),
              ),

            // Expanded wraps _buildChartArea sehingga CandleInfoPanel
            // dan ChartControls tidak pernah overflow ke bawah
            Expanded(child: _buildChartArea(style)),

            if (state.selectedCandle != null)
              CandleInfoPanel(
                selectedCandle: state.selectedCandle!,
                chartStyle:     style,
              ),

            RepaintBoundary(child: _buildBottomControls(style)),
          ],
        ),
      ),
    );
  }

  // ─── Top Controls ──────────────────────────────────────────────────────────

  Widget _buildTopControls(CandlestickStyle style) {
    final state = _controller.state;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingLarge,
        vertical:   AppSizes.paddingLarge,
      ),
      decoration: BoxDecoration(
        color:  style.backgroundColor,
        border: Border(bottom: BorderSide(color: style.gridColor)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _handleBack,
            child: Container(
              width:  36,
              height: 36,
              decoration: BoxDecoration(
                color:        style.gridColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border:       Border.all(color: style.gridColor),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: style.textColor,
                size:  16,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.paddingLarge),

          TickerSelector(
            selectedTicker:   state.selectedTicker,
            availableTickers: _controller.availableTickers,
            style:            style,
            onTickerChanged:  _controller.changeTicker,
          ),
          const SizedBox(width: AppSizes.paddingLarge),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntervalSelector(
                selectedInterval:   state.selectedInterval,
                availableIntervals: TimeframeConstants.common,
                onChanged:          _controller.changeInterval,
                backgroundColor:    style.backgroundColor,
                selectedColor:      style.bullishColor,
                unselectedColor:    style.textColor.withOpacity(0.5),
                borderColor:        style.gridColor,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.paddingLarge),

          FibonacciButton(
            isActive: _isFibonacciMode,
            style:    style,
            onTap:    _toggleFibonacciMode,
          ),
          const SizedBox(width: AppSizes.paddingLarge),

          RiskRatioButton(
            isActive:      state.isRiskRatioMode,
            mode:          state.riskRatioMode,
            style:         style,
            onTap:         _toggleRiskRatioMode,
            onModeChanged: _onRiskRatioModeChanged,
          ),
        ],
      ),
    );
  }

  // ─── Chart Area ────────────────────────────────────────────────────────────
  //
  // FIX UTAMA ADA DI SINI:
  //   1. LayoutBuilder di level paling luar → dapat totalH yang akurat
  //   2. maxBottom  = 80% totalH  (bisa full-screen editor)
  //   3. halfBottom = 40% totalH  (snap point tengah)
  //   4. Double-tap divider → cycling snap: half ↔ full, atau collapsed → half
  //   5. AnimatedContainer di bottom panel → transisi smooth
  //   6. Clamp guard pakai addPostFrameCallback agar tidak rebuild mid-frame

  Widget _buildChartArea(CandlestickStyle style) {
    final state = _controller.state;

    if (state.isLoading) {
      return LoadingStateHelper.createLoadingWidget(
        color:     style.bullishColor,
        message:   '${ErrorMessages.loadingPrefix} ${state.selectedTicker} ${state.selectedInterval}...',
        textColor: style.textColor,
      );
    }

    if (!DataValidator.isCandlesValid(state.candles)) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(
            color:    style.textColor.withOpacity(0.5),
            fontSize: AppSizes.fontRegular,
          ),
        ),
      );
    }

    // ── Snap + clamp logic (semua dihitung dari tinggi aktual layar) ─────────
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final totalH     = outerConstraints.maxHeight;
        final maxBottom  = totalH * 0.80;   // 80% → editor hampir full screen
        final halfBottom = totalH * 0.40;   // 40% → half split

        // Clamp guard: kalau state masih nyimpen nilai lama yang melebihi batas
        // baru (mis. setelah rotate), koreksi di frame berikutnya
        if (_bottomHeight > maxBottom) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _bottomHeight = maxBottom);
          });
        }

        return Column(
          children: [

            // ── Chart canvas (Expanded → otomatis menyusut saat editor diperbesar)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final newSize = Size(constraints.maxWidth, constraints.maxHeight);
                  if (newSize != _lastChartSize) _lastChartSize = newSize;

                  final vp             = _controller.buildViewport(_lastChartSize);
                  _lastViewport        = vp;
                  final offsetAsOffset = Offset(state.offsetX, state.offsetY);

                  return KeyboardListener(
                    focusNode: _chartFocus,
                    autofocus: true,
                    onKeyEvent: (event) {
                      _rrState?.handleKeyEvent(event);
                      _fibState?.handleKeyEvent(event);
                    },
                    child: Listener(
                      behavior:        HitTestBehavior.translucent,
                      onPointerDown:   _onPointerDown,
                      onPointerMove:   _onPointerMove,
                      onPointerUp:     _onPointerUp,
                      onPointerCancel: _onPointerCancel,
                      child: GestureDetector(
                        onScaleStart:  _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        child: Stack(
                          children: [

                            RepaintBoundary(
                              child: Column(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Stack(
                                      children: [
                                        if (state.showGrid)
                                          Positioned.fill(
                                            child: CustomPaint(
                                              painter: GridInteractive(
                                                candles:          state.candles,
                                                style:            style,
                                                scale:            state.scale,
                                                offsetY:          state.offsetY,
                                                offset:           offsetAsOffset,
                                                showVolume:       state.showVolume,
                                                selectedInterval: state.selectedInterval,
                                              ),
                                            ),
                                          ),
                                        InteractiveCandlestickChart(
                                          candles:          state.candles,
                                          style:            style,
                                          showVolume:       state.showVolume,
                                          scale:            state.scale,
                                          offset:           offsetAsOffset,
                                          onScaleUpdate:    null,
                                          onOffsetUpdate:   null,
                                          onCandleSelected: _controller.selectCandle,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (state.showVolume)
                                    FuturisticVolumeBar(
                                      candles:         state.candles,
                                      bullishColor:    style.bullishColor,
                                      bearishColor:    style.bearishColor,
                                      backgroundColor: style.backgroundColor,
                                      scale:           state.scale,
                                      offset:          offsetAsOffset,
                                      selectedIndex:   state.candles.indexOf(
                                        state.selectedCandle ?? state.candles.last,
                                      ),
                                      height: AppSizes.volumeBarHeight,
                                    ),
                                ],
                              ),
                            ),

                            if (state.showCrosshair && !state.isRiskRatioMode && !_isFibonacciMode)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: ValueListenableBuilder<Offset?>(
                                    valueListenable: _crosshairNotifier,
                                    builder: (_, pos, __) {
                                      if (pos == null) return const SizedBox.shrink();
                                      final currentVp = _lastViewport;
                                      if (currentVp == null) return const SizedBox.shrink();
                                      return CustomPaint(
                                        painter: CrosshairPainter(
                                          position:             pos,
                                          color:                style.bullishColor,
                                          strokeWidth:          1.0,
                                          showLabels:           true,
                                          priceLabel:           currentVp.yToPrice(pos.dy).toStringAsFixed(2),
                                          timeLabel:            _timeLabel(pos.dx, state.candles, currentVp),
                                          labelBackgroundColor: style.backgroundColor,
                                          labelTextColor:       style.textColor,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                            if (_fibVisible)
                              Positioned.fill(
                                child: FibonacciInteractive(
                                  key:             _fibonacciKey,
                                  viewport:        vp,
                                  accentColor:     FibonacciButton.fibColor,
                                  backgroundColor: style.backgroundColor,
                                  textColor:       style.textColor,
                                  chartStyle:      _chartStyle,
                                ),
                              ),

                            if (_rrVisible)
                              Positioned.fill(
                                child: RiskRatioInteractive(
                                  key:             _riskRatioKey,
                                  viewport:        vp,
                                  accentColor:     state.riskRatioMode == RiskRatioMode.buy
                                      ? style.bullishColor
                                      : style.bearishColor,
                                  backgroundColor: style.backgroundColor,
                                  textColor:       style.textColor,
                                  initialMode:     state.riskRatioMode,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Resizable Divider ─────────────────────────────────────────────
            // Double-tap → cycling snap:
            //   collapsed (<30% halfBottom) → half
            //   half (<85% maxBottom)       → full (maxBottom)
            //   full                        → half
            GestureDetector(
              onDoubleTap: () {
                setState(() {
                  if (!_bottomExpanded) {
                    // Kalau sedang collapsed, expand ke half dulu
                    _bottomExpanded = true;
                    _bottomHeight   = halfBottom;
                  } else if (_bottomHeight < halfBottom * 0.6) {
                    _bottomHeight = halfBottom;
                  } else if (_bottomHeight < maxBottom * 0.85) {
                    _bottomHeight = maxBottom;
                  } else {
                    _bottomHeight = halfBottom;
                  }
                });
              },
              child: ResizableDivider(
                axis:    Axis.horizontal,
                onDrag:  (delta) => setState(() {
                  final next = _bottomHeight - delta;
                  if (next < _minBottom * 0.5) {
                    // Kalau di-drag terlalu ke bawah → collapse
                    _bottomExpanded = false;
                    _bottomHeight   = _minBottom;
                  } else {
                    _bottomExpanded = true;
                    _bottomHeight   = next.clamp(_minBottom, maxBottom);
                  }
                }),
                minSize: _minBottom,
                maxSize: maxBottom,
                current: _bottomExpanded ? _bottomHeight : _minBottom,
              ),
            ),

            // ── Bottom Panel (editor) ─────────────────────────────────────────
            // AnimatedContainer: transisi tinggi smooth saat snap / drag
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve:    Curves.easeOut,
              height:   _bottomExpanded ? _bottomHeight : 0.0,
              // ClipRect penting — cegah konten editor meluap saat animasi
              child: ClipRect(
                child: _buildBottomPanel(style),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Bottom Panel ──────────────────────────────────────────────────────────

  Widget _buildBottomPanel(CandlestickStyle style) {
    return IsolatedHookProvider(
      hook:  _editorHook,
      child: const TradingViewCodeEditorScreen(),
    );
  }

  // ─── Bottom Controls ───────────────────────────────────────────────────────

  Widget _buildBottomControls(CandlestickStyle style) {
    final state = _controller.state;
    return ChartControls(
      style:             style,
      showVolume:        state.showVolume,
      showGrid:          state.showGrid,
      showCrosshair:     state.showCrosshair,
      isFibonacciMode:   _isFibonacciMode,
      isRiskRatioMode:   state.isRiskRatioMode,
      riskRatioMode:     state.riskRatioMode,
      onToggleVolume:    _controller.toggleVolume,
      onToggleGrid:      _controller.toggleGrid,
      onToggleCrosshair: _controller.toggleCrosshair,
      onToggleFibonacci: _toggleFibonacciMode,
      onToggleRiskRatio: _toggleRiskRatioMode,
      onSwitchRiskRatioMode: () {
        _controller.switchRiskRatioMode();
        _riskRatioKey.currentState?.setMode(state.riskRatioMode);
      },
      onSettings: _showStyleSettings,
      onReset: () {
        _controller.resetViewport();
        _riskRatioKey.currentState?.clearRiskRatio();
        _fibonacciKey.currentState?.clearAll();
        _crosshairNotifier.value = null;
        setState(() {
          _isFibonacciMode = false;
          _pointerOwnership.clear();
          _pendingDraw.clear();
          _activePointers.clear();
        });
      },
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _timeLabel(double x, List<dynamic> candles, ChartViewport vp) {
    if (candles.isEmpty) return '';
    final ci = vp.xToIndex(x);
    if (ci < 0 || ci >= candles.length) return '';
    final t = candles[ci].openTime.toLocal();
    return '${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }
}