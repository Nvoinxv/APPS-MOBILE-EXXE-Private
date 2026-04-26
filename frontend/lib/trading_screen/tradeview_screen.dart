import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../chart/candle_info_panel.dart';
import '../chart/price_header.dart';
import '../chart/volume_section.dart';

import '../controller/chart_controller_2.dart';
import '../controller/chart_controls.dart';
import '../controller/interval_selector.dart';
import '../controller/risk_ratio_button.dart';
import '../controller/ticker_selector.dart';
import '../controller/strategy_button_2.dart';
import '../controller/chart_viewport.dart';

import '../dialogs/style_settings.dart';  
import '../dialogs/chart_style.dart';      

import '../interactive/interactive_candlestick_chart.dart';
import '../interactive/risk_ratio_interactive_2.dart';
import '../interactive/volume_interactive.dart';
import '../interactive/cross_interactive.dart';
import '../interactive/grid_interactive.dart';
import '../interactive/strategy_interactive_2.dart';

import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../candle/candle_normal.dart';

import '../Strategy/Strategy_two_main.dart';

class TradeViewScreen extends StatefulWidget {
  final String token;
  const TradeViewScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<TradeViewScreen> createState() => _TradeViewScreenState();
}

class _TradeViewScreenState extends State<TradeViewScreen> {
  late ChartController _controller;
  final GlobalKey<RiskRatioInteractiveState> _riskRatioKey = GlobalKey();
  final GlobalKey<MainStrategyState>         _strategyKey  = GlobalKey<MainStrategyState>();

  final _strategy2Controller = Strategy2Controller();

  final ValueNotifier<Offset?> _crosshairNotifier = ValueNotifier(null);

  final Map<int, bool>   _pointerOwnership = {};
  final Map<int, Offset> _pendingDraw      = {};
  static const double    _drawThreshold    = 8.0;

  final Set<int> _activePointers = {};
  final FocusNode _chartFocus = FocusNode();

  // ── Style state ───────────────────────────────────────────────────────────
  ChartStyleState _chartStyle = const ChartStyleState();  // ← tambah

  Size _lastChartSize = Size.zero;
  ChartViewport? _lastViewport;

  double _scaleBase  = 1.0;
  Offset _scaleFocal = Offset.zero;

