import 'package:flutter/material.dart';
import '../hooks/crypto_data_hook.dart';
import '../models/chart_theme.dart';
import '../candle/candle_normal.dart';

/// Price information header - SIMPLIFIED VERSION
class PriceHeader extends StatelessWidget {
  final List<CryptoCandle> candles;
  final String selectedTicker;
  final String selectedInterval;
  final CandlestickStyle chartStyle;
  
  const PriceHeader({
    Key? key,
    required this.candles,
    required this.selectedTicker,
    required this.selectedInterval,
    required this.chartStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) return const SizedBox.shrink();
    
    // Latest candle data
    final latest = candles.last;
    final previous = candles.length > 1 ? candles[candles.length - 2] : latest;
    
    // Calculate change
    final change = latest.close - previous.close;
    final changePercent = (change / previous.close) * 100;
    final isPositive = change >= 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: chartStyle.backgroundColor,
        border: Border(
          bottom: BorderSide(color: chartStyle.gridColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // LEFT: Price & Change
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price & Change
                Row(
                  children: [
                    Text(
                      _formatPrice(latest.close),
                      style: TextStyle(
                        color: chartStyle.textColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPositive 
                            ? chartStyle.bullishColor.withOpacity(0.1)
                            : chartStyle.bearishColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${isPositive ? '+' : ''}${_formatPrice(change)} (${changePercent.toStringAsFixed(2)}%)',
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
                // Ticker & Interval
                Text(
                  '${_formatTicker(selectedTicker)} • ${_getIntervalLabel(selectedInterval)}',
                  style: TextStyle(
                    color: chartStyle.textColor.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // RIGHT: H/L/V
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildStat('H', latest.high),
              _buildStat('L', latest.low),
              _buildStat('V', latest.volume, isVolume: true),
            ],
          ),
        ],
      ),
    );
  }
  
  // Helper: Build stat line
  Widget _buildStat(String label, double value, {bool isVolume = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$label: ${isVolume ? _formatVolume(value) : _formatPrice(value)}',
        style: TextStyle(
          color: chartStyle.textColor.withOpacity(0.7),
          fontSize: 12,
        ),
      ),
    );
  }
  
  // Format price with proper decimals
  String _formatPrice(double price) {
    if (price >= 1000) return '\$${price.toStringAsFixed(2)}';
    if (price >= 10) return '\$${price.toStringAsFixed(4)}';
    if (price >= 1) return '\$${price.toStringAsFixed(6)}';
    return '\$${price.toStringAsFixed(8)}';
  }
  
  // Format volume with K/M/B
  String _formatVolume(double volume) {
    if (volume >= 1e9) return '${(volume / 1e9).toStringAsFixed(2)}B';
    if (volume >= 1e6) return '${(volume / 1e6).toStringAsFixed(2)}M';
    if (volume >= 1e3) return '${(volume / 1e3).toStringAsFixed(2)}K';
    return volume.toStringAsFixed(0);
  }
  
  // Format ticker (BTC-USDT -> BTC/USDT)
  String _formatTicker(String ticker) {
    return ticker.replaceAll('-', '/');
  }
  
  // Get interval label
  String _getIntervalLabel(String interval) {
    const labels = {
      '1m': '1 Minute', '3m': '3 Minutes', '5m': '5 Minutes',
      '15m': '15 Minutes', '30m': '30 Minutes',
      '1h': '1 Hour', '2h': '2 Hours', '4h': '4 Hours',
      '6h': '6 Hours', '12h': '12 Hours',
      '1d': '1 Day', '3d': '3 Days', '1w': '1 Week',
    };
    return labels[interval] ?? interval;
  }
}