import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Base URL
// ─────────────────────────────────────────────────────────────────────────────

const String _baseUrl = 'http://127.0.0.1:8080/api/v1/classifier';

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

class ClassifyRequest {
  final OHLCData ohlc;
  final EngineConfig engine;
  final String filterMode; // "ALL" | "BRIGHT_ONLY"

  const ClassifyRequest({
    required this.ohlc,
    this.engine = const EngineConfig(),
    this.filterMode = 'ALL',
  });

  Map<String, dynamic> toJson() => {
        'ohlc': ohlc.toJson(),
        'engine': engine.toJson(),
        'filter_mode': filterMode,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Response Models
// ─────────────────────────────────────────────────────────────────────────────

class ClassifiedSignal {
  final int barIndex;
  final int direction;
  final String directionStr;
  final String tier;
  final String signalClass;
  final double close;
  final double midBands;
  final double upperBands;
  final double lowerBands;
  final bool isDiscount;
  final bool isPremium;
  final String zoneLabel;
  final String regime;
  final bool trendUp;
  final double confidence;
  final double? bandPosition;
  final bool isBright;
  final bool isDark;
  final bool isLong;
  final bool isShort;

  const ClassifiedSignal({
    required this.barIndex,
    required this.direction,
    required this.directionStr,
    required this.tier,
    required this.signalClass,
    required this.close,
    required this.midBands,
    required this.upperBands,
    required this.lowerBands,
    required this.isDiscount,
    required this.isPremium,
    required this.zoneLabel,
    required this.regime,
    required this.trendUp,
    required this.confidence,
    this.bandPosition,
    required this.isBright,
    required this.isDark,
    required this.isLong,
    required this.isShort,
  });

  factory ClassifiedSignal.fromJson(Map<String, dynamic> json) {
    return ClassifiedSignal(
      barIndex: json['bar_index'] as int,
      direction: json['direction'] as int,
      directionStr: json['direction_str'] as String,
      tier: json['tier'] as String,
      signalClass: json['signal_class'] as String,
      close: (json['close'] as num).toDouble(),
      midBands: (json['mid_bands'] as num).toDouble(),
      upperBands: (json['upper_bands'] as num).toDouble(),
      lowerBands: (json['lower_bands'] as num).toDouble(),
      isDiscount: json['is_discount'] as bool,
      isPremium: json['is_premium'] as bool,
      zoneLabel: json['zone_label'] as String,
      regime: json['regime'] as String,
      trendUp: json['trend_up'] as bool,
      confidence: (json['confidence'] as num).toDouble(),
      bandPosition: json['band_position'] != null
          ? (json['band_position'] as num).toDouble()
          : null,
      isBright: json['is_bright'] as bool,
      isDark: json['is_dark'] as bool,
      isLong: json['is_long'] as bool,
      isShort: json['is_short'] as bool,
    );
  }

  @override
  String toString() =>
      'ClassifiedSignal(bar=$barIndex, $directionStr, tier=$tier, class=$signalClass, conf=${confidence.toStringAsFixed(3)}, zone=$zoneLabel)';
}

class ClassifierSummary {
  final String filterMode;
  final int totalSignals;
  final int brightTotal;
  final int darkTotal;
  final int brightLong;
  final int brightShort;
  final int darkLong;
  final int darkShort;
  final double avgConfBright;
  final double avgConfDark;

  const ClassifierSummary({
    required this.filterMode,
    required this.totalSignals,
    required this.brightTotal,
    required this.darkTotal,
    required this.brightLong,
    required this.brightShort,
    required this.darkLong,
    required this.darkShort,
    required this.avgConfBright,
    required this.avgConfDark,
  });

  factory ClassifierSummary.fromJson(Map<String, dynamic> json) {
    return ClassifierSummary(
      filterMode: json['filter_mode'] as String,
      totalSignals: json['total_signals'] as int,
      brightTotal: json['bright_total'] as int,
      darkTotal: json['dark_total'] as int,
      brightLong: json['bright_long'] as int,
      brightShort: json['bright_short'] as int,
      darkLong: json['dark_long'] as int,
      darkShort: json['dark_short'] as int,
      avgConfBright: (json['avg_conf_bright'] as num).toDouble(),
      avgConfDark: (json['avg_conf_dark'] as num).toDouble(),
    );
  }
}

class ClassifyResponse {
  final List<ClassifiedSignal> signals;
  final ClassifierSummary summary;

  const ClassifyResponse({
    required this.signals,
    required this.summary,
  });

  // ── Convenience filters (client-side, tanpa request tambahan) ─────────────

  List<ClassifiedSignal> get brightSignals =>
      signals.where((s) => s.isBright).toList();
  List<ClassifiedSignal> get darkSignals =>
      signals.where((s) => s.isDark).toList();
  List<ClassifiedSignal> get longSignals =>
      signals.where((s) => s.isLong).toList();
  List<ClassifiedSignal> get shortSignals =>
      signals.where((s) => s.isShort).toList();
  List<ClassifiedSignal> get brightLong =>
      signals.where((s) => s.isBright && s.isLong).toList();
  List<ClassifiedSignal> get brightShort =>
      signals.where((s) => s.isBright && s.isShort).toList();
  List<ClassifiedSignal> get darkLong =>
      signals.where((s) => s.isDark && s.isLong).toList();
  List<ClassifiedSignal> get darkShort =>
      signals.where((s) => s.isDark && s.isShort).toList();

  factory ClassifyResponse.fromJson(Map<String, dynamic> json) {
    return ClassifyResponse(
      signals: (json['signals'] as List)
          .map((e) => ClassifiedSignal.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary:
          ClassifierSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exception
// ─────────────────────────────────────────────────────────────────────────────

class ClassifierException implements Exception {
  final int statusCode;
  final String message;
  const ClassifierException(this.statusCode, this.message);

  @override
  String toString() => 'ClassifierException($statusCode): $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Hook — ClassifierHook
// ─────────────────────────────────────────────────────────────────────────────

class ClassifierHook {
  final http.Client _client;
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  ClassifierHook({http.Client? client}) : _client = client ?? http.Client();

  // ── Internal helpers ───────────────────────────────────────────────────────

  void _checkResponse(http.Response res) {
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      final detail = body['detail'] ?? 'Unknown error';
      throw ClassifierException(res.statusCode, detail.toString());
    }
  }

  Future<http.Response> _post(String path, ClassifyRequest req) {
    return _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
  }

  List<ClassifiedSignal> _parseSignalList(http.Response res) {
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => ClassifiedSignal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── POST /classify ─────────────────────────────────────────────────────────

  /// Full pipeline — semua signals + summary sekaligus.
  Future<ClassifyResponse> classify(ClassifyRequest req) async {
    final res = await _post('/classify', req);
    _checkResponse(res);
    return ClassifyResponse.fromJson(jsonDecode(res.body));
  }

  // ── POST /signals ──────────────────────────────────────────────────────────

  /// Semua signals (BRIGHT + DARK sesuai filter_mode).
  Future<List<ClassifiedSignal>> getSignals(ClassifyRequest req) async {
    final res = await _post('/signals', req);
    _checkResponse(res);
    return _parseSignalList(res);
  }

  // ── POST /signals/bright ───────────────────────────────────────────────────

  /// Hanya BRIGHT tier signals (high probability, aligned dengan LRC zone).
  Future<List<ClassifiedSignal>> getBrightSignals(ClassifyRequest req) async {
    final res = await _post('/signals/bright', req);
    _checkResponse(res);
    return _parseSignalList(res);
  }

  // ── POST /signals/dark ─────────────────────────────────────────────────────

  /// Hanya DARK tier signals (low probability, counter-zone).
  Future<List<ClassifiedSignal>> getDarkSignals(ClassifyRequest req) async {
    final res = await _post('/signals/dark', req);
    _checkResponse(res);
    return _parseSignalList(res);
  }

  // ── POST /signals/long ─────────────────────────────────────────────────────

  /// Semua LONG direction signals (BRIGHT + DARK).
  Future<List<ClassifiedSignal>> getLongSignals(ClassifyRequest req) async {
    final res = await _post('/signals/long', req);
    _checkResponse(res);
    return _parseSignalList(res);
  }

  // ── POST /signals/short ────────────────────────────────────────────────────

  /// Semua SHORT direction signals (BRIGHT + DARK).
  Future<List<ClassifiedSignal>> getShortSignals(ClassifyRequest req) async {
    final res = await _post('/signals/short', req);
    _checkResponse(res);
    return _parseSignalList(res);
  }

  // ── POST /signals/bright-long ──────────────────────────────────────────────

  /// BRIGHT LONG signals — Pine: plotshape(bright_Buy).
  Future<List<ClassifiedSignal>> getBrightLong(ClassifyRequest req) async {
    final res = await _post('/signals/bright-long', req);
    _checkResponse(res);
    return _parseSignalList(res);
  }

  // ── POST /signals/bright-short ─────────────────────────────────────────────

  /// BRIGHT SHORT signals — Pine: plotshape(bright_Sell).
  Future<List<ClassifiedSignal>> getBrightShort(ClassifyRequest req) async {
    final res = await _post('/signals/bright-short', req);
    _checkResponse(res);
    return _parseSignalList(res);
  }

  // ── POST /signals/dark-long ────────────────────────────────────────────────

  /// DARK LONG signals — Pine: plotshape(dark_Buy).
  Future<List<ClassifiedSignal>> getDarkLong(ClassifyRequest req) async {
    final res = await _post('/signals/dark-long', req);
    _checkResponse(res);
    return _parseSignalList(res);
  }

  // ── POST /signals/dark-short ───────────────────────────────────────────────

  /// DARK SHORT signals — Pine: plotshape(dark_Sell).
  Future<List<ClassifiedSignal>> getDarkShort(ClassifyRequest req) async {
    final res = await _post('/signals/dark-short', req);
    _checkResponse(res);
    return _parseSignalList(res);
  }

  // ── POST /summary ──────────────────────────────────────────────────────────

  /// Hanya summary stats — ringan untuk polling dashboard.
  Future<ClassifierSummary> getSummary(ClassifyRequest req) async {
    final res = await _post('/summary', req);
    _checkResponse(res);
    return ClassifierSummary.fromJson(jsonDecode(res.body));
  }

  void dispose() => _client.close();
}

// ─────────────────────────────────────────────────────────────────────────────
// Contoh penggunaan
// ─────────────────────────────────────────────────────────────────────────────
//
// final hook = ClassifierHook();
//
// final req = ClassifyRequest(
//   ohlc: OHLCData(
//     close: [100.1, 100.5, 101.0, ...],
//     high:  [100.8, 101.0, 101.5, ...],
//     low:   [99.5,  99.8,  100.2, ...],
//   ),
//   engine: EngineConfig(sensitivity: 2, atrPeriod: 6),
//   filterMode: 'ALL',
// );
//
// // 1. Full classify — signals + summary sekaligus
// final result = await hook.classify(req);
// print('Total signals   : ${result.summary.totalSignals}');
// print('Bright total    : ${result.summary.brightTotal}');
// print('Dark total      : ${result.summary.darkTotal}');
// print('Avg conf BRIGHT : ${result.summary.avgConfBright}');
//
// // Akses langsung via getter (tanpa request tambahan)
// for (final s in result.brightLong) {
//   print('BRIGHT LONG bar=${s.barIndex} price=${s.close} conf=${s.confidence}');
// }
// for (final s in result.brightShort) {
//   print('BRIGHT SHORT bar=${s.barIndex} price=${s.close} zone=${s.zoneLabel}');
// }
//
// // 2. Hanya bright long — cocok untuk trigger tradeWidget
// final brightLongs = await hook.getBrightLong(req);
// for (final s in brightLongs) {
//   tradeWidget.openLong(s.close, sl: s.lowerBands);
// }
//
// // 3. Hanya summary — ringan untuk dashboard
// final summary = await hook.getSummary(req);
// print('Bright long  : ${summary.brightLong}  (plotshape bright_Buy)');
// print('Bright short : ${summary.brightShort} (plotshape bright_Sell)');
// print('Dark long    : ${summary.darkLong}');
// print('Dark short   : ${summary.darkShort}');
//
// // 4. Filter BRIGHT_ONLY — sinyal high probability saja
// final brightOnlyReq = ClassifyRequest(
//   ohlc: ohlcData,
//   filterMode: 'BRIGHT_ONLY',
// );
// final brightOnly = await hook.classify(brightOnlyReq);
//
// hook.dispose();
// ─────────────────────────────────────────────────────────────────────────────