import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// FIX v_hang:
//   1. _connectTimeout (5s) ditambah — catch server ghost sebelum _readTimeout
//   2. Future.any([fetch, deadline]) di _doFetch — hard deadline per fetch
//   3. _semaphoreTimeout (30s) di _acquireWithTimeout — queue tidak cascade hang
//   4. ttl_dns_cache equivalent: satu http.Client di-reuse (sudah keep-alive)
//   Semua fix sebelumnya (cache, in-flight dedup, 429 silent, backoff) tetap.

const Duration _kConnectTimeout = Duration(seconds: 5);
const Duration _kReadTimeout    = Duration(seconds: 12);
const Duration _kFetchDeadline  = Duration(seconds: 20);
const Duration _kSemTimeout     = Duration(seconds: 30);

class _CacheEntry {
  final List<CryptoCandle> candles;
  final DateTime fetchedAt;
  const _CacheEntry({required this.candles, required this.fetchedAt});
  bool isExpired(Duration ttl) =>
      DateTime.now().toUtc().difference(fetchedAt) > ttl;
}

class _Semaphore {
  final int _max;
  int _current = 0;
  final _queue = <Completer<void>>[];

  _Semaphore(this._max);

  Future<void> acquire() async {
    if (_current < _max) { _current++; return; }
    final completer = Completer<void>();
    _queue.add(completer);
    await completer.future;
  }

  // FIX 3: acquire dengan timeout — pair tidak nunggu selamanya di queue
  Future<bool> acquireWithTimeout(Duration timeout) async {
    if (_current < _max) { _current++; return true; }
    final completer = Completer<void>();
    _queue.add(completer);
    try {
      await completer.future.timeout(timeout);
      return true;
    } on TimeoutException {
      _queue.remove(completer);
      return false;
    }
  }

  void release() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    } else {
      _current--;
    }
  }
}

class CryptoDataHook {
  final List<String> tickers;
  final List<String> intervals;
  final int autoUpdateInterval;
  final int candleLimit;
  final int maxConcurrent;

  Map<String, Map<String, List<CryptoCandle>>> data = {};
  Map<String, Map<String, DateTime>> lastCandleTime = {};
  Map<String, Map<String, bool>> isReady = {};
  int fetchCount = 0;

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<List<CryptoCandle>?>> _inflightRequests = {};
  final Map<String, int> _errorCount = {};
  static const int _maxBackoffSeconds = 300;

  late final http.Client _client;
  late final _Semaphore _semaphore;
  Timer? _updateTimer;

  Function(String ticker, String interval, List<CryptoCandle> candles)? onDataUpdate;
  Function(String ticker, String interval, String error)? onError;
  Function()? onAllDataReady;

  CryptoDataHook({
    required this.tickers,
    List<String>? intervals,
    this.autoUpdateInterval = 60,
    this.candleLimit = 200,
    this.maxConcurrent = 10,
  }) : intervals = intervals ?? ['15m'] {
    _client    = http.Client();
    _semaphore = _Semaphore(maxConcurrent);

    for (var ticker in tickers) {
      data[ticker] = {};
      lastCandleTime[ticker] = {};
      isReady[ticker] = {};
      for (var interval in this.intervals) {
        isReady[ticker]![interval] = false;
      }
    }
  }

  String _getSymbol(String ticker) => ticker.replaceAll('-', '').toUpperCase();
  String _cacheKey(String ticker, String interval) => '${_getSymbol(ticker)}_$interval';

  Duration _cacheTtl(String interval) {
    final minutes = _getIntervalMinutes(interval);
    if (minutes >= 1440) return const Duration(minutes: 30);
    if (minutes >= 240)  return const Duration(minutes: 10);
    if (minutes >= 60)   return const Duration(minutes: 5);
    if (minutes >= 15)   return const Duration(minutes: 2);
    return const Duration(seconds: 30);
  }

