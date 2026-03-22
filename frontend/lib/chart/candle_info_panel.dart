import 'package:flutter/material.dart';
import '../hooks/crypto_data_hook.dart'; // Import dari hook!
import '../models/chart_theme.dart';
import '../candle/candle_normal.dart';

/// OHLCV (Open, High, Low, Close, Volume) information panel
/// Displays detailed candle data when a candle is selected
class CandleInfoPanel extends StatelessWidget {
  final CryptoCandle selectedCandle; // Dari crypto_data_hook.dart!
  final CandlestickStyle chartStyle;
  
  const CandleInfoPanel({
    Key? key,
    required this.selectedCandle,
    required this.chartStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          _buildCandleDetail('O', selectedCandle.open),
          _buildCandleDetail('H', selectedCandle.high),
          _buildCandleDetail('L', selectedCandle.low),
          _buildCandleDetail('C', selectedCandle.close),
          _buildCandleDetail('V', selectedCandle.volume, isVolume: true),
        ],
      ),
    );
  }

  Widget _buildCandleDetail(String label, double value, {bool isVolume = false}) {
    // Format value based on size
    String formattedValue;
    if (isVolume) {
      // Format volume dengan K/M/B
      if (value >= 1000000000) {
        formattedValue = '${(value / 1000000000).toStringAsFixed(2)}B';
      } else if (value >= 1000000) {
        formattedValue = '${(value / 1000000).toStringAsFixed(2)}M';
      } else if (value >= 1000) {
        formattedValue = '${(value / 1000).toStringAsFixed(2)}K';
      } else {
        formattedValue = value.toStringAsFixed(0);
      }
    } else {
      // Format price dengan decimal places yang sesuai
      if (value >= 1000) {
        formattedValue = value.toStringAsFixed(2);
      } else if (value >= 10) {
        formattedValue = value.toStringAsFixed(4);
      } else if (value >= 1) {
        formattedValue = value.toStringAsFixed(6);
      } else {
        formattedValue = value.toStringAsFixed(8);
      }
    }

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
          formattedValue,
          style: TextStyle(
            color: chartStyle.textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}