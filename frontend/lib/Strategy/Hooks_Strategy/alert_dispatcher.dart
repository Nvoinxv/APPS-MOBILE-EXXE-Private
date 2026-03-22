import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Base URL
// ─────────────────────────────────────────────────────────────────────────────

const String _baseUrl = 'http://127.0.0.1:8080/api/v1/dispatcher';

// ─────────────────────────────────────────────────────────────────────────────
// Request Models
// ─────────────────────────────────────────────────────────────────────────────

class OHLCData {
  final List<double> close;
  final List<double> high;
  final List<double> low;
  final List<double>? src;

  const OHLCData({
    required this.close,
    required this.high,
    required this.low,
    this.src,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'close': close,
      'high': high,
      'low': low,
    };
    if (src != null) map['src'] = src;
    return map;
  }
}

class EngineConfig {
  final int sensitivity;
  final int atrPeriod;
  final int shortLen;
  final int longLen;
  final int lrcWindow;
  final double lrcDevlen;

  const EngineConfig({
    this.sensitivity = 2,
    this.atrPeriod = 6,
    this.shortLen = 50,
    this.longLen = 150,
    this.lrcWindow = 50,
    this.lrcDevlen = 3.0,
  });

  Map<String, dynamic> toJson() => {
        'sensitivity': sensitivity,
        'atr_period': atrPeriod,
        'short_len': shortLen,
        'long_len': longLen,
        'lrc_window': lrcWindow,
        'lrc_devlen': lrcDevlen,
      };
}

class DispatchRequest {
  final OHLCData ohlc;
  final EngineConfig engine;
  final String filterMode; // "ALL" | "BRIGHT_ONLY"
  final int slLookback;

  const DispatchRequest({
    required this.ohlc,
    this.engine = const EngineConfig(),
    this.filterMode = 'ALL',
    this.slLookback = 15,
  });

