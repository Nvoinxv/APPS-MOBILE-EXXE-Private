import 'package:flutter/material.dart';
import '../hooks/crypto_data_hook.dart';
import '../models/chart_theme.dart';
import '../interactive/volume_interactive.dart';
import '../candle/candle_normal.dart';

/// Volume section widget - SIMPLIFIED VERSION
class VolumeSection extends StatelessWidget {
  final List<CryptoCandle> candles;
  final CandlestickStyle chartStyle;
  final CryptoCandle? selectedCandle;
  
  const VolumeSection({
    Key? key,
    required this.candles,
    required this.chartStyle,
    this.selectedCandle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Volume Info Panel (if candle selected)
          if (selectedCandle != null)
            VolumeInfoPanel(
              selectedCandle: selectedCandle,
              textColor: chartStyle.textColor,
              bullishColor: chartStyle.bullishColor,
              bearishColor: chartStyle.bearishColor,
            ),
          
          // Volume Bars
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              child: FuturisticVolumeBar(
                candles: candles,
                bullishColor: chartStyle.bullishColor,
                bearishColor: chartStyle.bearishColor,
                backgroundColor: chartStyle.backgroundColor,
                scale: 1.0,           // Default scale
                offset: Offset.zero,  // Default offset
                selectedIndex: selectedCandle != null 
                    ? candles.indexOf(selectedCandle!)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}