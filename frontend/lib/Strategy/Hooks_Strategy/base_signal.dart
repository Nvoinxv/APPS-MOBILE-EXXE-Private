// base_signal.dart - FIXED: Connection leak dengan try/finally
import 'dart:convert';
import 'package:http/http.dart' as http;

const String _baseUrl = 'http://127.0.0.1:8080/api/v1/signal';

// ─── Request Models ───────────────────────────────────────────────────────────

class OHLCRequest {
  final List<double> close;
  final List<double> high;
  final List<double> low;
  final List<double>? src;
  final int? sensitivity;
  final int? atrPeriod;
  final int? shortLen;
  final int? longLen;
  final int? lrcWindow;
  final double? lrcDevlen;

  const OHLCRequest({
    required this.close,
    required this.high,
    required this.low,
    this.src,
    this.sensitivity,
    this.atrPeriod,
    this.shortLen,
    this.longLen,
    this.lrcWindow,
    this.lrcDevlen,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'close': close,
      'high': high,
      'low': low,
    };
    if (src != null) map['src'] = src;
    if (sensitivity != null) map['sensitivity'] = sensitivity;
    if (atrPeriod != null) map['atr_period'] = atrPeriod;
    if (shortLen != null) map['short_len'] = shortLen;
    if (longLen != null) map['long_len'] = longLen;
    if (lrcWindow != null) map['lrc_window'] = lrcWindow;
    if (lrcDevlen != null) map['lrc_devlen'] = lrcDevlen;
    return map;
  }
}

class EngineConfigRequest {
  final int? sensitivity;
  final int? atrPeriod;
  final int? shortLen;
  final int? longLen;
  final int? lrcWindow;
  final double? lrcDevlen;

  const EngineConfigRequest({
    this.sensitivity,
    this.atrPeriod,
    this.shortLen,
    this.longLen,
    this.lrcWindow,
    this.lrcDevlen,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (sensitivity != null) map['sensitivity'] = sensitivity;
    if (atrPeriod != null) map['atr_period'] = atrPeriod;
    if (shortLen != null) map['short_len'] = shortLen;
    if (longLen != null) map['long_len'] = longLen;
    if (lrcWindow != null) map['lrc_window'] = lrcWindow;
    if (lrcDevlen != null) map['lrc_devlen'] = lrcDevlen;
    return map;
  }
}

// ─── Response Models ──────────────────────────────────────────────────────────

class SignalBar {
  final int barIndex;
  final double close;
  final double high;
  final double low;
  final double? trailingStop;
  final double? shortKalman;
  final double? longKalman;
  final bool trendUp;
  final String candleColKalman;
  final bool isStrongUp;
  final bool isStrongDown;
  final bool baseBuy;
  final bool baseSell;
  final double? midBands;
  final double? upperBands;
  final double? lowerBands;
  final bool isDiscount;
  final bool isPremium;
  final bool brightBuy;
  final bool brightSell;
  final bool darkBuy;
  final bool darkSell;
  final String signalClass;

  const SignalBar({
    required this.barIndex,
    required this.close,
    required this.high,
    required this.low,
    this.trailingStop,
    this.shortKalman,
    this.longKalman,
    required this.trendUp,
    required this.candleColKalman,
    required this.isStrongUp,
    required this.isStrongDown,
    required this.baseBuy,
    required this.baseSell,
    this.midBands,
    this.upperBands,
    this.lowerBands,
    required this.isDiscount,
    required this.isPremium,
    required this.brightBuy,
    required this.brightSell,
    required this.darkBuy,
    required this.darkSell,
    required this.signalClass,
  });