  Map<String, dynamic> toJson() => {
        'ohlc': ohlc.toJson(),
        'engine': engine.toJson(),
        'filter_mode': filterMode,
        'sl_lookback': slLookback,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Response Models
// ─────────────────────────────────────────────────────────────────────────────

class AlertEvent {
  final int barIndex;
  final String alertType;
  final int direction;
  final String directionStr;
  final String tier;
  final String signalClass;
  final double close;
  final double confidence;
  final double? bandPos;
  final bool isBright;
  final String message;

  bool get isLong => directionStr == 'LONG';
  bool get isShort => directionStr == 'SHORT';
  bool get isDark => !isBright;

  const AlertEvent({
    required this.barIndex,
    required this.alertType,
    required this.direction,
    required this.directionStr,
    required this.tier,
    required this.signalClass,
    required this.close,
    required this.confidence,
    this.bandPos,
    required this.isBright,
    required this.message,
  });

  factory AlertEvent.fromJson(Map<String, dynamic> json) {
    return AlertEvent(
      barIndex: json['bar_index'] as int,
      alertType: json['alert_type'] as String,
      direction: json['direction'] as int,
      directionStr: json['direction_str'] as String,
      tier: json['tier'] as String,
      signalClass: json['signal_class'] as String,
      close: (json['close'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      bandPos: json['band_pos'] != null
          ? (json['band_pos'] as num).toDouble()
          : null,
      isBright: json['is_bright'] as bool,
      message: json['message'] as String,
    );
  }

  @override
  String toString() =>
      'AlertEvent(bar=$barIndex, $directionStr, tier=$tier, price=$close, conf=$confidence)';
}

class TradeSetup {
  final int entryBar;
  final int direction;
  final String directionStr;
  final String tier;
  final double entryPrice;
  final double slPrice;
  final double risk;
  final double tp1Price;
  final double tp2Price;
  final double tp3Price;
  final double tp4Price;
  final double tp5Price;
  final bool tp1Hit;
  final bool tp2Hit;
  final bool tp3Hit;
  final bool tp4Hit;
  final bool isActive;
  final String? outcome; // "MAX_TP" | "SL" | "OPEN" | null
  final int? exitBar;
  final double? exitPrice;
  final double highestRr;
  final bool isWinner;
  final bool smartSlShown;

  bool get isLong => directionStr == 'LONG';
  bool get isShort => directionStr == 'SHORT';
  bool get isBright => tier == 'bright';
  bool get isMaxTp => outcome == 'MAX_TP';
  bool get isSl => outcome == 'SL';
  bool get isOpen => outcome == 'OPEN' || isActive;

  const TradeSetup({
    required this.entryBar,
    required this.direction,
    required this.directionStr,
    required this.tier,
    required this.entryPrice,
    required this.slPrice,
    required this.risk,
    required this.tp1Price,
    required this.tp2Price,
    required this.tp3Price,
    required this.tp4Price,
    required this.tp5Price,
    required this.tp1Hit,
    required this.tp2Hit,
    required this.tp3Hit,
    required this.tp4Hit,
    required this.isActive,
    this.outcome,
    this.exitBar,
    this.exitPrice,
    required this.highestRr,
    required this.isWinner,
    required this.smartSlShown,
  });

  factory TradeSetup.fromJson(Map<String, dynamic> json) {
    return TradeSetup(
      entryBar: json['entry_bar'] as int,
      direction: json['direction'] as int,
      directionStr: json['direction_str'] as String,
      tier: json['tier'] as String,
      entryPrice: (json['entry_price'] as num).toDouble(),
      slPrice: (json['sl_price'] as num).toDouble(),
      risk: (json['risk'] as num).toDouble(),
      tp1Price: (json['tp1_price'] as num).toDouble(),
      tp2Price: (json['tp2_price'] as num).toDouble(),
      tp3Price: (json['tp3_price'] as num).toDouble(),
      tp4Price: (json['tp4_price'] as num).toDouble(),
      tp5Price: (json['tp5_price'] as num).toDouble(),
      tp1Hit: json['tp1_hit'] as bool,
      tp2Hit: json['tp2_hit'] as bool,
      tp3Hit: json['tp3_hit'] as bool,
      tp4Hit: json['tp4_hit'] as bool,
      isActive: json['is_active'] as bool,
      outcome: json['outcome'] as String?,
      exitBar: json['exit_bar'] as int?,
      exitPrice: json['exit_price'] != null
          ? (json['exit_price'] as num).toDouble()
          : null,
      highestRr: (json['highest_rr'] as num).toDouble(),
      isWinner: json['is_winner'] as bool,
      smartSlShown: json['smart_sl_shown'] as bool,
    );
  }

  @override
  String toString() =>
      'TradeSetup(bar=$entryBar, $directionStr, entry=$entryPrice, sl=$slPrice, outcome=$outcome, rr=${highestRr}R)';
}

class PerformanceSummary {
  final int totalAlerts;
  final int brightAlerts;
  final int darkAlerts;
  final int totalTrades;
  final int closedTrades;
  final int openTrades;
  final int winners;
  final int losers;
  final double winRatePct;
  final double avgWinnerRr;
  final double expectancy;
  final int brightTrades;
  final int darkTrades;
  final double brightWinRate;
  final double darkWinRate;

  const PerformanceSummary({
    required this.totalAlerts,
    required this.brightAlerts,
    required this.darkAlerts,
    required this.totalTrades,
    required this.closedTrades,
    required this.openTrades,
    required this.winners,
    required this.losers,
    required this.winRatePct,
    required this.avgWinnerRr,
    required this.expectancy,
    required this.brightTrades,
    required this.darkTrades,
    required this.brightWinRate,
    required this.darkWinRate,
  });

  factory PerformanceSummary.fromJson(Map<String, dynamic> json) {
    return PerformanceSummary(
      totalAlerts: json['total_alerts'] as int,
      brightAlerts: json['bright_alerts'] as int,
      darkAlerts: json['dark_alerts'] as int,
      totalTrades: json['total_trades'] as int,
      closedTrades: json['closed_trades'] as int,
      openTrades: json['open_trades'] as int,
      winners: json['winners'] as int,
      losers: json['losers'] as int,
      winRatePct: (json['win_rate_pct'] as num).toDouble(),
      avgWinnerRr: (json['avg_winner_rr'] as num).toDouble(),
      expectancy: (json['expectancy'] as num).toDouble(),
      brightTrades: json['bright_trades'] as int,
      darkTrades: json['dark_trades'] as int,
      brightWinRate: (json['bright_win_rate'] as num).toDouble(),
      darkWinRate: (json['dark_win_rate'] as num).toDouble(),
    );
  }
}

class DispatchResponse {
  final List<AlertEvent> alerts;
  final List<TradeSetup> trades;
  final PerformanceSummary summary;

  const DispatchResponse({
    required this.alerts,
    required this.trades,
    required this.summary,
  });

  // ── Convenience filters ───────────────────────────────────────────────────

  List<AlertEvent> get brightAlerts => alerts.where((a) => a.isBright).toList();
  List<AlertEvent> get darkAlerts => alerts.where((a) => a.isDark).toList();
  List<AlertEvent> get longAlerts => alerts.where((a) => a.isLong).toList();
  List<AlertEvent> get shortAlerts => alerts.where((a) => a.isShort).toList();

  List<TradeSetup> get closedTrades => trades.where((t) => !t.isActive).toList();
  List<TradeSetup> get openTrades => trades.where((t) => t.isActive).toList();
  List<TradeSetup> get winners => trades.where((t) => t.isWinner).toList();
  List<TradeSetup> get losers =>
      trades.where((t) => !t.isWinner && !t.isActive).toList();
  List<TradeSetup> get brightTrades => trades.where((t) => t.isBright).toList();
  List<TradeSetup> get darkTrades => trades.where((t) => !t.isBright).toList();

  factory DispatchResponse.fromJson(Map<String, dynamic> json) {
    return DispatchResponse(
      alerts: (json['alerts'] as List)
          .map((e) => AlertEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      trades: (json['trades'] as List)
          .map((e) => TradeSetup.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary:
          PerformanceSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exception
// ─────────────────────────────────────────────────────────────────────────────

class AlertDispatcherException implements Exception {
  final int statusCode;
  final String message;
  const AlertDispatcherException(this.statusCode, this.message);

  @override
  String toString() => 'AlertDispatcherException($statusCode): $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Hook — AlertDispatcherHook
// ─────────────────────────────────────────────────────────────────────────────

class AlertDispatcherHook {
  final http.Client _client;
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  AlertDispatcherHook({http.Client? client})
      : _client = client ?? http.Client();

  // ── Internal helpers ───────────────────────────────────────────────────────

  void _checkResponse(http.Response res) {
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      final detail = body['detail'] ?? 'Unknown error';
      throw AlertDispatcherException(res.statusCode, detail.toString());
    }
  }

  Future<http.Response> _post(String path, DispatchRequest req) {
    return _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
  }

  // ── POST /dispatch ─────────────────────────────────────────────────────────

  /// Full pipeline — alerts + trades + performance summary sekaligus.
  Future<DispatchResponse> dispatch(DispatchRequest req) async {
    final res = await _post('/dispatch', req);
    _checkResponse(res);
    return DispatchResponse.fromJson(jsonDecode(res.body));
  }

  // ── POST /alerts ───────────────────────────────────────────────────────────

  /// Semua alert events (BRIGHT + DARK sesuai filter_mode).
  Future<List<AlertEvent>> getAlerts(DispatchRequest req) async {
    final res = await _post('/alerts', req);
    _checkResponse(res);
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => AlertEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── POST /alerts/bright ────────────────────────────────────────────────────

  /// Hanya BRIGHT alerts (high probability).
  Future<List<AlertEvent>> getBrightAlerts(DispatchRequest req) async {
    final res = await _post('/alerts/bright', req);
    _checkResponse(res);
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => AlertEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── POST /alerts/dark ─────────────────────────────────────────────────────

  /// Hanya DARK alerts (low probability, counter-zone).
  Future<List<AlertEvent>> getDarkAlerts(DispatchRequest req) async {
    final res = await _post('/alerts/dark', req);
    _checkResponse(res);
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => AlertEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── POST /trades ───────────────────────────────────────────────────────────

  /// Semua trade setups dari Historical Execution Simulator.
  Future<List<TradeSetup>> getTrades(DispatchRequest req) async {
    final res = await _post('/trades', req);
    _checkResponse(res);
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => TradeSetup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── POST /trades/closed ────────────────────────────────────────────────────

  /// Hanya trades yang sudah tutup (SL atau MAX_TP).
  Future<List<TradeSetup>> getClosedTrades(DispatchRequest req) async {
    final res = await _post('/trades/closed', req);
    _checkResponse(res);
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => TradeSetup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── POST /trades/open ──────────────────────────────────────────────────────

  /// Trades yang masih aktif di akhir data (OPEN).
  Future<List<TradeSetup>> getOpenTrades(DispatchRequest req) async {
    final res = await _post('/trades/open', req);
    _checkResponse(res);
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => TradeSetup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── POST /trades/winners ───────────────────────────────────────────────────

  /// Hanya trades yang hit TP1 atau lebih.
  Future<List<TradeSetup>> getWinners(DispatchRequest req) async {
    final res = await _post('/trades/winners', req);
    _checkResponse(res);
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => TradeSetup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── POST /trades/losers ────────────────────────────────────────────────────

  /// Hanya trades yang kena SL sebelum hit TP1.
  Future<List<TradeSetup>> getLosers(DispatchRequest req) async {
    final res = await _post('/trades/losers', req);
    _checkResponse(res);
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => TradeSetup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── POST /summary ──────────────────────────────────────────────────────────

  /// Hanya performance summary — ringan untuk polling dashboard.
  Future<PerformanceSummary> getSummary(DispatchRequest req) async {
    final res = await _post('/summary', req);
    _checkResponse(res);
    return PerformanceSummary.fromJson(jsonDecode(res.body));
  }

  void dispose() => _client.close();
}

// ─────────────────────────────────────────────────────────────────────────────
// Contoh penggunaan
// ─────────────────────────────────────────────────────────────────────────────
//
// final hook = AlertDispatcherHook();
//
// final req = DispatchRequest(
//   ohlc: OHLCData(
//     close: [100.1, 100.5, 101.0, ...],
//     high:  [100.8, 101.0, 101.5, ...],
//     low:   [99.5,  99.8,  100.2, ...],
//   ),
//   engine: EngineConfig(sensitivity: 2, atrPeriod: 6),
//   filterMode: 'ALL',
//   slLookback: 15,
// );
//
// // 1. Full dispatch — dapat semua sekaligus
// final result = await hook.dispatch(req);
// print('Win rate  : ${result.summary.winRatePct}%');
// print('Expectancy: ${result.summary.expectancy}R');
//
// for (final alert in result.brightAlerts) {
//   print('BRIGHT ${alert.directionStr} bar=${alert.barIndex} price=${alert.close}');
// }
// for (final trade in result.winners) {
//   print('WINNER ${trade.directionStr} entry=${trade.entryPrice} rr=${trade.highestRr}R');
// }
//
// // 2. Hanya bright alerts
// final brights = await hook.getBrightAlerts(req);
// for (final a in brights) {
//   if (a.isLong)  tradeWidget.openLong(a.close);
//   if (a.isShort) tradeWidget.openShort(a.close);
// }
//
// // 3. Dashboard summary saja
// final summary = await hook.getSummary(req);
// print('Total trades    : ${summary.totalTrades}');
// print('Bright win rate : ${summary.brightWinRate}%');
// print('Dark win rate   : ${summary.darkWinRate}%');
//
// // 4. Hanya open trades (posisi aktif)
// final opens = await hook.getOpenTrades(req);
// for (final t in opens) {
//   print('OPEN ${t.directionStr} entry=${t.entryPrice} tp1=${t.tp1Price} sl=${t.slPrice}');
// }
//
// hook.dispose();
// ─────────────────────────────────────────────────────────────────────────────