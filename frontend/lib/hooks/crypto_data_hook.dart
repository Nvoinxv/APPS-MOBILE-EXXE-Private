import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ===========================================================================
// CryptoDataHook — Production-ready, scale-safe
//
// Perubahan utama vs versi lama:
//   1. Parallel fetch (Future.wait) — bukan serial dengan delay 100ms
//   2. In-memory cache dengan TTL — hindari re-fetch data yang masih valid
//   3. Request deduplication — jika fetch ticker+interval sama sedang berjalan,
//      tunggu hasilnya, jangan spawn request baru
//   4. Exponential backoff pada error — jangan spam server saat error
//   5. Hapus semua print() — ganti debugPrint yang auto-stripped di release build
//   6. Candle diffing — hanya trigger UI update jika data benar-benar berubah
//   7. Configurable limit — turunkan default dari 500 ke 200 untuk hemat bandwidth
// ===========================================================================

// ---------------------------------------------------------------------------
// Cache entry
// ---------------------------------------------------------------------------

class _CacheEntry {
  final List<CryptoCandle> candles;
  final DateTime fetchedAt;

  const _CacheEntry({required this.candles, required this.fetchedAt});

  bool isExpired(Duration ttl) =>
      DateTime.now().toUtc().difference(fetchedAt) > ttl;
}

// ---------------------------------------------------------------------------
// CryptoDataHook
// ---------------------------------------------------------------------------

class CryptoDataHook {
  final List<String> tickers;
  final List<String> intervals;
  final int autoUpdateInterval;

  // FIX 7: Turunkan limit default — 500 candles banyak, 200 cukup untuk chart
  final int candleLimit;

  // Structure: ticker -> interval -> candles
  Map<String, Map<String, List<CryptoCandle>>> data = {};
  Map<String, Map<String, DateTime>> lastCandleTime = {};
  Map<String, Map<String, bool>> isReady = {};
  int fetchCount = 0;

  // FIX 2: In-memory cache — key: "BTCUSDT_15m"
  final Map<String, _CacheEntry> _cache = {};

  // FIX 3: Deduplication — key: "BTCUSDT_15m" → ongoing Future
  final Map<String, Future<List<CryptoCandle>?>> _inflightRequests = {};

  // FIX 4: Backoff state per ticker-interval
  final Map<String, int> _errorCount = {};
  static const int _maxBackoffSeconds = 300; // 5 menit max

  Timer? _updateTimer;

  // Callbacks
  Function(String ticker, String interval, List<CryptoCandle> candles)? onDataUpdate;
  Function(String ticker, String interval, String error)? onError;
  Function()? onAllDataReady;

  CryptoDataHook({
    required this.tickers,
    List<String>? intervals,
    this.autoUpdateInterval = 60,
    this.candleLimit = 200, // FIX 7: lebih hemat dari 500
  }) : intervals = intervals ?? ['15m'] {
    for (var ticker in tickers) {
      data[ticker] = {};
      lastCandleTime[ticker] = {};
      isReady[ticker] = {};
      for (var interval in this.intervals) {
        isReady[ticker]![interval] = false;
      }
    }
  }

  String _getSymbol(String ticker) =>
      ticker.replaceAll('-', '').toUpperCase();

  String _cacheKey(String ticker, String interval) =>
      '${_getSymbol(ticker)}_$interval';

  Duration _cacheTtl(String interval) {
    // Cache lebih lama untuk interval besar — tidak perlu re-fetch 1d tiap menit
    final minutes = _getIntervalMinutes(interval);
    if (minutes >= 1440) return const Duration(minutes: 30); // 1d ke atas
    if (minutes >= 240)  return const Duration(minutes: 10); // 4h
    if (minutes >= 60)   return const Duration(minutes: 5);  // 1h
    if (minutes >= 15)   return const Duration(minutes: 2);  // 15m
    return const Duration(seconds: 30);                       // < 15m
  }