  factory SignalBar.fromJson(Map<String, dynamic> json) {
    return SignalBar(
      barIndex:        json['bar_index'] as int,
      close:           (json['close'] as num).toDouble(),
      high:            (json['high'] as num).toDouble(),
      low:             (json['low'] as num).toDouble(),
      trailingStop:    json['trailing_stop'] != null ? (json['trailing_stop'] as num).toDouble() : null,
      shortKalman:     json['short_kalman'] != null ? (json['short_kalman'] as num).toDouble() : null,
      longKalman:      json['long_kalman'] != null ? (json['long_kalman'] as num).toDouble() : null,
      trendUp:         json['trend_up'] as bool,
      candleColKalman: json['candle_col_kalman'] as String,
      isStrongUp:      json['is_strong_up'] as bool,
      isStrongDown:    json['is_strong_down'] as bool,
      baseBuy:         json['base_buy'] as bool,
      baseSell:        json['base_sell'] as bool,
      midBands:        json['mid_bands'] != null ? (json['mid_bands'] as num).toDouble() : null,
      upperBands:      json['upper_bands'] != null ? (json['upper_bands'] as num).toDouble() : null,
      lowerBands:      json['lower_bands'] != null ? (json['lower_bands'] as num).toDouble() : null,
      isDiscount:      json['is_discount'] as bool,
      isPremium:       json['is_premium'] as bool,
      brightBuy:       json['bright_buy'] as bool,
      brightSell:      json['bright_sell'] as bool,
      darkBuy:         json['dark_buy'] as bool,
      darkSell:        json['dark_sell'] as bool,
      signalClass:     json['signal_class'] as String,
    );
  }
}

class BrightSignalBar {
  final int barIndex;
  final String direction;
  final double close;
  final double high;
  final double low;
  final double? trailingStop;
  final double? shortKalman;
  final double? longKalman;
  final double? midBands;
  final bool isDiscount;
  final bool isPremium;
  final String signalClass;

  bool get isLong  => direction == 'long';
  bool get isShort => direction == 'short';

  const BrightSignalBar({
    required this.barIndex,
    required this.direction,
    required this.close,
    required this.high,
    required this.low,
    this.trailingStop,
    this.shortKalman,
    this.longKalman,
    this.midBands,
    required this.isDiscount,
    required this.isPremium,
    required this.signalClass,
  });

  factory BrightSignalBar.fromJson(Map<String, dynamic> json) {
    return BrightSignalBar(
      barIndex:    json['bar_index'] as int,
      direction:   json['direction'] as String,
      close:       (json['close'] as num).toDouble(),
      high:        (json['high'] as num).toDouble(),
      low:         (json['low'] as num).toDouble(),
      trailingStop: json['trailing_stop'] != null ? (json['trailing_stop'] as num).toDouble() : null,
      shortKalman:  json['short_kalman'] != null ? (json['short_kalman'] as num).toDouble() : null,
      longKalman:   json['long_kalman'] != null ? (json['long_kalman'] as num).toDouble() : null,
      midBands:     json['mid_bands'] != null ? (json['mid_bands'] as num).toDouble() : null,
      isDiscount:  json['is_discount'] as bool,
      isPremium:   json['is_premium'] as bool,
      signalClass: json['signal_class'] as String,
    );
  }
}

class SignalSummary {
  final int validBars;
  final int atrBuyCount;
  final int atrSellCount;
  final int strongUpBars;
  final int strongDnBars;
  final int baseBuyCount;
  final int baseSellCount;
  final int brightBuyCount;
  final int brightSellCount;
  final int darkBuyCount;
  final int darkSellCount;
  final double? kalmanBuyPassRate;
  final double? kalmanSellPassRate;
  final double? lrcBuyPassRate;
  final double? lrcSellPassRate;
  final double elapsedMs;

  const SignalSummary({
    required this.validBars,
    required this.atrBuyCount,
    required this.atrSellCount,
    required this.strongUpBars,
    required this.strongDnBars,
    required this.baseBuyCount,
    required this.baseSellCount,
    required this.brightBuyCount,
    required this.brightSellCount,
    required this.darkBuyCount,
    required this.darkSellCount,
    this.kalmanBuyPassRate,
    this.kalmanSellPassRate,
    this.lrcBuyPassRate,
    this.lrcSellPassRate,
    required this.elapsedMs,
  });

