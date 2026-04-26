import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;

import '../hooks/crypto_data_hook.dart';
import '../controller/risk_ratio_button.dart';
import 'chart_viewport.dart';
import '../interactive/risk_ratio_interactive_2.dart';

// ===========================================================================
// ChartState — immutable, semua perubahan buat instance baru
// ===========================================================================

@immutable
class ChartState {
  final List<CryptoCandle> candles;
  final String  selectedTicker;
  final String  selectedInterval;
  final bool    isLoading;

  final double  scale;
  final double  offsetX;
  final double  offsetY;

  final bool showVolume;
  final bool showGrid;
  final bool showCrosshair;
  final bool isRiskRatioMode;
  final RiskRatioMode riskRatioMode;

  final CryptoCandle? selectedCandle;

  const ChartState({
    this.candles         = const [],
    this.selectedTicker  = '',
    this.selectedInterval = '',
    this.isLoading       = true,
    this.scale           = 1.0,
    this.offsetX         = 0.0,
    this.offsetY         = 0.0,
    this.showVolume      = true,
    this.showGrid        = true,
    this.showCrosshair   = false,
    this.isRiskRatioMode = false,
    this.riskRatioMode   = RiskRatioMode.buy,
    this.selectedCandle  = null,
  });

  ChartState copyWith({
    List<CryptoCandle>? candles,
    String?  selectedTicker,
    String?  selectedInterval,
    bool?    isLoading,
    double?  scale,
    double?  offsetX,
    double?  offsetY,
    bool?    showVolume,
    bool?    showGrid,
    bool?    showCrosshair,
    bool?    isRiskRatioMode,
    RiskRatioMode? riskRatioMode,
    CryptoCandle? selectedCandle,
  }) => ChartState(
    candles:          candles          ?? this.candles,
    selectedTicker:   selectedTicker   ?? this.selectedTicker,
    selectedInterval: selectedInterval ?? this.selectedInterval,
    isLoading:        isLoading        ?? this.isLoading,
    scale:            scale            ?? this.scale,
    offsetX:          offsetX          ?? this.offsetX,
    offsetY:          offsetY          ?? this.offsetY,
    showVolume:       showVolume       ?? this.showVolume,
    showGrid:         showGrid         ?? this.showGrid,
    showCrosshair:    showCrosshair    ?? this.showCrosshair,
    isRiskRatioMode:  isRiskRatioMode  ?? this.isRiskRatioMode,
    riskRatioMode:    riskRatioMode    ?? this.riskRatioMode,
    selectedCandle:   selectedCandle   ?? this.selectedCandle,
  );
}

// ===========================================================================
// ChartController
// ===========================================================================

class ChartController extends ChangeNotifier {
  final List<String> availableTickers;
  final List<String> availableIntervals;

  ChartState _state;
  late CryptoDataHook _hook;

  ChartController({
    required this.availableTickers,
    required this.availableIntervals,
  }) : _state = ChartState(
    selectedTicker:   availableTickers.first,
    selectedInterval: availableIntervals.first,
  ) {
    _initHook();
  }

  ChartState get state => _state;

  void _setState(ChartState next) {
    _state = next;
    notifyListeners();
  }

  void _initHook() {
    _hook = CryptoDataHook(
      tickers:             availableTickers,
      intervals:           availableIntervals,
      autoUpdateInterval:  60,
    );
    _hook.onDataUpdate = (ticker, interval, candles) {
      if (ticker == _state.selectedTicker && interval == _state.selectedInterval) {
        _setState(_state.copyWith(candles: candles, isLoading: false));
      }
    };
    _hook.onError = (ticker, interval, err) => debugPrint('⚠️ $ticker $interval: $err');
    _hook.startAdaptiveUpdate();
  }

  // ---------------------------------------------------------------------------
  // Viewport — dibuat on-demand
  // ---------------------------------------------------------------------------