  int    _lastCandleCount = 0;
  String _lastTicker      = '';
  String _lastInterval    = '';
  double _lastScale       = 1.0;
  double _lastOffsetX     = 0.0;
  double _lastOffsetY     = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = ChartController(
      availableTickers:   CryptoPairs.major,
      availableIntervals: TimeframeConstants.common,
    );
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _strategy2Controller.dispose();
    _crosshairNotifier.dispose();
    _chartFocus.dispose();
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
      if (DataValidator.isCandlesValid(state.candles)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _strategyKey.currentState?.runHistorical();
        });
      }
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

  // ← isi sekarang, sebelumnya kosong
  void _showStyleSettings() {
    StyleSettingsPanel.show(
      context,
      currentStyle: _chartStyle,
      onChanged:    (next) => setState(() => _chartStyle = next),
    );
  }

  // ── Pointer handling ──────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    if (e.buttons == kSecondaryMouseButton) {
      _rrState?.handleRightClick(context, e.localPosition);
      return;
    }

    _activePointers.add(e.pointer);

    final pos   = e.localPosition;
    final state = _controller.state;

    if (_rrVisible && _rrOwnsImmediately(pos)) {
      final claimed = _rrState?.handlePointerDown(pos) ?? false;
      _pointerOwnership[e.pointer] = claimed;
      return;
    }

    if (_rrVisible &&
        state.isRiskRatioMode &&
        _rrState != null &&
        !(_rrState!.isDrawing)) {
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
      _rrState?.handlePointerMove(pos);
      return;
    }

    final drawStart = _pendingDraw[e.pointer];
    if (drawStart != null) {
      if ((pos - drawStart).distance >= _drawThreshold) {
        _pendingDraw.remove(e.pointer);
        _pointerOwnership[e.pointer] = true;
        _rrState?.startDrawing(drawStart);
        _rrState?.handlePointerMove(pos);
      }
      return;
    }

    final state = _controller.state;

    if (!state.isRiskRatioMode && _activePointers.length == 1) {
      _controller.applyPanDelta(e.delta.dx, 0);
    }

    if (state.showCrosshair && !state.isRiskRatioMode) {
      _crosshairNotifier.value = pos;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _activePointers.remove(e.pointer);
    _pendingDraw.remove(e.pointer);

    final owned = _pointerOwnership.remove(e.pointer);
    if (owned == true) {
      _rrState?.handlePointerUp(e.localPosition);
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

  // ── Build ─────────────────────────────────────────────────────────────────
  // ── Di dalam _TradeViewScreenState, tambah method ini ──────────────────────
  CandlestickStyle _toCandlestickStyle(ChartStyleState s) {
    return CandlestickStyle(
      bullishColor:    s.bullishColor,
      bearishColor:    s.bearishColor,
      backgroundColor: s.backgroundColor,
      gridColor:       s.gridColor.withOpacity(s.gridOpacity),
      textColor:       s.textColor,
      crosshairColor:  s.crosshairColor,
      bullishStyle:    s.bodyStyle,   // CandleBodyStyle sudah sama enum-nya
      bearishStyle:    s.bodyStyle,
    );
  }


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

  Widget _buildTopControls(CandlestickStyle style) {
    final state = _controller.state;
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingLarge),
      decoration: BoxDecoration(
        color:  style.backgroundColor,
        border: Border(bottom: BorderSide(color: style.gridColor)),
      ),
      child: Row(
        children: [
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
          RiskRatioButton(
            isActive: state.isRiskRatioMode,
            mode:     state.riskRatioMode,
            style:    style,
            onTap:    _toggleRiskRatioMode,
          ),
        ],
      ),
    );
  }

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
      builder: (context, constraints) {
        final newSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (newSize != _lastChartSize) _lastChartSize = newSize;

        final vp = _controller.buildViewport(_lastChartSize);
        _lastViewport = vp;

        final minPrice       = vp.minPrice;
        final maxPrice       = vp.maxPrice;
        final offsetAsOffset = Offset(state.offsetX, state.offsetY);

        return KeyboardListener(
          focusNode: _chartFocus,
          autofocus: true,
          onKeyEvent: (event) {
            _rrState?.handleKeyEvent(event);
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

                  Positioned.fill(
                    child: Strategy2Gate(
                      controller: _strategy2Controller,
                      builder: (isSignalEnabled) => MainStrategy(
                        key:             _strategyKey,
                        chartSize:       _lastChartSize,
                        totalCandles:    state.candles.length,
                        scale:           state.scale,
                        scrollOffset:    state.offsetX,
                        minPrice:        minPrice,
                        maxPrice:        maxPrice,
                        candles:         state.candles,
                        isSignalEnabled: isSignalEnabled,
                      ),
                    ),
                  ),

                  if (state.showCrosshair && !state.isRiskRatioMode)
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
    );
  }

  Widget _buildBottomControls(CandlestickStyle style) {
    final state = _controller.state;
    return ChartControls(
      style:             style,
      showVolume:        state.showVolume,
      showGrid:          state.showGrid,
      showCrosshair:     state.showCrosshair,
      isFibonacciMode:   false,
      isRiskRatioMode:   state.isRiskRatioMode,
      riskRatioMode:     state.riskRatioMode,
      onToggleVolume:    _controller.toggleVolume,
      onToggleGrid:      _controller.toggleGrid,
      onToggleCrosshair: _controller.toggleCrosshair,
      onToggleFibonacci: () {},
      onToggleRiskRatio: _toggleRiskRatioMode,
      onSwitchRiskRatioMode: () {
        _controller.switchRiskRatioMode();
        _riskRatioKey.currentState?.setMode(state.riskRatioMode);
      },
      onSettings: _showStyleSettings,
      onReset: () {
        _controller.resetViewport();
        _riskRatioKey.currentState?.clearRiskRatio();
        _crosshairNotifier.value = null;
        setState(() {
          _pointerOwnership.clear();
          _pendingDraw.clear();
          _activePointers.clear();
        });
      },
      strategy2Button: Strategy2Button(
        isActive: _strategy2Controller.isActive,
        onTap:    _strategy2Controller.toggle,
        style:    style,
      ),
    );
  }

  String _timeLabel(double x, List<dynamic> candles, ChartViewport vp) {
    if (candles.isEmpty) return '';
    final ci = vp.xToIndex(x);
    if (ci < 0 || ci >= candles.length) return '';
    final t = candles[ci].openTime.toLocal();
    return '${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }
}