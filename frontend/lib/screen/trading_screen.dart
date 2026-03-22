import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../hooks/crypto_data_hook.dart';
import '../candle/candle_normal.dart';
import '../interactive/cross_interactive.dart';
import '../interactive/volume_interactive.dart';
import '../interactive/risk_ratio_interactive.dart';
import '../interactive/fibonacci_interactive.dart';

class CryptoTradingView extends StatefulWidget {
  final List<String>? tickers;
  final List<String>? intervals;
  
  const CryptoTradingView({
    Key? key,
    this.tickers,
    this.intervals,
  }) : super(key: key);

  @override
  State<CryptoTradingView> createState() => _CryptoTradingViewState();
}

class _CryptoTradingViewState extends State<CryptoTradingView> {
  late CryptoDataHook cryptoHook;
  late List<String> availableTickers;
  late List<String> availableIntervals;
  
  String selectedTicker = 'BTC-USDT';
  String selectedInterval = '15m';
  
  List<CryptoCandle> candles = [];
  CryptoCandle? selectedCandle;
  late CandlestickStyle chartStyle;
  
  bool isRiskRatioMode = false;
  RiskRatioMode riskRatioMode = RiskRatioMode.buy;
  final GlobalKey<RiskRatioInteractiveState> _riskRatioKey = GlobalKey();

  bool showVolume = true;
  bool showGrid = true;
  bool showCrosshair = true;
  bool isLoading = true;
  
  // Fibonacci controls
  bool isFibonacciMode = false;
  final GlobalKey<FibonacciInteractiveState> _fibonacciKey = GlobalKey();
  
  // Chart interaction controls
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _previousOffset = Offset.zero;
  
  // Crosshair position
  Offset? _crosshairPosition;
  
  @override
  void initState() {
    super.initState();
    
    // Futuristic dark theme with neon green accents
    chartStyle = CandlestickStyle(
      bullishColor: const Color(0xFF00FF88), // Neon green
      bearishColor: const Color(0xFFFF0066), // Neon pink/red
      backgroundColor: const Color(0xFF0A0E17), // Deep space black
      gridColor: const Color(0xFF1A2332), // Dark blue-gray
      textColor: const Color(0xFF8B93A7), // Muted gray-blue
      crosshairColor: const Color(0xFF00FF88).withOpacity(0.3),
      selectedColor: const Color(0xFF00FFFF), // Cyan highlight
    );
    
    // Use provided tickers or default to major pairs
    availableTickers = widget.tickers ?? TokoCryptoPairs.major;
    availableIntervals = widget.intervals ?? Timeframes.common;
    
    selectedTicker = availableTickers.first;
    selectedInterval = availableIntervals.first;
    
    _initializeCryptoHook();
  }
  
  void _initializeCryptoHook() {
    cryptoHook = CryptoDataHook(
      tickers: availableTickers,
      intervals: availableIntervals,
      autoUpdateInterval: 60,
    );
    
    cryptoHook.onDataUpdate = (ticker, interval, candlesData) {
      if (mounted && ticker == selectedTicker && interval == selectedInterval) {
        setState(() {
          candles = candlesData;
          isLoading = false;
        });
      }
    };
    
    cryptoHook.onError = (ticker, interval, error) {
      if (mounted) {
        // Silent error logging - no red popups
        print('⚠️ Error $ticker $interval: $error');
      }
    };
    
    cryptoHook.onAllDataReady = () {
      if (mounted) {
        print('✅ All timeframes loaded');
      }
    };
    
    cryptoHook.startAdaptiveUpdate();
  }
  
  void _changeTicker(String newTicker) {
    setState(() {
      selectedTicker = newTicker;
      isLoading = true;
      candles = [];
      selectedCandle = null;
      _crosshairPosition = null;
      isFibonacciMode = false;
    });
    
    final existingCandles = cryptoHook.getCandles(newTicker, selectedInterval);
    if (existingCandles != null && existingCandles.isNotEmpty) {
      setState(() {
        candles = existingCandles;
        isLoading = false;
      });
    }
  }
  