  ChartViewport buildViewport(Size chartSize) {
    final candles = _state.candles;

    // FIX #6: Guard size kosong — hindari division by zero di candleWidth
    if (chartSize.isEmpty) {
      return ChartViewport(
        totalCandles: 0, minPrice: 0, maxPrice: 100,
        chartSize: const Size(1, 1),
        scale: _state.scale, offsetX: _state.offsetX, offsetY: _state.offsetY,
      );
    }

    if (candles.isEmpty) {
      return ChartViewport(
        totalCandles: 0, minPrice: 0, maxPrice: 100,
        chartSize: chartSize, scale: _state.scale,
        offsetX: _state.offsetX, offsetY: _state.offsetY,
      );
    }

    final allLow  = candles.map((c) => c.low).reduce(math.min);
    final allHigh = candles.map((c) => c.high).reduce(math.max);
    final range   = allHigh - allLow;

    // FIX #6: Guard range nol — semua candle harga sama (edge case data flat)
    final pad = range > 0 ? range * 0.02 : allHigh * 0.01;

    return ChartViewport(
      totalCandles: candles.length,
      minPrice:     allLow  - pad,
      maxPrice:     allHigh + pad,
      chartSize:    chartSize,
      scale:        _state.scale,
      offsetX:      _state.offsetX,
      offsetY:      _state.offsetY,
    );
  }

  // ---------------------------------------------------------------------------
  // Zoom/Pan
  // ---------------------------------------------------------------------------

  void updateScale(double newScale, {Offset? focalPoint, Size? chartSize}) {
    final clamped = newScale.clamp(0.3, 10.0);

    if (focalPoint != null && chartSize != null) {
      final vp         = buildViewport(chartSize);
      final focalData  = vp.xToIndexF(focalPoint.dx);
      final newVp      = vp.copyWith(scale: clamped);
      final newScreenX = (focalData + 0.5) * newVp.candleWidth + _state.offsetX;
      final dOffset    = focalPoint.dx - newScreenX;
      _setState(_state.copyWith(scale: clamped, offsetX: _state.offsetX + dOffset));
    } else {
      _setState(_state.copyWith(scale: clamped));
    }
  }

  // FIX #1 & #6: Pan atomik — satu notifyListeners per move event, bukan dua
  void applyPanDelta(double dx, double dy) {
    // Guard NaN — bisa datang dari ScaleUpdateDetails.focalPointDelta saat gesture dibatalkan OS
    if (!dx.isFinite || !dy.isFinite) return;
    _setState(_state.copyWith(
      offsetX: _state.offsetX + dx,
      offsetY: _state.offsetY + dy,
    ));
  }

  // Tetap ada untuk backward-compatibility dengan kode lain yang mungkin memanggil ini
  // tapi di trade_view_screen sudah diganti ke applyPanDelta
  void updateOffsetX(double dx) {
    if (!dx.isFinite) return;
    _setState(_state.copyWith(offsetX: _state.offsetX + dx));
  }

  void updateOffsetY(double dy) {
    if (!dy.isFinite) return;
    _setState(_state.copyWith(offsetY: _state.offsetY + dy));
  }

  void resetViewport() => _setState(_state.copyWith(scale: 1.0, offsetX: 0.0, offsetY: 0.0));

  // ---------------------------------------------------------------------------
  // Ticker / Interval
  // ---------------------------------------------------------------------------

  void changeTicker(String ticker) {
    _setState(_state.copyWith(
      selectedTicker:  ticker,
      isLoading:       true,
      candles:         [],
      selectedCandle:  null,
      offsetX:         0.0,
      offsetY:         0.0,
    ));
    final cached = _hook.getCandles(ticker, _state.selectedInterval);
    if (cached != null && cached.isNotEmpty) {
      _setState(_state.copyWith(candles: cached, isLoading: false));
    }
  }

  void changeInterval(String interval) {
    _setState(_state.copyWith(
      selectedInterval: interval,
      isLoading:        true,
      candles:          [],
      offsetX:          0.0,
      offsetY:          0.0,
    ));
    final cached = _hook.getCandles(_state.selectedTicker, interval);
    if (cached != null && cached.isNotEmpty) {
      _setState(_state.copyWith(candles: cached, isLoading: false));
    }
  }

  // ---------------------------------------------------------------------------
  // UI toggles
  // ---------------------------------------------------------------------------

  void selectCandle(CryptoCandle? c) => _setState(_state.copyWith(selectedCandle: c));
  void toggleVolume()    => _setState(_state.copyWith(showVolume:    !_state.showVolume));
  void toggleGrid()      => _setState(_state.copyWith(showGrid:      !_state.showGrid));
  void toggleCrosshair() => _setState(_state.copyWith(showCrosshair: !_state.showCrosshair));

