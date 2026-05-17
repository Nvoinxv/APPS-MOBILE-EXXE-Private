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

  final GlobalKey<RiskRatioInteractiveState> _riskRatioKey  = GlobalKey();
  final GlobalKey<FibonacciInteractiveState> _fibonacciKey  = GlobalKey();
  final ValueNotifier<Offset?>               _crosshairNotifier = ValueNotifier(null);

  final Map<int, bool>   _pointerOwnership = {};
  final Map<int, Offset> _pendingDraw      = {};
  static const double    _drawThreshold    = 8.0;

  final Set<int>  _activePointers = {};
  final FocusNode _chartFocus     = FocusNode();

  bool _isFibonacciMode = false;
  ChartStyleState _chartStyle = const ChartStyleState();

  // Chart geometry — diupdate dari LayoutBuilder, bukan di build phase
  Size           _lastChartSize = Size.zero;
  ChartViewport? _lastViewport;

  // Throttle state untuk _onControllerUpdate
  double _lastScale   = 1.0;
  double _lastOffsetX = 0.0;
  double _lastOffsetY = 0.0;
  int    _lastCandleCount = 0;
  String _lastTicker      = '';
  String _lastInterval    = '';

  // Panel layout
  double _bottomHeight   = 220.0;
  bool   _bottomExpanded = true;
  static const double _minBottom        = 48.0;
  static const double _dividerThickness = 6.0;

  // FIX: notifier terpisah untuk data chart — isolasi rebuild candle/grid
  // dari rebuild crosshair & UI panel lainnya
  final _chartDataVersion = ValueNotifier<int>(0);

  double _scaleBase  = 1.0;
  Offset _scaleFocal = Offset.zero;

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
    _chartDataVersion.dispose();
    _chartFocus.dispose();
    _editorHook.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Controller update — hanya setState kalau benar-benar perlu
  // ═══════════════════════════════════════════════════════════════════════════

  void _onControllerUpdate() {
    final state = _controller.state;

    // Ticker/interval/loading → full rebuild (UI panel berubah)
    final tickerChanged   = state.selectedTicker   != _lastTicker;
    final intervalChanged = state.selectedInterval != _lastInterval;
    if (tickerChanged || intervalChanged || state.isLoading) {
      _lastTicker   = state.selectedTicker;
      _lastInterval = state.selectedInterval;
      if (mounted) setState(() {});
      return;
    }

    // Candle count berubah → increment notifier, bukan setState global
    final candleCountChanged = state.candles.length != _lastCandleCount;
    if (candleCountChanged) {
      _lastCandleCount = state.candles.length;
      _chartDataVersion.value++;
      return;
    }

    // Scale berubah → viewport perlu rekalkulasi → increment notifier
    final scaleChanged = (state.scale - _lastScale).abs() > 0.001;
    if (scaleChanged) {
      _lastScale = state.scale;
      _chartDataVersion.value++;
      return;
    }

    // Offset berubah (pan) → increment notifier, threshold lebih longgar
    // FIX: threshold dinaikkan 0.5 → 2.0 supaya pan halus tidak spam rebuild
    final offsetChanged =
        (state.offsetX - _lastOffsetX).abs() > 2.0 ||
        (state.offsetY - _lastOffsetY).abs() > 2.0;
    if (offsetChanged) {
      _lastOffsetX = state.offsetX;
      _lastOffsetY = state.offsetY;
      _chartDataVersion.value++;
      return;
    }

    // Selected candle berubah → hanya panel info yang perlu rebuild
    // FIX: dulu selalu setState(), sekarang hanya kalau candle benar-benar beda
    if (state.selectedCandle != null) {
      if (mounted) setState(() {});
    }
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
  // Code editor panel
  // ═══════════════════════════════════════════════════════════════════════════

  void _openCodeEditor() {
    setState(() {
      _bottomExpanded = true;
      if (_bottomHeight < _minBottom * 2) _bottomHeight = 220.0;
    });
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
      _pointerOwnership[e.pointer] = _fibState?.handlePointerDown(pos) ?? false;
      return;
    }

    if (_fibVisible && _isFibonacciMode && _fibState != null && !_fibState!.isDrawing) {
      _pendingDraw[e.pointer]      = pos;
      _pointerOwnership[e.pointer] = false;
      return;
    }

    if (_rrVisible && _rrOwnsImmediately(pos)) {
      _pointerOwnership[e.pointer] = _rrState?.handlePointerDown(pos) ?? false;
      return;
    }

    if (_rrVisible && state.isRiskRatioMode && _rrState != null && !_rrState!.isDrawing) {
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
    final inDrawMode = state.isRiskRatioMode || _isFibonacciMode;

    if (_activePointers.length == 1) {
      if (!inDrawMode) {
        _controller.applyPanDelta(e.delta.dx, e.delta.dy);
      } else {
        final rrHit  = _rrVisible  && _rrOwnsImmediately(pos);
        final fibHit = _fibVisible && _fibOwnsImmediately(pos);
        if (!rrHit && !fibHit) _controller.applyPanDelta(e.delta.dx, e.delta.dy);
      }
    }

    // FIX: crosshair hanya update notifier — tidak sentuh setState sama sekali
    if (state.showCrosshair && !inDrawMode) {
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

  CandlestickStyle _toCandlestickStyle(ChartStyleState s) => CandlestickStyle(
    bullishColor:    s.bullishColor,
    bearishColor:    s.bearishColor,
    backgroundColor: s.backgroundColor,
    gridColor:       s.gridColor.withOpacity(s.gridOpacity),
    textColor:       s.textColor,
    crosshairColor:  s.crosshairColor,
    bullishStyle:    s.bodyStyle,
    bearishStyle:    s.bodyStyle,
  );

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
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: style.textColor, size: 16),
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

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final totalH    = outerConstraints.maxHeight;
        final maxBottom = totalH * 0.80;
        final halfBottom = totalH * 0.40;

        // FIX: clamp SINKRON — tidak pakai SchedulerBinding di dalam build.
        // Kalau _bottomHeight sudah aman, tidak ada setState sama sekali.
        final clampedBottom = _bottomHeight.clamp(0.0, maxBottom);
        if (clampedBottom != _bottomHeight) {
          // Hanya schedule kalau benar-benar perlu koreksi
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted && _bottomHeight != clampedBottom) {
              setState(() => _bottomHeight = clampedBottom);
            }
          });
        }

        return Column(
          children: [
            // ── Chart canvas — pakai ValueListenableBuilder supaya
            //    pan/zoom tidak rebuild seluruh widget tree ──────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // FIX: update _lastChartSize via post-frame, bukan di build phase
                  final newSize = Size(constraints.maxWidth, constraints.maxHeight);
                  if (newSize != _lastChartSize) {
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _lastChartSize = newSize;
                    });
                    _lastChartSize = newSize; // tetap update sinkron untuk render
                  }

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
                        // FIX: chart canvas rebuild hanya saat _chartDataVersion naik,
                        //      bukan setiap setState() dari controller
                        child: ValueListenableBuilder<int>(
                          valueListenable: _chartDataVersion,
                          builder: (context, _, __) {
                            final cs    = _controller.state;
                            final vp    = _controller.buildViewport(_lastChartSize);
                            _lastViewport = vp;
                            final off = Offset(cs.offsetX, cs.offsetY);

                            return Stack(
                              children: [

                                // ── Candles + grid — RepaintBoundary sendiri ──
                                RepaintBoundary(
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Stack(
                                          children: [
                                            if (cs.showGrid)
                                              Positioned.fill(
                                                child: CustomPaint(
                                                  painter: GridInteractive(
                                                    candles:          cs.candles,
                                                    style:            style,
                                                    scale:            cs.scale,
                                                    offsetY:          cs.offsetY,
                                                    offset:           off,
                                                    showVolume:       cs.showVolume,
                                                    selectedInterval: cs.selectedInterval,
                                                  ),
                                                ),
                                              ),
                                            InteractiveCandlestickChart(
                                              candles:          cs.candles,
                                              style:            style,
                                              showVolume:       cs.showVolume,
                                              scale:            cs.scale,
                                              offset:           off,
                                              onScaleUpdate:    null,
                                              onOffsetUpdate:   null,
                                              onCandleSelected: _controller.selectCandle,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (cs.showVolume)
                                        FuturisticVolumeBar(
                                          candles:         cs.candles,
                                          bullishColor:    style.bullishColor,
                                          bearishColor:    style.bearishColor,
                                          backgroundColor: style.backgroundColor,
                                          scale:           cs.scale,
                                          offset:          off,
                                          selectedIndex:   cs.candles.indexOf(
                                            cs.selectedCandle ?? cs.candles.last,
                                          ),
                                          height: AppSizes.volumeBarHeight,
                                        ),
                                    ],
                                  ),
                                ),

                                // ── Crosshair — ValueListenableBuilder sendiri,
                                //    zero setState ─────────────────────────────
                                if (cs.showCrosshair && !cs.isRiskRatioMode && !_isFibonacciMode)
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
                                              timeLabel:            _timeLabel(pos.dx, cs.candles, currentVp),
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
                                      accentColor:     cs.riskRatioMode == RiskRatioMode.buy
                                          ? style.bullishColor
                                          : style.bearishColor,
                                      backgroundColor: style.backgroundColor,
                                      textColor:       style.textColor,
                                      initialMode:     cs.riskRatioMode,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Resizable divider ──────────────────────────────────────────
            GestureDetector(
              onDoubleTap: () {
                setState(() {
                  if (!_bottomExpanded) {
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

            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve:    Curves.easeOut,
              height:   _bottomExpanded ? clampedBottom : 0.0,
              child: ClipRect(child: _buildBottomPanel(style)),
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
      onSettings:       _showStyleSettings,
      onOpenCodeEditor: _openCodeEditor,
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