  factory SignalSummary.fromJson(Map<String, dynamic> json) {
    return SignalSummary(
      validBars:          json['valid_bars'] as int,
      atrBuyCount:        json['atr_buy_count'] as int,
      atrSellCount:       json['atr_sell_count'] as int,
      strongUpBars:       json['strong_up_bars'] as int,
      strongDnBars:       json['strong_dn_bars'] as int,
      baseBuyCount:       json['base_buy_count'] as int,
      baseSellCount:      json['base_sell_count'] as int,
      brightBuyCount:     json['bright_buy_count'] as int,
      brightSellCount:    json['bright_sell_count'] as int,
      darkBuyCount:       json['dark_buy_count'] as int,
      darkSellCount:      json['dark_sell_count'] as int,
      kalmanBuyPassRate:  json['kalman_buy_pass_rate'] != null ? (json['kalman_buy_pass_rate'] as num).toDouble() : null,
      kalmanSellPassRate: json['kalman_sell_pass_rate'] != null ? (json['kalman_sell_pass_rate'] as num).toDouble() : null,
      lrcBuyPassRate:     json['lrc_buy_pass_rate'] != null ? (json['lrc_buy_pass_rate'] as num).toDouble() : null,
      lrcSellPassRate:    json['lrc_sell_pass_rate'] != null ? (json['lrc_sell_pass_rate'] as num).toDouble() : null,
      elapsedMs:          (json['elapsed_ms'] as num).toDouble(),
    );
  }
}

class FullRunResponse {
  final int totalBars;
  final List<SignalBar> signalBars;
  final SignalSummary summary;

  const FullRunResponse({
    required this.totalBars,
    required this.signalBars,
    required this.summary,
  });

  factory FullRunResponse.fromJson(Map<String, dynamic> json) {
    return FullRunResponse(
      totalBars:  json['total_bars'] as int,
      signalBars: (json['signal_bars'] as List)
          .map((e) => SignalBar.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: SignalSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }
}

class LatestBarResponse {
  final int barIndex;
  final double close;
  final double? trailingStop;
  final double? shortKalman;
  final double? longKalman;
  final double? midBands;
  final String candleColKalman;
  final bool isStrongUp;
  final bool isStrongDown;
  final bool isDiscount;
  final bool isPremium;
  final bool brightBuy;
  final bool brightSell;
  final bool darkBuy;
  final bool darkSell;
  final String signalClass;
  final double elapsedMs;

  const LatestBarResponse({
    required this.barIndex,
    required this.close,
    this.trailingStop,
    this.shortKalman,
    this.longKalman,
    this.midBands,
    required this.candleColKalman,
    required this.isStrongUp,
    required this.isStrongDown,
    required this.isDiscount,
    required this.isPremium,
    required this.brightBuy,
    required this.brightSell,
    required this.darkBuy,
    required this.darkSell,
    required this.signalClass,
    required this.elapsedMs,
  });

  factory LatestBarResponse.fromJson(Map<String, dynamic> json) {
    return LatestBarResponse(
      barIndex:        json['bar_index'] as int,
      close:           (json['close'] as num).toDouble(),
      trailingStop:    json['trailing_stop'] != null ? (json['trailing_stop'] as num).toDouble() : null,
      shortKalman:     json['short_kalman'] != null ? (json['short_kalman'] as num).toDouble() : null,
      longKalman:      json['long_kalman'] != null ? (json['long_kalman'] as num).toDouble() : null,
      midBands:        json['mid_bands'] != null ? (json['mid_bands'] as num).toDouble() : null,
      candleColKalman: json['candle_col_kalman'] as String,
      isStrongUp:      json['is_strong_up'] as bool,
      isStrongDown:    json['is_strong_down'] as bool,
      isDiscount:      json['is_discount'] as bool,
      isPremium:       json['is_premium'] as bool,
      brightBuy:       json['bright_buy'] as bool,
      brightSell:      json['bright_sell'] as bool,
      darkBuy:         json['dark_buy'] as bool,
      darkSell:        json['dark_sell'] as bool,
      signalClass:     json['signal_class'] as String,
      elapsedMs:       (json['elapsed_ms'] as num).toDouble(),
    );
  }
}

class EngineConfigResponse {
  final int sensitivity;
  final int atrPeriod;
  final int shortLen;
  final int longLen;
  final int lrcWindow;
  final double lrcDevlen;
  final String message;

  const EngineConfigResponse({
    required this.sensitivity,
    required this.atrPeriod,
    required this.shortLen,
    required this.longLen,
    required this.lrcWindow,
    required this.lrcDevlen,
    required this.message,
  });

  factory EngineConfigResponse.fromJson(Map<String, dynamic> json) {
    return EngineConfigResponse(
      sensitivity: json['sensitivity'] as int,
      atrPeriod:   json['atr_period'] as int,
      shortLen:    json['short_len'] as int,
      longLen:     json['long_len'] as int,
      lrcWindow:   json['lrc_window'] as int,
      lrcDevlen:   (json['lrc_devlen'] as num).toDouble(),
      message:     json['message'] as String,
    );
  }
}

// ─── Exception ────────────────────────────────────────────────────────────────

class BaseSignalException implements Exception {
  final int statusCode;
  final String message;
  const BaseSignalException(this.statusCode, this.message);

  @override
  String toString() => 'BaseSignalException($statusCode): $message';
}

// ─── Hook ─────────────────────────────────────────────────────────────────────

class BaseSignalHook {
  // ✅ FIXED: Satu shared client — reuse koneksi, tidak bocor
  // Jangan buat http.Client() baru di setiap method!
  static final http.Client _sharedClient = http.Client();

  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── Internal helpers ───────────────────────────────────────────────────────

  void _checkResponse(http.Response res) {
    if (res.statusCode != 200) {
      String detail;
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        detail = (body['detail'] ?? body['message'] ?? 'Unknown error').toString();
      } catch (_) {
        detail = res.body.isNotEmpty ? res.body : 'Server error ${res.statusCode}';
      }
      throw BaseSignalException(res.statusCode, detail);
    }
  }

  // ✅ FIXED: try/finally di semua method — koneksi PASTI ditutup
  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    // Pakai _sharedClient, bukan client baru
    // try/finally tidak perlu di sini karena _sharedClient di-manage sendiri
    return _sharedClient.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
  }