  void _changeInterval(String newInterval) {
    setState(() {
      selectedInterval = newInterval;
      isLoading = true;
      candles = [];
      selectedCandle = null;
      _crosshairPosition = null;
      isFibonacciMode = false;
    });
    
    final existingCandles = cryptoHook.getCandles(selectedTicker, newInterval);
    if (existingCandles != null && existingCandles.isNotEmpty) {
      setState(() {
        candles = existingCandles;
        isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    cryptoHook.dispose();
    super.dispose();
  }
  
  // Helper method to get the datetime from a candle
  DateTime _getCandleDateTime(CryptoCandle candle) {
    try {
      return (candle as dynamic).timestamp as DateTime;
    } catch (e) {
      try {
        return (candle as dynamic).dateTime as DateTime;
      } catch (e) {
        try {
          return (candle as dynamic).openTime as DateTime;
        } catch (e) {
          try {
            return (candle as dynamic).date as DateTime;
          } catch (e) {
            return DateTime.now();
          }
        }
      }
    }
  }
  
  // Get min/max price from candles for Fibonacci
  double _getMinPrice() {
    if (candles.isEmpty) return 0;
    return candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
  }
  
  double _getMaxPrice() {
    if (candles.isEmpty) return 0;
    return candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chartStyle.backgroundColor,
      appBar: AppBar(
        backgroundColor: chartStyle.backgroundColor,
        elevation: 0,
        title: Row(
          children: [
            _buildTickerSelector(),
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 24,
              color: chartStyle.gridColor,
            ),
            const SizedBox(width: 12),
            _buildIntervalSelector(),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: chartStyle.textColor),
            onPressed: _showStyleSettings,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: chartStyle.textColor),
            onPressed: () {
              setState(() => isLoading = true);
              cryptoHook.fetch(selectedTicker, selectedInterval);
            },
          ),
        ],
      ),
      body: isLoading || candles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: chartStyle.bullishColor,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading $selectedTicker ${Timeframes.getLabel(selectedInterval)}...',
                    style: TextStyle(
                      color: chartStyle.textColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildPriceHeader(),
                
                // Candlestick chart with zoom & pan controls
                Expanded(
                  flex: 7,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
                    child: GestureDetector(
                      // ONLY handle zoom/pan when NOT in drawing modes
                      onScaleStart: (!isFibonacciMode && !isRiskRatioMode) ? (details) {
                        _previousScale = _scale;
                        _previousOffset = _offset;
                      } : null,
                      onScaleUpdate: (!isFibonacciMode && !isRiskRatioMode) ? (details) {
                        setState(() {
                          final scaleChanged = (details.scale - 1.0).abs() > 0.01;
                          
                          if (scaleChanged) {
                            final newScale = (_previousScale * details.scale).clamp(0.3, 5.0);
                            final focalPoint = details.localFocalPoint.dx;
                            final oldScale = _scale;
                            _scale = newScale;
                            
                            final scaleRatio = newScale / oldScale;
                            _offset = Offset(
                              focalPoint - (focalPoint - _offset.dx) * scaleRatio,
                              0,
                            );
                          } else {
                            _offset = Offset(
                              _offset.dx + details.focalPointDelta.dx,
                              0,
                            );
                          }
                        });
                      } : null,
                      
                      onDoubleTap: (!isFibonacciMode && !isRiskRatioMode) ? () {
                        setState(() {
                          _scale = 1.0;
                          _offset = Offset.zero;
                        });
                      } : null,
                      
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final chartSize = Size(constraints.maxWidth, constraints.maxHeight);
                          
                          return Stack(
                            children: [
                              // Base Chart - handles candle selection
                              InteractiveCandlestickChart(
                                candles: candles,
                                style: chartStyle,
                                showVolume: false,
                                showGrid: showGrid,
                                scale: _scale,
                                offset: _offset,
                                onCandleSelected: (candle) {
                                  setState(() {
                                    selectedCandle = candle;
                                  });
                                },
                                onTapPosition: (position) {
                                  // Show crosshair ONLY when not in drawing modes
                                  if (showCrosshair && !isFibonacciMode && !isRiskRatioMode) {
                                    setState(() {
                                      _crosshairPosition = position;
                                    });
                                  }
                                },
                                onTapEnd: () {
                                  if (showCrosshair && !isFibonacciMode && !isRiskRatioMode) {
                                    Future.delayed(const Duration(milliseconds: 100), () {
                                      if (mounted) {
                                        setState(() {
                                          _crosshairPosition = null;
                                        });
                                      }
                                    });
                                  }
                                },
                              ),
                              
                              // Fibonacci Layer - ONLY active when in fibonacci mode
                              if (isFibonacciMode || _fibonacciKey.currentState?.fibonacci != null)
                                GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onPanStart: isFibonacciMode ? (details) {
                                    final fibState = _fibonacciKey.currentState;
                                    if (fibState != null) {
                                      final handled = fibState.handleTapDown(details.localPosition);
                                      if (!handled) {
                                        fibState.startDrawing(details.localPosition);
                                      }
                                    }
                                  } : null,
                                  onPanUpdate: isFibonacciMode ? (details) {
                                    final fibState = _fibonacciKey.currentState;
                                    if (fibState != null) {
                                      if (fibState.isDraggingStart || fibState.isDraggingEnd) {
                                        fibState.handleDrag(details.localPosition);
                                      } else {
                                        fibState.updateDrawing(details.localPosition);
                                      }
                                    }
                                  } : null,
                                  onPanEnd: isFibonacciMode ? (_) {
                                    final fibState = _fibonacciKey.currentState;
                                    if (fibState != null) {
                                      if (fibState.isDraggingStart || fibState.isDraggingEnd) {
                                        fibState.handleDragEnd();
                                      } else {
                                        fibState.finishDrawing();
                                      }
                                    }
                                  } : null,
                                  onDoubleTap: isFibonacciMode ? () {
                                    final fibState = _fibonacciKey.currentState;
                                    if (fibState != null && fibState.fibonacci != null) {
                                      fibState.toggleLock();
                                      setState(() {});
                                    }
                                  } : null,
                                  onSecondaryTapDown: (details) {
                                    final fibState = _fibonacciKey.currentState;
                                    if (fibState?.fibonacci != null) {
                                      _showFibonacciContextMenu(context, details.globalPosition);
                                    }
                                  },
                                  child: FibonacciInteractive(
                                    key: _fibonacciKey,
                                    chartSize: chartSize,
                                    accentColor: chartStyle.bullishColor,
                                    backgroundColor: chartStyle.backgroundColor,
                                    textColor: chartStyle.textColor,
                                    minPrice: _getMinPrice(),
                                    maxPrice: _getMaxPrice(),
                                  ),
                                ),
                              
                              // Risk Ratio Layer - ONLY active when in risk ratio mode
                              if (isRiskRatioMode || _riskRatioKey.currentState?.riskRatio != null)
                                GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onPanStart: isRiskRatioMode ? (details) {
                                    final rrState = _riskRatioKey.currentState;
                                    if (rrState != null) {
                                      final handled = rrState.handleTapDown(details.localPosition);
                                      if (!handled) {
                                        rrState.startDrawing(details.localPosition);
                                      }
                                    }
                                  } : null,
                                  onPanUpdate: isRiskRatioMode ? (details) {
                                    final rrState = _riskRatioKey.currentState;
                                    if (rrState != null) {
                                      if (rrState.isDraggingEntry || 
                                          rrState.isDraggingStopLoss || 
                                          rrState.isDraggingTakeProfit) {
                                        rrState.handleDrag(details.localPosition);
                                      } else {
                                        rrState.updateDrawing(details.localPosition);
                                      }
                                    }
                                  } : null,
                                  onPanEnd: isRiskRatioMode ? (_) {
                                    final rrState = _riskRatioKey.currentState;
                                    if (rrState != null) {
                                      if (rrState.isDraggingEntry || 
                                          rrState.isDraggingStopLoss || 
                                          rrState.isDraggingTakeProfit) {
                                        rrState.handleDragEnd();
                                      } else {
                                        rrState.finishDrawing();
                                      }
                                    }
                                  } : null,
                                  onDoubleTap: isRiskRatioMode ? () {
                                    final rrState = _riskRatioKey.currentState;
                                    if (rrState != null && rrState.riskRatio != null) {
                                      rrState.toggleLock();
                                      setState(() {});
                                    }
                                  } : null,
                                  onSecondaryTapDown: (details) {
                                    final rrState = _riskRatioKey.currentState;
                                    if (rrState?.riskRatio != null) {
                                      _showRiskRatioContextMenu(context, details.globalPosition);
                                    }
                                  },
                                  child: RiskRatioInteractive(
                                    key: _riskRatioKey,
                                    chartSize: chartSize,
                                    accentColor: chartStyle.bullishColor,
                                    backgroundColor: chartStyle.backgroundColor,
                                    textColor: chartStyle.textColor,
                                    minPrice: _getMinPrice(),
                                    maxPrice: _getMaxPrice(),
                                    initialMode: riskRatioMode,
                                  ),
                                ),
                              
                              // Crosshair - ONLY show when not in drawing modes
                              if (showCrosshair && !isFibonacciMode && !isRiskRatioMode && _crosshairPosition != null)
                                SmoothCrosshair(
                                  position: _crosshairPosition,
                                  color: chartStyle.crosshairColor.withOpacity(0.8),
                                  strokeWidth: 1.2,
                                  chartSize: chartSize,
                                  showLabels: true,
                                  priceLabel: selectedCandle != null 
                                      ? '\$${selectedCandle!.close.toStringAsFixed(2)}'
                                      : null,
                                  timeLabel: selectedCandle != null
                                      ? _formatTime(_getCandleDateTime(selectedCandle!))
                                      : null,
                                  labelBackgroundColor: chartStyle.gridColor,
                                  labelTextColor: chartStyle.bullishColor,
                                  onPositionChanged: (position) {
                                    setState(() {
                                      _crosshairPosition = position;
                                    });
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                // Volume Bar Section
                if (showVolume)
                  Container(
                    height: 100,
                    margin: const EdgeInsets.only(left: 8, right: 8, top: 4),
                    decoration: BoxDecoration(
                      color: chartStyle.backgroundColor,
                      border: Border(
                        top: BorderSide(
                          color: chartStyle.gridColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        VolumeInfoPanel(
                          selectedCandle: selectedCandle,
                          textColor: chartStyle.textColor,
                          bullishColor: chartStyle.bullishColor,
                          bearishColor: chartStyle.bearishColor,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                            child: FuturisticVolumeBar(
                              candles: candles,
                              bullishColor: chartStyle.bullishColor,
                              bearishColor: chartStyle.bearishColor,
                              backgroundColor: chartStyle.backgroundColor,
                              scale: _scale,
                              offset: _offset,
                              selectedIndex: selectedCandle != null 
                                  ? candles.indexOf(selectedCandle!)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                if (selectedCandle != null) _buildCandleInfo(),
                
                _buildControls(),
              ],
            ),
    );
  }
  
  String _formatTime(DateTime time) {
    if (selectedInterval.contains('m')) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (selectedInterval.contains('h')) {
      return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:00';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
  
  Widget _buildTickerSelector() {
    return PopupMenuButton<String>(
      initialValue: selectedTicker,
      onSelected: _changeTicker,
      color: chartStyle.backgroundColor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: chartStyle.gridColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: chartStyle.gridColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedTicker.replaceAll('-USDT', ''),
              style: TextStyle(
                color: chartStyle.textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: chartStyle.textColor,
              size: 20,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => availableTickers.map((ticker) {
        final isSelected = ticker == selectedTicker;
        final coinName = ticker.replaceAll('-USDT', '');
        
        return PopupMenuItem<String>(
          value: ticker,
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? chartStyle.bullishColor.withOpacity(0.2)
                      : chartStyle.gridColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    coinName.substring(0, 1),
                    style: TextStyle(
                      color: isSelected 
                          ? chartStyle.bullishColor
                          : chartStyle.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                coinName,
                style: TextStyle(
                  color: isSelected 
                      ? chartStyle.bullishColor
                      : chartStyle.textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(
                  Icons.check,
                  color: chartStyle.bullishColor,
                  size: 18,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildIntervalSelector() {
    final intervalSymbols = {
      '1m': '1′',
      '3m': '3′',
      '5m': '5′',
      '15m': '15′',
      '30m': '30′',
      '1h': '1h',
      '2h': '2h',
      '4h': '4h',
      '6h': '6h',
      '12h': '12h',
      '1d': '1D',
      '3d': '3D',
      '1w': '1W',
    };
    
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1419),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF1A2332),
          width: 1,
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: availableIntervals.length,
        itemBuilder: (context, index) {
          final interval = availableIntervals[index];
          final isSelected = interval == selectedInterval;
          final symbol = intervalSymbols[interval] ?? interval;
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: GestureDetector(
              onTap: () => _changeInterval(interval),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: isSelected 
                      ? LinearGradient(
                          colors: [
                            const Color(0xFF00FF88).withOpacity(0.3),
                            const Color(0xFF00CC6A).withOpacity(0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected 
                        ? const Color(0xFF00FF88)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: const Color(0xFF00FF88).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ] : null,
                ),
                child: Center(
                  child: Text(
                    symbol,
                    style: TextStyle(
                      color: isSelected 
                          ? const Color(0xFF00FF88)
                          : const Color(0xFF4A5568),
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildPriceHeader() {
    if (candles.isEmpty) return const SizedBox.shrink();
    
    final latest = candles.last;
    final previous = candles.length > 1 ? candles[candles.length - 2] : latest;
    final change = latest.close - previous.close;
    final changePercent = (change / previous.close) * 100;
    final isPositive = change >= 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: chartStyle.backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: chartStyle.gridColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '\$${latest.close.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: chartStyle.textColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive 
                            ? chartStyle.bullishColor.withOpacity(0.1)
                            : chartStyle.bearishColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${isPositive ? '+' : ''}${change.toStringAsFixed(2)} (${changePercent.toStringAsFixed(2)}%)',
                        style: TextStyle(
                          color: isPositive 
                              ? chartStyle.bullishColor
                              : chartStyle.bearishColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${selectedTicker.replaceAll('-USDT', '/USDT')} • ${Timeframes.getLabel(selectedInterval)}',
                  style: TextStyle(
                    color: chartStyle.textColor.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildInfoText('H', latest.high),
              _buildInfoText('L', latest.low),
              _buildInfoText('V', latest.volume, isVolume: true),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoText(String label, double value, {bool isVolume = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$label: ${isVolume ? value.toStringAsFixed(0) : value.toStringAsFixed(2)}',
        style: TextStyle(
          color: chartStyle.textColor.withOpacity(0.7),
          fontSize: 12,
        ),
      ),
    );
  }
  
  Widget _buildCandleInfo() {
    final candle = selectedCandle!;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: chartStyle.backgroundColor,
        border: Border(
          top: BorderSide(
            color: chartStyle.gridColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildCandleDetail('O', candle.open),
          _buildCandleDetail('H', candle.high),
          _buildCandleDetail('L', candle.low),
          _buildCandleDetail('C', candle.close),
          _buildCandleDetail('V', candle.volume, isVolume: true),
        ],
      ),
    );
  }
  
  Widget _buildCandleDetail(String label, double value, {bool isVolume = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: chartStyle.textColor.withOpacity(0.6),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isVolume ? value.toStringAsFixed(0) : value.toStringAsFixed(2),
          style: TextStyle(
            color: chartStyle.textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildControls() {
    final fibState = _fibonacciKey.currentState;
    final hasFibonacci = fibState?.fibonacci != null;
    final rrState = _riskRatioKey.currentState;
    final hasRiskRatio = rrState?.riskRatio != null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0A0E17),
            const Color(0xFF0F1419),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF1A2332),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToggleButton('📊 Volume', showVolume, () => setState(() => showVolume = !showVolume)),
          _buildToggleButton('⊞ Grid', showGrid, () => setState(() => showGrid = !showGrid)),
          _buildToggleButton('✛ Cross', showCrosshair && !isFibonacciMode && !isRiskRatioMode, () {
            if (!isFibonacciMode && !isRiskRatioMode) {
              setState(() => showCrosshair = !showCrosshair);
            }
          }),
          _buildToggleButton('📐 Fib', isFibonacciMode, () {
            setState(() {
              isFibonacciMode = !isFibonacciMode;
              if (isFibonacciMode) isRiskRatioMode = false;
            });
          }),
          _buildRiskRatioButton(),
          if (!isFibonacciMode && !isRiskRatioMode)
            _buildToggleButton('↺ Reset', false, () {
              setState(() {
                _scale = 1.0;
                _offset = Offset.zero;
              });
            }),
        ],
      ),
    );
  }

  Widget _buildRiskRatioButton() {
    return InkWell(
      onTap: () {
        setState(() {
          isRiskRatioMode = !isRiskRatioMode;
          if (isRiskRatioMode) isFibonacciMode = false;
        });
      },
      onLongPress: () {
        setState(() {
          riskRatioMode = riskRatioMode == RiskRatioMode.buy 
              ? RiskRatioMode.sell 
              : RiskRatioMode.buy;
          _riskRatioKey.currentState?.setMode(riskRatioMode);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isRiskRatioMode 
              ? LinearGradient(
                  colors: [
                    (riskRatioMode == RiskRatioMode.buy 
                        ? const Color(0xFF00FF88) 
                        : const Color(0xFFFF0066)).withOpacity(0.2),
                    (riskRatioMode == RiskRatioMode.buy 
                        ? const Color(0xFF00CC6A) 
                        : const Color(0xFFCC0052)).withOpacity(0.1),
                  ],
                )
              : null,
          color: isRiskRatioMode ? null : const Color(0xFF0F1419),
          border: Border.all(
            color: isRiskRatioMode 
                ? (riskRatioMode == RiskRatioMode.buy 
                    ? const Color(0xFF00FF88) 
                    : const Color(0xFFFF0066))
                : const Color(0xFF1A2332),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isRiskRatioMode ? [
            BoxShadow(
              color: (riskRatioMode == RiskRatioMode.buy 
                  ? const Color(0xFF00FF88) 
                  : const Color(0xFFFF0066)).withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              riskRatioMode == RiskRatioMode.buy ? '📈' : '📉',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 4),
            Text(
              'R:R',
              style: TextStyle(
                color: isRiskRatioMode 
                    ? (riskRatioMode == RiskRatioMode.buy 
                        ? const Color(0xFF00FF88) 
                        : const Color(0xFFFF0066))
                    : const Color(0xFF4A5568),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showRiskRatioContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final rrState = _riskRatioKey.currentState;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: chartStyle.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: chartStyle.gridColor,
          width: 1,
        ),
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                Icons.swap_vert,
                color: chartStyle.bullishColor,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                'Switch to ${rrState?.riskRatio?.mode == RiskRatioMode.buy ? "SELL" : "BUY"}',
                style: TextStyle(
                  color: chartStyle.textColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          onTap: () {
            final currentMode = rrState?.riskRatio?.mode ?? RiskRatioMode.buy;
            final newMode = currentMode == RiskRatioMode.buy 
                ? RiskRatioMode.sell 
                : RiskRatioMode.buy;
            
            setState(() {
              riskRatioMode = newMode;
            });
            rrState?.setMode(newMode);
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                rrState?.isLocked ?? false ? Icons.lock_open : Icons.lock,
                color: const Color(0xFFFFD700),
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                rrState?.isLocked ?? false ? 'Unlock' : 'Lock',
                style: TextStyle(
                  color: chartStyle.textColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          onTap: () {
            rrState?.toggleLock();
            setState(() {});
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: chartStyle.bearishColor,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                'Delete Risk Ratio',
                style: TextStyle(
                  color: chartStyle.bearishColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          onTap: () {
            rrState?.clearRiskRatio();
            setState(() {});
          },
        ),
      ],
    );
  }
  
  void _showFibonacciContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: chartStyle.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: chartStyle.gridColor,
          width: 1,
        ),
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                _fibonacciKey.currentState?.isLocked ?? false 
                    ? Icons.lock_open 
                    : Icons.lock,
                color: const Color(0xFFFFD700),
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                _fibonacciKey.currentState?.isLocked ?? false 
                    ? 'Unlock Fibonacci'
                    : 'Lock Fibonacci',
                style: TextStyle(
                  color: chartStyle.textColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          onTap: () {
            _fibonacciKey.currentState?.toggleLock();
            setState(() {});
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: chartStyle.bearishColor,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                'Delete Fibonacci',
                style: TextStyle(
                  color: chartStyle.bearishColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          onTap: () {
            _fibonacciKey.currentState?.clearFibonacci();
            setState(() {});
          },
        ),
      ],
    );
  }
  
  Widget _buildToggleButton(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive 
              ? LinearGradient(
                  colors: [
                    const Color(0xFF00FF88).withOpacity(0.2),
                    const Color(0xFF00CC6A).withOpacity(0.1),
                  ],
                )
              : null,
          color: isActive ? null : const Color(0xFF0F1419),
          border: Border.all(
            color: isActive 
                ? const Color(0xFF00FF88)
                : const Color(0xFF1A2332),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive ? [
            BoxShadow(
              color: const Color(0xFF00FF88).withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive 
                ? const Color(0xFF00FF88)
                : const Color(0xFF4A5568),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
  
  void _showStyleSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: chartStyle.backgroundColor,
      builder: (context) => StyleSettingsSheet(
        currentStyle: chartStyle,
        onStyleChanged: (newStyle) {
          setState(() {
            chartStyle = newStyle;
          });
        },
      ),
    );
  }
}

// ===== INTERACTIVE CANDLESTICK CHART =====
class InteractiveCandlestickChart extends StatefulWidget {
  final List<CryptoCandle> candles;
  final CandlestickStyle style;
  final bool showVolume;
  final bool showGrid;
  final double scale;
  final Offset offset;
  final Function(CryptoCandle?)? onCandleSelected;
  final Function(Offset)? onTapPosition;
  final VoidCallback? onTapEnd;
  
  const InteractiveCandlestickChart({
    Key? key,
    required this.candles,
    required this.style,
    required this.showVolume,
    required this.showGrid,
    required this.scale,
    required this.offset,
    this.onCandleSelected,
    this.onTapPosition,
    this.onTapEnd,
  }) : super(key: key);

  @override
  State<InteractiveCandlestickChart> createState() => _InteractiveCandlestickChartState();
}

class _InteractiveCandlestickChartState extends State<InteractiveCandlestickChart> {
  int? _selectedIndex;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        _findSelectedCandle(details.localPosition);
        widget.onTapPosition?.call(details.localPosition);
      },
      onTapUp: (_) {
        widget.onTapEnd?.call();
      },
      child: CustomPaint(
        painter: InteractiveCandlestickPainter(
          candles: widget.candles,
          style: widget.style,
          scale: widget.scale,
          offset: widget.offset,
          showVolume: widget.showVolume,
          showGrid: widget.showGrid,
          selectedIndex: _selectedIndex,
        ),
        child: Container(),
      ),
    );
  }
  
  void _findSelectedCandle(Offset position) {
    final chartWidth = context.size?.width ?? 0;
    final adjustedX = (position.dx - widget.offset.dx) / widget.scale;
    final candleWidth = chartWidth / widget.candles.length;
    final index = (adjustedX / candleWidth).floor();
    
    if (index >= 0 && index < widget.candles.length) {
      setState(() {
        _selectedIndex = index;
        widget.onCandleSelected?.call(widget.candles[index]);
      });
    }
  }
}

// ===== STYLE SETTINGS SHEET =====
class StyleSettingsSheet extends StatefulWidget {
  final CandlestickStyle currentStyle;
  final Function(CandlestickStyle) onStyleChanged;
  
  const StyleSettingsSheet({
    Key? key,
    required this.currentStyle,
    required this.onStyleChanged,
  }) : super(key: key);

  @override
  State<StyleSettingsSheet> createState() => _StyleSettingsSheetState();
}

class _StyleSettingsSheetState extends State<StyleSettingsSheet> {
  late CandlestickStyle style;
  
  @override
  void initState() {
    super.initState();
    style = widget.currentStyle;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chart Style Settings',
                  style: TextStyle(
                    color: style.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: style.textColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Preset Themes
            Text(
              'Preset Themes',
              style: TextStyle(color: style.textColor, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildThemeButton('TradingView', _tradingViewTheme()),
                _buildThemeButton('Dark', _darkTheme()),
                _buildThemeButton('Light', _lightTheme()),
                _buildThemeButton('Blue', _blueTheme()),
              ],
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildThemeButton(String label, CandlestickStyle theme) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          style = theme;
          widget.onStyleChanged(theme);
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
      ),
      child: Text(label),
    );
  }
  
  CandlestickStyle _tradingViewTheme() {
    return CandlestickStyle(
      bullishColor: const Color(0xFF26A69A),
      bearishColor: const Color(0xFFEF5350),
      backgroundColor: const Color(0xFF1E222D),
      gridColor: const Color(0xFF2A2E39),
      textColor: const Color(0xFFB2B5BE),
    );
  }
  
  CandlestickStyle _darkTheme() {
    return CandlestickStyle(
      bullishColor: Colors.green,
      bearishColor: Colors.red,
      backgroundColor: Colors.black,
      gridColor: const Color(0xFF2D2D2D),
      textColor: Colors.white70,
    );
  }
  
  CandlestickStyle _lightTheme() {
    return CandlestickStyle(
      bullishColor: const Color(0xFF26A69A),
      bearishColor: const Color(0xFFEF5350),
      backgroundColor: Colors.white,
      gridColor: const Color(0xFFE0E0E0),
      textColor: Colors.black87,
    );
  }
  
  CandlestickStyle _blueTheme() {
    return CandlestickStyle(
      bullishColor: Colors.blue,
      bearishColor: Colors.orange,
      backgroundColor: const Color(0xFF0D1B2A),
      gridColor: const Color(0xFF1B263B),
      textColor: const Color(0xFFE0E1DD),
    );
  }
}