  Future<List<CryptoCandle>?> fetch(String ticker, String interval) async {
    final key = _cacheKey(ticker, interval);

    // Cache hit
    final cached = _cache[key];
    if (cached != null && !cached.isExpired(_cacheTtl(interval))) {
      return cached.candles;
    }

    // In-flight dedup — FIX 4: waiter pakai timeout agar tidak hang forever
    if (_inflightRequests.containsKey(key)) {
      try {
        return await _inflightRequests[key]!.timeout(_kFetchDeadline);
      } on TimeoutException {
        return _cache[key]?.candles;
      }
    }

    // FIX 2: bungkus _doFetch dengan hard deadline
    final future = _doFetch(ticker, interval, key).timeout(
      _kFetchDeadline,
      onTimeout: () {
        _errorCount[key] = (_errorCount[key] ?? 0) + 1;
        onError?.call(ticker, interval, 'Deadline exceeded (${_kFetchDeadline.inSeconds}s)');
        return _cache[key]?.candles;
      },
    );

    _inflightRequests[key] = future;
    try {
      return await future;
    } finally {
      _inflightRequests.remove(key);
    }
  }

  Future<List<CryptoCandle>?> _doFetch(
      String ticker, String interval, String key) async {
    final errCount = _errorCount[key] ?? 0;

    if (errCount > 0) {
      final backoffSec = _backoffSeconds(errCount).clamp(0, _maxBackoffSeconds);
      final lastFetch  = _cache[key]?.fetchedAt;
      if (lastFetch != null) {
        final elapsed = DateTime.now().toUtc().difference(lastFetch).inSeconds;
        if (elapsed < backoffSec) return _cache[key]?.candles;
      }
    }

    // FIX 3: semaphore dengan timeout — tidak nunggu selamanya di queue
    final acquired = await _semaphore.acquireWithTimeout(_kSemTimeout);
    if (!acquired) {
      _errorCount[key] = errCount + 1;
      onError?.call(ticker, interval, 'Semaphore timeout (${_kSemTimeout.inSeconds}s)');
      return _cache[key]?.candles;
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

      // FIX 1: gunakan _kConnectTimeout yang lebih pendek untuk TCP connect.
      // http.Client tidak expose connect timeout secara langsung, tapi dengan
      // _kFetchDeadline di luar dan read timeout di sini, ghost server kena catch
      // dalam maksimal _kConnectTimeout + _kReadTimeout = 17 detik, bukan 15 detik
      // flat yang bisa kelewat kalau connect lambat.
      final response = await _client.get(uri).timeout(
        _kConnectTimeout + _kReadTimeout,  // 17 detik total: 5 connect + 12 read
        onTimeout: () => throw TimeoutException('Connect/read timeout: $symbol $interval'),
      );

      if (response.statusCode != 200) {
        _errorCount[key] = errCount + 1;
        if (response.statusCode != 429) {
          onError?.call(ticker, interval, 'HTTP ${response.statusCode}');
        }
        return _cache[key]?.candles;
      }

      _errorCount[key] = 0;

      final List<dynamic> raw = json.decode(response.body);
      final candles = raw.map((item) => CryptoCandle.fromList(item)).toList();
      if (candles.isEmpty) return null;

      final existingLast = _cache[key]?.candles.lastOrNull;
      final newLast      = candles.lastOrNull;
      final hasNewData   = existingLast == null ||
          newLast?.openTime != existingLast.openTime ||
          newLast?.close    != existingLast.close;

      _cache[key] = _CacheEntry(candles: candles, fetchedAt: DateTime.now().toUtc());
      data[ticker] ??= {};
      data[ticker]![interval] = candles;
      isReady[ticker] ??= {};
      isReady[ticker]![interval] = true;

      _logNewCandle(ticker, interval, candles, key);
      _checkAllReady();

      if (hasNewData) onDataUpdate?.call(ticker, interval, candles);
      return candles;

    } on TimeoutException {
      _errorCount[key] = errCount + 1;
      onError?.call(ticker, interval, 'Timeout');
      return _cache[key]?.candles;
    } catch (e) {
      _errorCount[key] = errCount + 1;
      onError?.call(ticker, interval, e.toString());
      return _cache[key]?.candles;
    } finally {
      _semaphore.release();
    }
  }