  // ── GET /health ────────────────────────────────────────────────────────────

  Future<EngineConfigResponse> healthCheck() async {
    // ✅ try/finally: response selalu di-dispose meski error
    late http.Response res;
    try {
      res = await _sharedClient.get(
        Uri.parse('$_baseUrl/health'),
        headers: _headers,
      );
      _checkResponse(res);
      return EngineConfigResponse.fromJson(jsonDecode(res.body));
    } catch (e) {
      rethrow; // bubble up ke caller
    }
  }

  // ── POST /config ───────────────────────────────────────────────────────────

  Future<EngineConfigResponse> updateConfig(EngineConfigRequest config) async {
    try {
      final res = await _post('/config', config.toJson());
      _checkResponse(res);
      return EngineConfigResponse.fromJson(jsonDecode(res.body));
    } catch (e) {
      rethrow;
    }
  }

  // ── POST /run ──────────────────────────────────────────────────────────────

  Future<FullRunResponse> run(OHLCRequest ohlc, {bool allBars = false}) async {
    try {
      final res = await _sharedClient.post(
        Uri.parse('$_baseUrl/run?all_bars=$allBars'),
        headers: _headers,
        body: jsonEncode(ohlc.toJson()),
      );
      _checkResponse(res);
      return FullRunResponse.fromJson(jsonDecode(res.body));
    } catch (e) {
      rethrow;
    }
  }

  // ── POST /run/bright ───────────────────────────────────────────────────────

  Future<List<BrightSignalBar>> runBright(OHLCRequest ohlc) async {
    try {
      final res = await _post('/run/bright', ohlc.toJson());
      _checkResponse(res);
      final list = jsonDecode(res.body) as List;
      return list
          .map((e) => BrightSignalBar.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // ── POST /run/summary ──────────────────────────────────────────────────────

  Future<SignalSummary> runSummary(OHLCRequest ohlc) async {
    try {
      final res = await _post('/run/summary', ohlc.toJson());
      _checkResponse(res);
      return SignalSummary.fromJson(jsonDecode(res.body));
    } catch (e) {
      rethrow;
    }
  }

  // ── POST /run/latest ───────────────────────────────────────────────────────

  Future<LatestBarResponse> runLatest(OHLCRequest ohlc) async {
    try {
      final res = await _post('/run/latest', ohlc.toJson());
      _checkResponse(res);
      return LatestBarResponse.fromJson(jsonDecode(res.body));
    } catch (e) {
      rethrow;
    }
  }

  // ✅ dispose() sekarang close shared client — panggil ini SEKALI saat app tutup
  static void disposeSharedClient() => _sharedClient.close();

  // Backward compat
  void dispose() => disposeSharedClient();
}