  void toggleRiskRatioMode() {
    _setState(_state.copyWith(isRiskRatioMode: !_state.isRiskRatioMode));
  }

  void switchRiskRatioMode() {
    final next = _state.riskRatioMode == RiskRatioMode.buy
        ? RiskRatioMode.sell : RiskRatioMode.buy;
    _setState(_state.copyWith(riskRatioMode: next));
  }

  @override
  void dispose() {
    _hook.dispose();
    super.dispose();
  }
}

// ===========================================================================
// TradeViewScreen (template minimal — struktur sama dengan versi kamu)
// ===========================================================================

class TradeViewScreen extends StatefulWidget {
  final String token;
  const TradeViewScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<TradeViewScreen> createState() => _TradeViewScreenState();
}

class _TradeViewScreenState extends State<TradeViewScreen> {
  late ChartController _ctrl;
  final GlobalKey<RiskRatioInteractiveState> _rrKey = GlobalKey();
  final ValueNotifier<Offset?> _crosshair = ValueNotifier(null);

  final Map<int, bool>   _pointerOwned = {};
  final Map<int, Offset> _pendingDraw  = {};
  static const double    _drawThreshold = 8.0;

  double _scaleBase  = 1.0;
  Offset _scaleFocal = Offset.zero;
  Size   _chartSize  = Size.zero;

  // FIX #4: Simpan viewport terakhir yang valid supaya crosshair selalu
  // pakai viewport yang sinkron dengan frame build terakhir
  ChartViewport? _lastViewport;

  @override
  void initState() {
    super.initState();
    _ctrl = ChartController(
      availableTickers:   const ['BTC-USDT', 'ETH-USDT', 'BNB-USDT'],
      availableIntervals: const ['1m', '5m', '15m', '1h', '4h', '1d'],
    );
    _ctrl.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onStateChanged);
    _ctrl.dispose();
    _crosshair.dispose();
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  // ---------------------------------------------------------------------------
  // Pointer handling
  // ---------------------------------------------------------------------------

  void _onPointerDown(PointerDownEvent e) {
    if (e.buttons == kSecondaryButton) return;
    final pos     = e.localPosition;
    final rrState = _rrKey.currentState;

    if (rrState?.isInsideInteractiveArea(pos) ?? false) {
      if (rrState!.handlePointerDown(pos)) {
        _pointerOwned[e.pointer] = true;
        return;
      }
    }

    if (_ctrl.state.isRiskRatioMode && (rrState?.overlay == null ?? true)) {
      _pendingDraw[e.pointer]  = pos;
      _pointerOwned[e.pointer] = false;
      return;
    }

    _pointerOwned[e.pointer] = false;
  }

  void _onPointerMove(PointerMoveEvent e) {
    final pos   = e.localPosition;
    final owned = _pointerOwned[e.pointer];

    // ── Pointer diklaim RR overlay ──
    if (owned == true) {
      _rrKey.currentState?.handlePointerMove(pos);
      return;
    }

    // ── Pending draw threshold ──
    final drawStart = _pendingDraw[e.pointer];
    if (drawStart != null) {
      if ((pos - drawStart).distance >= _drawThreshold) {
        _pendingDraw.remove(e.pointer);
        _pointerOwned[e.pointer] = true;
        _rrKey.currentState?.startDrawing(drawStart);
        _rrKey.currentState?.handlePointerMove(pos);
      }
      return;
    }

    final state = _ctrl.state;

    // FIX #2: Pan hanya lewat Listener (onPointerMove), BUKAN juga dari
    // GestureDetector.onScaleUpdate saat pointerCount==1.
    // Keduanya sekarang tidak aktif bersamaan — lihat _buildChartArea.
    if (!state.isRiskRatioMode) {
      // FIX #1: Satu call, satu notifyListeners
      _ctrl.applyPanDelta(e.delta.dx, e.delta.dy);
    }

    // FIX #4: Crosshair pakai ValueNotifier — tidak setState
    if (state.showCrosshair && !state.isRiskRatioMode) {
      _crosshair.value = pos;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _pendingDraw.remove(e.pointer);
    final owned = _pointerOwned.remove(e.pointer);
    if (owned == true) {
      _rrKey.currentState?.handlePointerUp(e.localPosition);
    } else {
      _crosshair.value = null;
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _pendingDraw.remove(e.pointer);
    final owned = _pointerOwned.remove(e.pointer);
    if (owned == true) {
      _rrKey.currentState?.handlePointerCancel();
    } else {
      _crosshair.value = null;
    }
  }

  // FIX #2: Scale gesture — HANYA untuk pinch (pointerCount >= 2)
  // Pan single-finger sepenuhnya ditangani Listener di atas
  void _onScaleStart(ScaleStartDetails d) {
    _scaleBase  = _ctrl.state.scale;
    _scaleFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    // FIX #2: Jangan pan dari sini saat single finger —
    // onPointerMove sudah menanganinya. Duplicate pan = chart loncat 2x.
    if (d.pointerCount >= 2) {
      _ctrl.updateScale(
        _scaleBase * d.scale,
        focalPoint: _scaleFocal,
        chartSize:  _chartSize,
      );
    }
    // pointerCount == 1: diabaikan di sini, sudah ditangani Listener
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = _ctrl.state;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            RepaintBoundary(child: _buildTopBar()),
            Expanded(child: _buildChartArea()),
            RepaintBoundary(child: _buildBottomBar()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 48,
      color: Colors.grey[900],
      child: const Center(child: Text('Top Bar', style: TextStyle(color: Colors.white))),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 48,
      color: Colors.grey[900],
      child: const Center(child: Text('Bottom Bar', style: TextStyle(color: Colors.white))),
    );
  }

  Widget _buildChartArea() {
    final state = _ctrl.state;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }

    if (state.candles.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: Colors.white54)));
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        _chartSize = Size(constraints.maxWidth, constraints.maxHeight);