  // ---------------------------------------------------------------------------
  // Core fetch — dengan caching + deduplication
  // ---------------------------------------------------------------------------

  Future<List<CryptoCandle>?> fetch(String ticker, String interval) async {
    final key = _cacheKey(ticker, interval);

    // FIX 2: Kembalikan cache jika masih valid
    final cached = _cache[key];
    if (cached != null && !cached.isExpired(_cacheTtl(interval))) {
      return cached.candles;
    }

    // FIX 3: Jika request yang sama sudah berjalan, tunggu hasilnya
    if (_inflightRequests.containsKey(key)) {
      return _inflightRequests[key];
    }

    // Daftarkan future sebelum await — ini kunci deduplication
    final future = _doFetch(ticker, interval, key);
    _inflightRequests[key] = future;

    try {
      return await future;
    } finally {
      _inflightRequests.remove(key);
    }
  }

  Future<List<CryptoCandle>?> _doFetch(
    String ticker,
    String interval,
    String key,
  ) async {
    // FIX 4: Cek backoff — jangan fetch jika dalam penalti error
    final errCount = _errorCount[key] ?? 0;
    if (errCount > 0) {
      final backoffSec = (_backoffSeconds(errCount)).clamp(0, _maxBackoffSeconds);
      final lastFetch = _cache[key]?.fetchedAt;
      if (lastFetch != null) {
        final elapsed = DateTime.now().toUtc().difference(lastFetch).inSeconds;
        if (elapsed < backoffSec) {
          // Masih dalam penalti, kembalikan data lama jika ada
          return _cache[key]?.candles;
        }
      }
    }

    try {
      fetchCount++;
      final symbol = _getSymbol(ticker);

      final uri = Uri.parse('https://www.tokocrypto.site/api/v3/klines').replace(
        queryParameters: {
          'symbol':   symbol,
          'interval': interval,
          'limit':    candleLimit.toString(),
        },
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15), // FIX: turunkan timeout dari 30s ke 15s
        onTimeout: () => throw TimeoutException('Timeout: $symbol $interval'),
      );

      if (response.statusCode != 200) {
        _errorCount[key] = errCount + 1;
        onError?.call(ticker, interval, 'HTTP ${response.statusCode}');
        return _cache[key]?.candles; // kembalikan stale cache jika ada
      }

      // Reset error count jika berhasil
      _errorCount[key] = 0;

      final List<dynamic> raw = json.decode(response.body);
      final candles = raw.map((item) => CryptoCandle.fromList(item)).toList();

      if (candles.isEmpty) return null;

      // FIX 6: Candle diffing — hanya update jika data benar-benar berubah
      final existingLast = _cache[key]?.candles.lastOrNull;
      final newLast      = candles.lastOrNull;
      final hasNewData   = existingLast == null ||
          newLast?.openTime != existingLast.openTime ||
          newLast?.close    != existingLast.close;

      // Simpan ke cache
      _cache[key] = _CacheEntry(
        candles:   candles,
        fetchedAt: DateTime.now().toUtc(),
      );

      if (!data.containsKey(ticker)) data[ticker] = {};
      data[ticker]![interval] = candles;

      if (!isReady.containsKey(ticker)) isReady[ticker] = {};
      isReady[ticker]![interval] = true;

      _logNewCandle(ticker, interval, candles, key);
      _checkAllReady();

      // FIX 6: Hanya panggil onDataUpdate jika ada perubahan nyata
      if (hasNewData) {
        onDataUpdate?.call(ticker, interval, candles);
      }

      return candles;

    } on TimeoutException {
      _errorCount[key] = errCount + 1;
      onError?.call(ticker, interval, 'Timeout');
      return _cache[key]?.candles;
    } catch (e) {
      _errorCount[key] = errCount + 1;
      onError?.call(ticker, interval, e.toString());
      return _cache[key]?.candles;
    }
  }

  int _backoffSeconds(int errorCount) {
    // Exponential: 5s, 10s, 20s, 40s, 80s, 160s, 300s (max)
    return (5 * (1 << (errorCount - 1))).clamp(5, _maxBackoffSeconds);
  }

  // FIX 5: Ganti print() dengan debugPrint — di-strip otomatis di release build
  void _logNewCandle(
    String ticker,
    String interval,
    List<CryptoCandle> candles,
    String key,
  ) {
    if (candles.length < 2) return;

    final lastClosed  = candles[candles.length - 2];
    final prevLast    = lastCandleTime[ticker]?[interval];

    if (!lastCandleTime.containsKey(ticker)) lastCandleTime[ticker] = {};

    if (prevLast == null) {
      debugPrint('${_getSymbol(ticker)} $interval ready');
    } else if (lastClosed.openTime.isAfter(prevLast)) {
      debugPrint('${_getSymbol(ticker)} $interval new candle');
    }

    lastCandleTime[ticker]![interval] = lastClosed.openTime;
  }

  void _checkAllReady() {
    for (var ticker in tickers) {
      for (var interval in intervals) {
        if (isReady[ticker]?[interval] != true) return;
      }
    }
    onAllDataReady?.call();
  }

  // ---------------------------------------------------------------------------
  // FIX 1: Parallel fetch — ganti loop serial + delay 100ms
  // ---------------------------------------------------------------------------

  Future<void> _fetchAll() async {
    // Semua kombinasi ticker-interval di-fetch secara parallel
    // Tapi batasi concurrency agar tidak banjir server sekaligus
    const maxConcurrent = 5;
    final pairs = <(String, String)>[];
    for (var ticker in tickers) {
      for (var interval in intervals) {
        pairs.add((ticker, interval));
      }
    }

    // Chunked parallel — fetch maxConcurrent sekaligus, lalu batch berikutnya
    for (var i = 0; i < pairs.length; i += maxConcurrent) {
      final chunk = pairs.skip(i).take(maxConcurrent);
      await Future.wait(
        chunk.map((p) => fetch(p.$1, p.$2)),
        eagerError: false, // jangan hentikan chunk jika satu gagal
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Auto-update strategies
  // ---------------------------------------------------------------------------

  void startAutoUpdate() {
    debugPrint('Auto-update started: ${tickers.length}t x ${intervals.length}i');

    // Initial fetch
    _fetchAll();

    _updateTimer = Timer.periodic(
      Duration(seconds: autoUpdateInterval),
      (_) => _fetchAll(),
    );
  }

  void startAdaptiveUpdate() {
    debugPrint('Adaptive update started');

    _fetchAll();
    _scheduleAdaptive();
  }

  void _scheduleAdaptive() {
    final now             = DateTime.now().toUtc();
    final shortestMinutes = intervals
        .map(_getIntervalMinutes)
        .reduce((a, b) => a < b ? a : b);

    final currentMinute  = now.minute;
    final expectedMinute = (currentMinute ~/ shortestMinutes) * shortestMinutes;
    var nextMinute       = expectedMinute + shortestMinutes;
    if (nextMinute >= 60) nextMinute -= 60;

    final minutesToClose = nextMinute > currentMinute
        ? nextMinute - currentMinute
        : (60 - currentMinute) + nextMinute;

    // Agresif hanya 2 menit sebelum candle close
    final fetchInterval = minutesToClose <= 2 ? 5 : autoUpdateInterval;

    _updateTimer = Timer(Duration(seconds: fetchInterval), () async {
      await _fetchAll();
      _scheduleAdaptive();
    });
  }

  void stop() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Accessors (backward-compatible)
  // ---------------------------------------------------------------------------

  List<CryptoCandle>? getCandles(String ticker, [String? interval]) {
    final target = interval ?? intervals.first;
    return data[ticker]?[target];
  }

  bool isIntervalReady(String ticker, String interval) =>
      isReady[ticker]?[interval] ?? false;

  bool isTicked(String ticker) {
    if (!isReady.containsKey(ticker)) return false;
    return isReady[ticker]!.values.any((ready) => ready);
  }

  // Paksa invalidasi cache — berguna saat user switch ticker/interval
  void invalidateCache([String? ticker, String? interval]) {
    if (ticker == null) {
      _cache.clear();
    } else if (interval == null) {
      for (var iv in intervals) {
        _cache.remove(_cacheKey(ticker, iv));
      }
    } else {
      _cache.remove(_cacheKey(ticker, interval));
    }
  }

  int _getIntervalMinutes(String interval) {
    const map = {
      '1m': 1, '3m': 3, '5m': 5, '15m': 15, '30m': 30,
      '1h': 60, '2h': 120, '4h': 240, '6h': 360, '12h': 720,
      '1d': 1440, '3d': 4320, '1w': 10080,
    };
    return map[interval] ?? 15;
  }

  void dispose() {
    stop();
    data.clear();
    lastCandleTime.clear();
    isReady.clear();
    _cache.clear();
    _inflightRequests.clear();
    _errorCount.clear();
  }
}

// ===========================================================================
// CryptoCandle — tidak berubah, tetap backward-compatible
// ===========================================================================

class CryptoCandle {
  final DateTime openTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final DateTime closeTime;
  final double quoteAssetVolume;
  final int numberOfTrades;
  final double takerBuyBaseVolume;
  final double takerBuyQuoteVolume;

  const CryptoCandle({
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.closeTime,
    required this.quoteAssetVolume,
    required this.numberOfTrades,
    required this.takerBuyBaseVolume,
    required this.takerBuyQuoteVolume,
  });

  factory CryptoCandle.fromList(List<dynamic> data) {
    return CryptoCandle(
      openTime: DateTime.fromMillisecondsSinceEpoch(
        data[0] is int ? data[0] : int.parse(data[0].toString()),
        isUtc: true,
      ),
      open:               double.parse(data[1].toString()),
      high:               double.parse(data[2].toString()),
      low:                double.parse(data[3].toString()),
      close:              double.parse(data[4].toString()),
      volume:             double.parse(data[5].toString()),
      closeTime: DateTime.fromMillisecondsSinceEpoch(
        data[6] is int ? data[6] : int.parse(data[6].toString()),
        isUtc: true,
      ),
      quoteAssetVolume:   double.parse(data[7].toString()),
      numberOfTrades:     data[8] is int ? data[8] : int.parse(data[8].toString()),
      takerBuyBaseVolume: double.parse(data[9].toString()),
      takerBuyQuoteVolume: double.parse(data[10].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'openTime':           openTime.millisecondsSinceEpoch,
    'open':               open,
    'high':               high,
    'low':                low,
    'close':              close,
    'volume':             volume,
    'closeTime':          closeTime.millisecondsSinceEpoch,
    'quoteAssetVolume':   quoteAssetVolume,
    'numberOfTrades':     numberOfTrades,
    'takerBuyBaseVolume': takerBuyBaseVolume,
    'takerBuyQuoteVolume': takerBuyQuoteVolume,
  };
}

// ===========================================================================
// Timeframes & pairs — tidak berubah
// ===========================================================================

class Timeframes {
  static const String m1  = '1m';
  static const String m3  = '3m';
  static const String m5  = '5m';
  static const String m15 = '15m';
  static const String m30 = '30m';
  static const String h1  = '1h';
  static const String h2  = '2h';
  static const String h4  = '4h';
  static const String h6  = '6h';
  static const String h12 = '12h';
  static const String d1  = '1d';
  static const String d3  = '3d';
  static const String w1  = '1w';

  static const List<String> all    = [m1, m3, m5, m15, m30, h1, h2, h4, h6, h12, d1, d3, w1];
  static const List<String> common = [m5, m15, m30, h1, h4, d1];
  static const List<String> trading = [m1, m5, m15, h1, h4];

  static String getLabel(String interval) {
    const labels = {
      '1m': '1M', '3m': '3M', '5m': '5M', '15m': '15M', '30m': '30M',
      '1h': '1H', '2h': '2H', '4h': '4H', '6h': '6H', '12h': '12H',
      '1d': '1D', '3d': '3D', '1w': '1W',
    };
    return labels[interval] ?? interval;
  }
}

class TokoCryptoPairs {
  static const List<String> major = [
    'BTC-USDT', 'ETH-USDT', 'BNB-USDT', 'SOL-USDT', 'XRP-USDT',
  ];

  static const List<String> top10 = [
    'BTC-USDT', 'ETH-USDT', 'BNB-USDT', 'XRP-USDT', 'SOL-USDT',
    'ADA-USDT', 'DOGE-USDT', 'TRX-USDT', 'DOT-USDT', 'MATIC-USDT',
  ];

  static const List<String> top20 = [
    'BTC-USDT', 'ETH-USDT', 'BNB-USDT', 'XRP-USDT', 'SOL-USDT',
    'ADA-USDT', 'DOGE-USDT', 'TRX-USDT', 'DOT-USDT', 'MATIC-USDT',
    'LTC-USDT', 'AVAX-USDT', 'SHIB-USDT', 'LINK-USDT', 'UNI-USDT',
    'ATOM-USDT', 'ETC-USDT', 'XLM-USDT', 'FIL-USDT', 'NEAR-USDT',
  ];

  static const List<String> top100 = [
    'BTC-USDT', 'ETH-USDT', 'BNB-USDT', 'XRP-USDT', 'SOL-USDT',
    'ADA-USDT', 'DOGE-USDT', 'TRX-USDT', 'DOT-USDT', 'MATIC-USDT',
    'LTC-USDT', 'AVAX-USDT', 'SHIB-USDT', 'LINK-USDT', 'UNI-USDT',
    'ATOM-USDT', 'ETC-USDT', 'XLM-USDT', 'FIL-USDT', 'NEAR-USDT',
    'APT-USDT', 'ARB-USDT', 'OP-USDT', 'INJ-USDT', 'SUI-USDT',
    'PEPE-USDT', 'WIF-USDT', 'FLOKI-USDT', 'BONK-USDT', 'RENDER-USDT',
    'FET-USDT', 'AAVE-USDT', 'SAND-USDT', 'MANA-USDT', 'AXS-USDT',
    'THETA-USDT', 'ALGO-USDT', 'VET-USDT', 'ICP-USDT', 'GRT-USDT',
    'FTM-USDT', 'RUNE-USDT', 'EGLD-USDT', 'SNX-USDT', 'CAKE-USDT',
    'XTZ-USDT', 'KAVA-USDT', 'ZIL-USDT', 'ENJ-USDT', 'CHZ-USDT',
    'WAVES-USDT', 'SUSHI-USDT', 'BAT-USDT', 'ZRX-USDT', 'COMP-USDT',
    'YFI-USDT', 'CRV-USDT', 'BAL-USDT', 'UMA-USDT', 'REN-USDT',
    'LRC-USDT', 'STORJ-USDT', 'KNC-USDT', 'BNT-USDT', 'ANT-USDT',
    'MKR-USDT', 'OCEAN-USDT', 'BAND-USDT', 'NMR-USDT', 'CTSI-USDT',
    'ROSE-USDT', 'SKL-USDT', 'COTI-USDT', 'CHR-USDT', 'AKRO-USDT',
    'SXP-USDT', 'STMX-USDT', 'FTT-USDT', 'SRM-USDT', 'RAY-USDT',
    'ALICE-USDT', 'TLM-USDT', 'SFP-USDT', 'DODO-USDT', 'REEF-USDT',
    'DENT-USDT', 'HOT-USDT', 'WIN-USDT', 'BTT-USDT', 'CELR-USDT',
    'ONE-USDT', 'HBAR-USDT', 'GALA-USDT', 'ENS-USDT', 'IMX-USDT',
    'APE-USDT', 'GMT-USDT', 'JASMY-USDT', 'LUNC-USDT', 'USTC-USDT',
  ];
}