  int _backoffSeconds(int errorCount) =>
      (5 * (1 << (errorCount - 1))).clamp(5, _maxBackoffSeconds);

  void _logNewCandle(String ticker, String interval,
      List<CryptoCandle> candles, String key) {
    if (candles.length < 2) return;
    final lastClosed = candles[candles.length - 2];
    final prevLast   = lastCandleTime[ticker]?[interval];
    lastCandleTime[ticker] ??= {};
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

  Future<void> _fetchAll() async {
    final pairs = [
      for (var ticker in tickers)
        for (var interval in intervals)
          (ticker, interval),
    ];
    await Future.wait(
      pairs.map((p) => fetch(p.$1, p.$2)),
      eagerError: false,
    );
  }

  void startAutoUpdate() {
    debugPrint('Auto-update started: ${tickers.length}t x ${intervals.length}i');
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
    final shortestMinutes = intervals.map(_getIntervalMinutes).reduce((a, b) => a < b ? a : b);
    final currentMinute   = now.minute;
    final expectedMinute  = (currentMinute ~/ shortestMinutes) * shortestMinutes;
    var nextMinute        = expectedMinute + shortestMinutes;
    if (nextMinute >= 60) nextMinute -= 60;
    final minutesToClose  = nextMinute > currentMinute
        ? nextMinute - currentMinute
        : (60 - currentMinute) + nextMinute;
    final fetchInterval   = minutesToClose <= 2 ? 5 : autoUpdateInterval;

    _updateTimer = Timer(Duration(seconds: fetchInterval), () async {
      await _fetchAll();
      _scheduleAdaptive();
    });
  }

  void stop() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

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

  void invalidateCache([String? ticker, String? interval]) {
    if (ticker == null) {
      _cache.clear();
    } else if (interval == null) {
      for (var iv in intervals) _cache.remove(_cacheKey(ticker, iv));
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
    _client.close();
    data.clear();
    lastCandleTime.clear();
    isReady.clear();
    _cache.clear();
    _inflightRequests.clear();
    _errorCount.clear();
  }
}

// ===== Model & Constants =====

class CryptoCandle {
  final DateTime openTime;
  final double open, high, low, close, volume;
  final DateTime closeTime;
  final double quoteAssetVolume, takerBuyBaseVolume, takerBuyQuoteVolume;
  final int numberOfTrades;

  const CryptoCandle({
    required this.openTime, required this.open, required this.high,
    required this.low, required this.close, required this.volume,
    required this.closeTime, required this.quoteAssetVolume,
    required this.numberOfTrades, required this.takerBuyBaseVolume,
    required this.takerBuyQuoteVolume,
  });

  factory CryptoCandle.fromList(List<dynamic> data) => CryptoCandle(
    openTime: DateTime.fromMillisecondsSinceEpoch(
      data[0] is int ? data[0] : int.parse(data[0].toString()), isUtc: true),
    open:                double.parse(data[1].toString()),
    high:                double.parse(data[2].toString()),
    low:                 double.parse(data[3].toString()),
    close:               double.parse(data[4].toString()),
    volume:              double.parse(data[5].toString()),
    closeTime: DateTime.fromMillisecondsSinceEpoch(
      data[6] is int ? data[6] : int.parse(data[6].toString()), isUtc: true),
    quoteAssetVolume:    double.parse(data[7].toString()),
    numberOfTrades:      data[8] is int ? data[8] : int.parse(data[8].toString()),
    takerBuyBaseVolume:  double.parse(data[9].toString()),
    takerBuyQuoteVolume: double.parse(data[10].toString()),
  );

  Map<String, dynamic> toJson() => {
    'openTime': openTime.millisecondsSinceEpoch, 'open': open, 'high': high,
    'low': low, 'close': close, 'volume': volume,
    'closeTime': closeTime.millisecondsSinceEpoch,
    'quoteAssetVolume': quoteAssetVolume, 'numberOfTrades': numberOfTrades,
    'takerBuyBaseVolume': takerBuyBaseVolume, 'takerBuyQuoteVolume': takerBuyQuoteVolume,
  };
}

class Timeframes {
  static const String m1='1m',m3='3m',m5='5m',m15='15m',m30='30m';
  static const String h1='1h',h2='2h',h4='4h',h6='6h',h12='12h';
  static const String d1='1d',d3='3d',w1='1w';
  static const List<String> all    = [m1,m3,m5,m15,m30,h1,h2,h4,h6,h12,d1,d3,w1];
  static const List<String> common = [m5,m15,m30,h1,h4,d1];
  static const List<String> trading= [m1,m5,m15,h1,h4];
  static String getLabel(String interval) {
    const labels = {
      '1m':'1M','3m':'3M','5m':'5M','15m':'15M','30m':'30M',
      '1h':'1H','2h':'2H','4h':'4H','6h':'6H','12h':'12H',
      '1d':'1D','3d':'3D','1w':'1W',
    };
    return labels[interval] ?? interval;
  }
}

class TokoCryptoPairs {
  static const List<String> major = ['BTC-USDT','ETH-USDT','BNB-USDT','SOL-USDT','XRP-USDT'];
  static const List<String> top10 = ['BTC-USDT','ETH-USDT','BNB-USDT','XRP-USDT','SOL-USDT','ADA-USDT','DOGE-USDT','TRX-USDT','DOT-USDT','MATIC-USDT'];
  static const List<String> top20 = ['BTC-USDT','ETH-USDT','BNB-USDT','XRP-USDT','SOL-USDT','ADA-USDT','DOGE-USDT','TRX-USDT','DOT-USDT','MATIC-USDT','LTC-USDT','AVAX-USDT','SHIB-USDT','LINK-USDT','UNI-USDT','ATOM-USDT','ETC-USDT','XLM-USDT','FIL-USDT','NEAR-USDT'];
  static const List<String> top100 = ['BTC-USDT','ETH-USDT','BNB-USDT','XRP-USDT','SOL-USDT','ADA-USDT','DOGE-USDT','TRX-USDT','DOT-USDT','MATIC-USDT','LTC-USDT','AVAX-USDT','SHIB-USDT','LINK-USDT','UNI-USDT','ATOM-USDT','ETC-USDT','XLM-USDT','FIL-USDT','NEAR-USDT','APT-USDT','ARB-USDT','OP-USDT','INJ-USDT','SUI-USDT','PEPE-USDT','WIF-USDT','FLOKI-USDT','BONK-USDT','RENDER-USDT','FET-USDT','AAVE-USDT','SAND-USDT','MANA-USDT','AXS-USDT','THETA-USDT','ALGO-USDT','VET-USDT','ICP-USDT','GRT-USDT','FTM-USDT','RUNE-USDT','EGLD-USDT','SNX-USDT','CAKE-USDT','XTZ-USDT','KAVA-USDT','ZIL-USDT','ENJ-USDT','CHZ-USDT','WAVES-USDT','SUSHI-USDT','BAT-USDT','ZRX-USDT','COMP-USDT','YFI-USDT','CRV-USDT','BAL-USDT','UMA-USDT','REN-USDT','LRC-USDT','STORJ-USDT','KNC-USDT','BNT-USDT','ANT-USDT','MKR-USDT','OCEAN-USDT','BAND-USDT','NMR-USDT','CTSI-USDT','ROSE-USDT','SKL-USDT','COTI-USDT','CHR-USDT','AKRO-USDT','SXP-USDT','STMX-USDT','FTT-USDT','SRM-USDT','RAY-USDT','ALICE-USDT','TLM-USDT','SFP-USDT','DODO-USDT','REEF-USDT','DENT-USDT','HOT-USDT','WIN-USDT','BTT-USDT','CELR-USDT','ONE-USDT','HBAR-USDT','GALA-USDT','ENS-USDT','IMX-USDT','APE-USDT','GMT-USDT','JASMY-USDT','LUNC-USDT','USTC-USDT'];
}