        final vp = _ctrl.buildViewport(_chartSize);

        // FIX #4: Simpan viewport — dipakai crosshair ValueListenableBuilder
        // yang bisa fire async setelah build selesai
        _lastViewport = vp;

        return GestureDetector(
          onScaleStart:  _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: Listener(
            behavior:        HitTestBehavior.translucent,
            onPointerDown:   _onPointerDown,
            onPointerMove:   _onPointerMove,
            onPointerUp:     _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: Stack(
              children: [

                // ── Layer 1: Candles ─────────────────────────────────────
                // RepaintBoundary: tidak repaint saat crosshair bergerak
                RepaintBoundary(
                  child: _CandleLayer(viewport: vp, candles: state.candles),
                ),

                // ── Layer 2: Risk Ratio overlay ──────────────────────────
                // TIDAK pakai RepaintBoundary — harus repaint saat vp berubah
                if (state.isRiskRatioMode || (_rrKey.currentState?.overlay != null))
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RiskRatioInteractive(
                        key:             _rrKey,
                        viewport:        vp,
                        accentColor:     state.riskRatioMode == RiskRatioMode.buy
                            ? Colors.green : Colors.red,
                        backgroundColor: Colors.black,
                        textColor:       Colors.white,
                        initialMode:     state.riskRatioMode,
                      ),
                    ),
                  ),

                // ── Layer 3: Crosshair ───────────────────────────────────
                // ValueListenableBuilder: zero setState, zero repaint pada layer lain
                if (state.showCrosshair && !state.isRiskRatioMode)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<Offset?>(
                        valueListenable: _crosshair,
                        builder: (_, pos, __) {
                          if (pos == null) return const SizedBox.shrink();
                          // FIX #4: Pakai _lastViewport bukan vp dari closure build
                          // supaya tidak stale saat gesture terjadi antar frame
                          final currentVp = _lastViewport;
                          if (currentVp == null) return const SizedBox.shrink();
                          return CustomPaint(
                            painter: _CrosshairPainter(
                              position: pos,
                              viewport: currentVp,
                              candles:  state.candles,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===========================================================================
// _CandleLayer
// ===========================================================================

class _CandleLayer extends StatelessWidget {
  final ChartViewport      viewport;
  final List<CryptoCandle> candles;

  const _CandleLayer({required this.viewport, required this.candles});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CandlePainter(viewport: viewport, candles: candles),
      child:   const SizedBox.expand(),
    );
  }
}

class _CandlePainter extends CustomPainter {
  final ChartViewport      viewport;
  final List<CryptoCandle> candles;

  _CandlePainter({required this.viewport, required this.candles});

  @override
  void paint(Canvas canvas, Size size) {
    // FIX #6: Selalu save/restore — canvas state tidak bocor ke painter lain
    canvas.save();
    try {
      _doPaint(canvas, size);
    } finally {
      canvas.restore();
    }
  }

  void _doPaint(Canvas canvas, Size size) {
    // FIX #6: Guard kondisi degenerate sebelum apapun digambar
    if (candles.isEmpty) return;
    if (viewport.maxPrice <= viewport.minPrice) return;
    if (size.isEmpty) return;
    final cw = viewport.candleWidth;
    if (cw < 0.5) return; // terlalu zoom out

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final first = viewport.firstVisibleIndex;
    final last  = viewport.lastVisibleIndex;

    final bullPaint = Paint()..color = const Color(0xFF00C896)..style = PaintingStyle.fill;
    final bearPaint = Paint()..color = const Color(0xFFFF4560)..style = PaintingStyle.fill;
    final wickPaint = Paint()..strokeWidth = 1.0;

    final bodyW   = (cw * 0.6).clamp(1.0, 20.0);
    final halfBody = bodyW / 2;

    for (var i = first; i <= last; i++) {
      if (i < 0 || i >= candles.length) continue;
      final c = candles[i];

      // FIX #6: Guard NaN — data rusak tidak crash painter
      if (!c.open.isFinite || !c.close.isFinite ||
          !c.high.isFinite || !c.low.isFinite) continue;

      final isBull = c.close >= c.open;
      final paint  = isBull ? bullPaint : bearPaint;

      final cx    = viewport.indexToX(i);
      final topY  = viewport.priceToY(math.max(c.open, c.close));
      final botY  = viewport.priceToY(math.min(c.open, c.close));
      final highY = viewport.priceToY(c.high);
      final lowY  = viewport.priceToY(c.low);

      // FIX #6: Guard koordinat tidak valid sebelum draw call
      if (!cx.isFinite || !topY.isFinite || !botY.isFinite) continue;

      final bodyH = math.max(botY - topY, 1.0);
      canvas.drawRect(Rect.fromLTWH(cx - halfBody, topY, bodyW, bodyH), paint);

      wickPaint.color = paint.color;
      if (highY.isFinite && lowY.isFinite) {
        canvas.drawLine(Offset(cx, highY), Offset(cx, topY), wickPaint);
        canvas.drawLine(Offset(cx, botY),  Offset(cx, lowY),  wickPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.viewport != viewport || !identical(old.candles, candles);
}

// ===========================================================================
// _CrosshairPainter
// ===========================================================================

class _CrosshairPainter extends CustomPainter {
  final Offset             position;
  final ChartViewport      viewport;
  final List<CryptoCandle> candles;

  _CrosshairPainter({
    required this.position,
    required this.viewport,
    required this.candles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // FIX #6: save/restore di crosshair juga
    canvas.save();
    try {
      _doPaint(canvas, size);
    } finally {
      canvas.restore();
    }
  }

  void _doPaint(Canvas canvas, Size size) {
    if (!position.dx.isFinite || !position.dy.isFinite) return;

    final linePaint = Paint()
      ..color      = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(position.dx, 0), Offset(position.dx, size.height), linePaint);
    canvas.drawLine(Offset(0, position.dy), Offset(size.width, position.dy), linePaint);

    final price    = viewport.yToPrice(position.dy);
    final priceStr = '\$${price.toStringAsFixed(2)}';
    _drawPill(canvas, priceStr, Offset(size.width - 4, position.dy), isRight: true);

    final ci = viewport.xToIndex(position.dx);
    if (ci >= 0 && ci < candles.length) {
      final t  = candles[ci].openTime.toLocal();
      final ts = '${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
      _drawPill(canvas, ts, Offset(position.dx, size.height - 4), isBottom: true);
    }
  }

  void _drawPill(Canvas canvas, String text, Offset anchor,
      {bool isRight = false, bool isBottom = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padX = 8.0, padY = 4.0;
    final w = tp.width + padX * 2;
    final h = tp.height + padY * 2;

    final left = isRight  ? anchor.dx - w
               : isBottom ? anchor.dx - w / 2
               : anchor.dx;
    final top  = isBottom ? anchor.dy - h
               : anchor.dy - h / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(4)),
      Paint()..color = const Color(0xFF1A2332),
    );
    tp.paint(canvas, Offset(left + padX, top + padY));
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) =>
      old.position != position || old.viewport != viewport;
}