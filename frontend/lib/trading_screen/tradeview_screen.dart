import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../chart/candle_info_panel.dart';
import '../chart/price_header.dart';
import '../chart/volume_section.dart';

import '../controller/chart_controller.dart';
import '../controller/chart_controls.dart';
import '../controller/interval_selector.dart';
import '../controller/risk_ratio_button.dart';
import '../controller/ticker_selector.dart';
import '../controller/strategy_button_2.dart';           // ← BARU

import '../dialogs/style_settings.dart';
import '../dialogs/context_menu.dart';

import '../interactive/interactive_candlestick_chart.dart';
import '../interactive/risk_ratio_interactive.dart';
import '../interactive/volume_interactive.dart';
import '../interactive/cross_interactive.dart';
import '../interactive/grid_interactive.dart';
import '../interactive/strategy_interactive_2.dart';     // ← BARU

import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../models/chart_theme.dart';

import '../Strategy/Strategy_two_main.dart';
import '../Strategy/utils/chart_utils.dart';

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

  // ── Strategy 2 controller ────────────────────────────────────────────
  final _strategy2Controller = Strategy2Controller();

  Offset? _crosshairPosition;

  final Map<int, bool>   _pointerOwnership = {};
  final Map<int, Offset> _pendingDraw      = {};
  static const double    _drawThreshold    = 8.0;

  double _panStartOffsetX = 0.0;
  double _panStartOffsetY = 0.0;

  Size _lastChartSize = Size.zero;

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
    _strategy2Controller.dispose();                      // ← dispose controller
    super.dispose();
  }

  void _onControllerUpdate() {
    setState(() {});

    if (DataValidator.isCandlesValid(_controller.state.candles)) {
      _strategyKey.currentState?.runHistorical();
    }
  }

  RiskRatioInteractiveState? get _rrState => _riskRatioKey.currentState;

  bool get _rrVisible =>
      _controller.state.isRiskRatioMode || (_rrState?.riskRatio != null);

  bool _rrOwnsImmediately(Offset pos) {
    final rr = _rrState;
    if (rr == null || rr.riskRatio == null) return false;
    return rr.isInsideInteractiveArea(pos);
  }

  ChartCoordinateMapper _buildMapper(Size chartSize) {
    final state = _controller.state;
    return ChartCoordinateMapper(
      totalCandles: state.candles.length,
      minPrice:     _controller.getMinPrice(),
      maxPrice:     _controller.getMaxPrice(),
      chartSize:    chartSize,
      scale:        state.scale,
      offset:       state.offset.dx,
    );
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

  void _showRiskRatioContextMenu(BuildContext context, Offset position) {
    context.showRiskRatioMenu(
      globalPosition: position,
      style:          _controller.state.chartStyle,
      riskRatioKey:   _riskRatioKey,
      onModeChanged:  (newMode) => _controller.switchRiskRatioMode(),
      onUpdate:       () => setState(() {}),
    );
  }

  void _showStyleSettings() {
    context.showStyleSettings(
      currentStyle:   _controller.state.chartStyle,
      onStyleChanged: _controller.changeTheme,
    );
  }

  void _onPointerDown(PointerDownEvent e) {
    if (e.buttons == kSecondaryButton) return;

    final pos   = e.localPosition;
    final state = _controller.state;

    if (_rrVisible && _rrOwnsImmediately(pos)) {
      _pointerOwnership[e.pointer] = true;
      _rrState?.handlePointerDown(pos);
      return;
    }

    if (_rrVisible &&
        state.isRiskRatioMode &&
        (_rrState?.riskRatio == null ?? true) &&
        !(_rrState?.isDrawing ?? false)) {
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
        _rrState?.updateDrawing(pos);
      }
      return;
    }

    if (!_controller.state.isInDrawingMode &&
        !_controller.state.isRiskRatioMode) {
      final delta = e.delta;
      _controller.updateOffset(Offset(_controller.state.offset.dx + delta.dx, 0));
      _controller.updateOffsetY(_controller.state.offsetY + delta.dy);
    }

    if (_controller.state.showCrosshair &&
        !_controller.state.isInDrawingMode &&
        !_controller.state.isRiskRatioMode) {
      setState(() => _crosshairPosition = pos);
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _pendingDraw.remove(e.pointer);
    final owned = _pointerOwnership.remove(e.pointer);
    if (owned == true) {
      _rrState?.handlePointerUp(e.localPosition);
    } else {
      if (mounted) setState(() => _crosshairPosition = null);
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _pendingDraw.remove(e.pointer);
    final owned = _pointerOwnership.remove(e.pointer);
    if (owned == true) {
      _rrState?.handlePointerCancel();
    } else {
      if (mounted) setState(() => _crosshairPosition = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    return Scaffold(
      backgroundColor: state.chartStyle.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopControls(),
            if (DataValidator.isCandlesValid(state.candles))
              PriceHeader(
                candles:          state.candles,
                selectedTicker:   state.selectedTicker,
                selectedInterval: state.selectedInterval,
                chartStyle:       state.chartStyle,
              ),
            Expanded(child: _buildChartArea()),
            if (state.selectedCandle != null)
              CandleInfoPanel(
                selectedCandle: state.selectedCandle!,
                chartStyle:     state.chartStyle,
              ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    final state = _controller.state;
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingLarge),
      decoration: BoxDecoration(
        color:  state.chartStyle.backgroundColor,
        border: Border(bottom: BorderSide(color: state.chartStyle.gridColor)),
      ),
      child: Row(
        children: [
          TickerSelector(
            selectedTicker:   state.selectedTicker,
            availableTickers: _controller.availableTickers,
            style:            state.chartStyle,
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
                backgroundColor:    state.chartStyle.backgroundColor,
                selectedColor:      state.chartStyle.bullishColor,
                unselectedColor:    state.chartStyle.textColor.withOpacity(0.5),
                borderColor:        state.chartStyle.gridColor,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.paddingLarge),
          RiskRatioButton(
            isActive:  state.isRiskRatioMode,
            mode:      state.riskRatioMode,
            style:     state.chartStyle,
            onTap:     _toggleRiskRatioMode,
            onLongPress: () {
              _controller.switchRiskRatioMode();
              _riskRatioKey.currentState?.setMode(state.riskRatioMode);
            },
            onShowContextMenu: _showRiskRatioContextMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildChartArea() {
    final state = _controller.state;

    if (state.isLoading) {
      return LoadingStateHelper.createLoadingWidget(
        color:     state.chartStyle.bullishColor,
        message:   '${ErrorMessages.loadingPrefix} ${state.selectedTicker} ${state.selectedInterval}...',
        textColor: state.chartStyle.textColor,
      );
    }

    if (!DataValidator.isCandlesValid(state.candles)) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(
            color:    state.chartStyle.textColor.withOpacity(0.5),
            fontSize: AppSizes.fontRegular,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartSize = Size(constraints.maxWidth, constraints.maxHeight * 0.6);
        _lastChartSize  = chartSize;
        final mapper    = _buildMapper(chartSize);

        return Listener(
          behavior:        HitTestBehavior.translucent,
          onPointerDown:   _onPointerDown,
          onPointerMove:   _onPointerMove,
          onPointerUp:     _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: Stack(
            children: [

              // ── Layer 1: Grid + Candles + Volume ──────────────────────
              Column(
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
                                style:            state.chartStyle,
                                scale:            state.scale,
                                offsetY:          state.offsetY,
                                offset:           state.offset,
                                showVolume:       state.showVolume,
                                selectedInterval: state.selectedInterval,
                              ),
                            ),
                          ),
                        InteractiveCandlestickChart(
                          candles:          state.candles,
                          style:            state.chartStyle,
                          showVolume:       state.showVolume,
                          scale:            state.scale,
                          offset:           state.offset,
                          onScaleUpdate:    _controller.updateScale,
                          onOffsetUpdate:   _controller.updateOffset,
                          onCandleSelected: _controller.selectCandle,
                        ),
                      ],
                    ),
                  ),
                  if (state.showVolume)
                    FuturisticVolumeBar(
                      candles:         state.candles,
                      bullishColor:    state.chartStyle.bullishColor,
                      bearishColor:    state.chartStyle.bearishColor,
                      backgroundColor: state.chartStyle.backgroundColor,
                      scale:           state.scale,
                      offset:          state.offset,
                      selectedIndex:   state.candles.indexOf(
                        state.selectedCandle ?? state.candles.last,
                      ),
                      height: AppSizes.volumeBarHeight,
                    ),
                ],
              ),

              // ── Layer 2: MainStrategy (dibungkus Strategy2Gate) ───────
              Positioned.fill(
                child: Strategy2Gate(
                  controller: _strategy2Controller,
                  builder: (isSignalEnabled) => MainStrategy(
                    key:             _strategyKey,
                    chartSize:       chartSize,
                    totalCandles:    state.candles.length,
                    scale:           state.scale,
                    scrollOffset:    state.offset.dx,
                    minPrice:        _controller.getMinPrice(),
                    maxPrice:        _controller.getMaxPrice(),
                    candles:         state.candles,
                    isSignalEnabled: isSignalEnabled,   // ← dari gate
                  ),
                ),
              ),

              // ── Layer 3: Crosshair ─────────────────────────────────────
              if (state.showCrosshair &&
                  !state.isInDrawingMode &&
                  !state.isRiskRatioMode &&
                  _crosshairPosition != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: CrosshairPainter(
                        position:             _crosshairPosition!,
                        color:                state.chartStyle.bullishColor,
                        strokeWidth:          1.0,
                        showLabels:           true,
                        priceLabel:           state.crosshairPriceLabel,
                        timeLabel:            state.crosshairTimeLabel,
                        labelBackgroundColor: state.chartStyle.backgroundColor,
                        labelTextColor:       state.chartStyle.textColor,
                      ),
                    ),
                  ),
                ),

              // ── Layer 4: Risk Ratio ────────────────────────────────────
              if (_rrVisible)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RiskRatioInteractive(
                      key:             _riskRatioKey,
                      chartSize:       chartSize,
                      accentColor:     state.riskRatioMode == RiskRatioMode.buy
                          ? state.chartStyle.bullishColor
                          : state.chartStyle.bearishColor,
                      backgroundColor: state.chartStyle.backgroundColor,
                      textColor:       state.chartStyle.textColor,
                      minPrice:        _controller.getMinPrice(),
                      maxPrice:        _controller.getMaxPrice(),
                      initialMode:     state.riskRatioMode,
                      mapper:          mapper,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    final state = _controller.state;
    return ChartControls(
      style:             state.chartStyle,
      showVolume:        state.showVolume,
      showGrid:          state.showGrid,
      showCrosshair:     state.showCrosshair,
      isFibonacciMode:   state.isFibonacciMode,
      isRiskRatioMode:   state.isRiskRatioMode,
      riskRatioMode:     state.riskRatioMode,
      onToggleVolume:    _controller.toggleVolume,
      onToggleGrid:      _controller.toggleGrid,
      onToggleCrosshair: _controller.toggleCrosshair,
      onToggleFibonacci: _controller.toggleFibonacciMode,
      onToggleRiskRatio: _toggleRiskRatioMode,
      onSwitchRiskRatioMode: () {
        _controller.switchRiskRatioMode();
        _riskRatioKey.currentState?.setMode(state.riskRatioMode);
      },
      onShowRiskRatioContextMenu: _showRiskRatioContextMenu,
      onSettings: _showStyleSettings,
      onReset: () {
        _controller.resetZoomPan();
        _riskRatioKey.currentState?.clearRiskRatio();
        setState(() {
          _crosshairPosition = null;
          _pointerOwnership.clear();
          _pendingDraw.clear();
        });
      },
      // ── Strategy 2 button ─────────────────────────────────────────────
      strategy2Button: Strategy2Button(
        isActive: _strategy2Controller.isActive,
        onTap:    _strategy2Controller.toggle,
        style:    state.chartStyle,
      ),
    );
  }
}