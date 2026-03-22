import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CryptoDataHook {
  final List<String> tickers;
  final List<String> intervals; // Support multiple timeframes
  final int autoUpdateInterval;
  
  // Structure: ticker -> interval -> candles
  Map<String, Map<String, List<CryptoCandle>>> data = {};
  Map<String, Map<String, DateTime>> lastCandleTime = {};
  Map<String, Map<String, bool>> isReady = {}; // Track readiness per ticker-interval
  int fetchCount = 0;
  
  Timer? _updateTimer;
  
  // Callbacks - UPDATED to include interval parameter
  Function(String ticker, String interval, List<CryptoCandle> candles)? onDataUpdate;
  Function(String ticker, String interval, String error)? onError;
  Function()? onAllDataReady;
  
  CryptoDataHook({
    required this.tickers,
    List<String>? intervals,
    this.autoUpdateInterval = 60,
  }) : intervals = intervals ?? ['15m'] {
    // Initialize data structures
    for (var ticker in tickers) {
      data[ticker] = {};
      lastCandleTime[ticker] = {};
      isReady[ticker] = {};
      for (var interval in this.intervals) {
        isReady[ticker]![interval] = false;
      }
    }
  }
  
  String _getSymbol(String ticker) {
    return ticker.replaceAll('-', '').toUpperCase();
  }
  
  Future<List<CryptoCandle>?> fetch(String ticker, String interval) async {
    try {
      fetchCount++;
      final symbol = _getSymbol(ticker);
      
      final uri = Uri.parse('https://www.tokocrypto.site/api/v3/klines').replace(
        queryParameters: {
          'symbol': symbol,
          'interval': interval,
          'limit': '500', // Get more candles for better chart
        },
      );
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Timeout');
        },
      );
      
      if (response.statusCode != 200) {
        if (response.statusCode >= 400) {
          print('❌ API Error ${response.statusCode}: $symbol $interval');
        }
        onError?.call(ticker, interval, 'HTTP ${response.statusCode}');
        return null;
      }
      
      final List<dynamic> raw = json.decode(response.body);
      final List<CryptoCandle> candles = [];
      
      for (var item in raw) {
        candles.add(CryptoCandle.fromList(item));
      }
      
      if (candles.isNotEmpty) {
        _validateAndLog(ticker, interval, candles);
      }
      
      // Store data
      if (!data.containsKey(ticker)) {
        data[ticker] = {};
      }
      data[ticker]![interval] = candles;
      
      if (!isReady.containsKey(ticker)) {
        isReady[ticker] = {};
      }
      isReady[ticker]![interval] = true;
      
      // Trigger UI update
      onDataUpdate?.call(ticker, interval, candles);
      
      // Check if all data is ready
      _checkAllReady();
      
      return candles;
      
    } on TimeoutException {
      onError?.call(ticker, interval, 'Timeout');
      return null;
    } catch (e) {
      onError?.call(ticker, interval, e.toString());
      return null;
    }
  }
  
  void _validateAndLog(String ticker, String interval, List<CryptoCandle> candles) {
    if (candles.length < 2) return;
    
    final lastClosed = candles[candles.length - 2];
    final lastRunning = candles[candles.length - 1];
    final now = DateTime.now().toUtc();
    
    final runningAge = now.difference(lastRunning.openTime).inMinutes;
    
    // Get interval minutes
    final intervalMinutes = _getIntervalMinutes(interval);
    
    // Validation: running candle harus fresh
    if (runningAge > intervalMinutes + 1) {
      onError?.call(ticker, interval, 'Stale ${runningAge}m');
      return;
    }
    
    if (!lastCandleTime.containsKey(ticker)) {
      lastCandleTime[ticker] = {};
    }
    
    final prevLast = lastCandleTime[ticker]![interval];
    
    if (prevLast == null) {
      // First fetch
      print('${_getSymbol(ticker)} $interval ✓');
    } else if (lastClosed.openTime.isAfter(prevLast)) {
      // New candle detected
      print('🔔 ${_getSymbol(ticker)} $interval NEW CANDLE');
    }
    
    lastCandleTime[ticker]![interval] = lastClosed.openTime;
  }
  
  int _getIntervalMinutes(String interval) {
    final map = {
      '1m': 1, '3m': 3, '5m': 5, '15m': 15, '30m': 30,
      '1h': 60, '2h': 120, '4h': 240, '6h': 360, '12h': 720,
      '1d': 1440, '3d': 4320, '1w': 10080,
    };
    return map[interval] ?? 15;
  }
  
  void _checkAllReady() {
    bool allReady = true;
    for (var ticker in tickers) {
      for (var interval in intervals) {
        if (isReady[ticker]?[interval] != true) {
          allReady = false;
          break;
        }
      }
      if (!allReady) break;
    }
    
    if (allReady) {
      onAllDataReady?.call();
    }
  }
  
  void startAutoUpdate() {
    print('🔄 Multi-timeframe update started');
    print('📊 Tickers: ${tickers.join(", ")}');
    print('⏱️  Intervals: ${intervals.join(", ")}');
    
    _updateTimer = Timer.periodic(
      Duration(seconds: autoUpdateInterval),
      (timer) async {
        for (var ticker in tickers) {
          for (var interval in intervals) {
            await fetch(ticker, interval);
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      },
    );
    
    // Initial fetch
    for (var ticker in tickers) {
      for (var interval in intervals) {
        fetch(ticker, interval);
      }
    }
  }
  
  void startAdaptiveUpdate() {
    print('🔄 Adaptive multi-timeframe polling started');
    print('📊 Tickers: ${tickers.join(", ")}');
    print('⏱️  Intervals: ${intervals.join(", ")}');
    
    void scheduleNext() {
      final now = DateTime.now().toUtc();
      
      // Get shortest interval for adaptive timing
      int shortestInterval = _getIntervalMinutes(intervals.first);
      for (var interval in intervals) {
        final minutes = _getIntervalMinutes(interval);
        if (minutes < shortestInterval) {
          shortestInterval = minutes;
        }
      }
      
      final currentMinute = now.minute;
      final expectedMinute = (currentMinute ~/ shortestInterval) * shortestInterval;
      var nextMinute = expectedMinute + shortestInterval;
      if (nextMinute >= 60) nextMinute -= 60;
      
      int minutesToClose;
      if (nextMinute > currentMinute) {
        minutesToClose = nextMinute - currentMinute;
      } else {
        minutesToClose = (60 - currentMinute) + nextMinute;
      }
      
      // Adaptive interval
      int fetchInterval;
      if (minutesToClose <= 2) {
        fetchInterval = 5; // Aggressive near candle close
      } else {
        fetchInterval = autoUpdateInterval; // Normal
      }
      
      _updateTimer = Timer(Duration(seconds: fetchInterval), () async {
        for (var ticker in tickers) {
          for (var interval in intervals) {
            await fetch(ticker, interval);
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
        scheduleNext();
      });
    }
    
    // Initial fetch
    for (var ticker in tickers) {
      for (var interval in intervals) {
        fetch(ticker, interval);
      }
    }
    
    scheduleNext();
  }
  
  void stop() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }
  
  // BACKWARD COMPATIBLE: Get candles with optional interval parameter
  List<CryptoCandle>? getCandles(String ticker, [String? interval]) {
    final targetInterval = interval ?? intervals.first;
    return data[ticker]?[targetInterval];
  }
  
  // Check if specific interval is ready
  bool isIntervalReady(String ticker, String interval) {
    return isReady[ticker]?[interval] ?? false;
  }
  
  // BACKWARD COMPATIBLE: Check if ticker is ready (any interval)
  bool isTicked(String ticker) {
    if (!isReady.containsKey(ticker)) return false;
    return isReady[ticker]!.values.any((ready) => ready == true);
  }
  
  void dispose() {
    stop();
    data.clear();
    lastCandleTime.clear();
    isReady.clear();
  }
}

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
  
  CryptoCandle({
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
      open: double.parse(data[1].toString()),
      high: double.parse(data[2].toString()),
      low: double.parse(data[3].toString()),
      close: double.parse(data[4].toString()),
      volume: double.parse(data[5].toString()),
      closeTime: DateTime.fromMillisecondsSinceEpoch(
        data[6] is int ? data[6] : int.parse(data[6].toString()),
        isUtc: true,
      ),
      quoteAssetVolume: double.parse(data[7].toString()),
      numberOfTrades: data[8] is int ? data[8] : int.parse(data[8].toString()),
      takerBuyBaseVolume: double.parse(data[9].toString()),
      takerBuyQuoteVolume: double.parse(data[10].toString()),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'openTime': openTime.millisecondsSinceEpoch,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
      'closeTime': closeTime.millisecondsSinceEpoch,
      'quoteAssetVolume': quoteAssetVolume,
      'numberOfTrades': numberOfTrades,
      'takerBuyBaseVolume': takerBuyBaseVolume,
      'takerBuyQuoteVolume': takerBuyQuoteVolume,
    };
  }
}

// ===== TIMEFRAME DEFINITIONS =====
class Timeframes {
  static const String m1 = '1m';
  static const String m3 = '3m';
  static const String m5 = '5m';
  static const String m15 = '15m';
  static const String m30 = '30m';
  static const String h1 = '1h';
  static const String h2 = '2h';
  static const String h4 = '4h';
  static const String h6 = '6h';
  static const String h12 = '12h';
  static const String d1 = '1d';
  static const String d3 = '3d';
  static const String w1 = '1w';
  
  static const List<String> all = [
    m1, m3, m5, m15, m30,
    h1, h2, h4, h6, h12,
    d1, d3, w1,
  ];
  
  static const List<String> common = [
    m5, m15, m30, h1, h4, d1,
  ];
  
  static const List<String> trading = [
    m1, m5, m15, h1, h4,
  ];
  
  static String getLabel(String interval) {
    final labels = {
      m1: '1M', m3: '3M', m5: '5M', m15: '15M', m30: '30M',
      h1: '1H', h2: '2H', h4: '4H', h6: '6H', h12: '12H',
      d1: '1D', d3: '3D', w1: '1W',
    };
    return labels[interval] ?? interval;
  }
}

// ===== TOP CRYPTO PAIRS =====
class TokoCryptoPairs {
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
  
  static const List<String> major = [
    'BTC-USDT', 'ETH-USDT', 'BNB-USDT', 'SOL-USDT', 'XRP-USDT',
  ];
}