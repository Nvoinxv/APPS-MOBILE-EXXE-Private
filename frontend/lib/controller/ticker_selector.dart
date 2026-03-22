import 'package:flutter/material.dart';
import '../models/chart_theme.dart';
import '../candle/candle_normal.dart';

/// Widget untuk memilih cryptocurrency ticker
/// 
/// Menampilkan dropdown yang menunjukkan ticker saat ini dan
/// memungkinkan user memilih dari daftar ticker yang tersedia
class TickerSelector extends StatelessWidget {
  final String selectedTicker;
  final List<String> availableTickers;
  final CandlestickStyle style;
  final Function(String) onTickerChanged;

  const TickerSelector({
    Key? key,
    required this.selectedTicker,
    required this.availableTickers,
    required this.style,
    required this.onTickerChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: selectedTicker,
      onSelected: onTickerChanged,
      color: style.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: style.gridColor, width: 1),
      ),
      offset: const Offset(0, 45),
      child: _buildSelectorButton(),
      itemBuilder: (context) => _buildMenuItems(),
    );
  }

  /// Membuat tombol selector dengan ticker saat ini
  Widget _buildSelectorButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: style.gridColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: style.gridColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selectedTicker.replaceAll('-USDT', ''),
            style: TextStyle(
              color: style.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            color: style.textColor,
            size: 20,
          ),
        ],
      ),
    );
  }

  /// Membuat daftar menu items untuk setiap ticker
  List<PopupMenuItem<String>> _buildMenuItems() {
    return availableTickers.map((ticker) {
      final isSelected = ticker == selectedTicker;
      final coinName = ticker.replaceAll('-USDT', '');

      return PopupMenuItem<String>(
        value: ticker,
        height: 48,
        child: Row(
          children: [
            _buildCoinAvatar(coinName, isSelected),
            const SizedBox(width: 12),
            Text(
              coinName,
              style: TextStyle(
                color: isSelected ? style.bullishColor : style.textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 15,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Icon(
                Icons.check,
                color: style.bullishColor,
                size: 18,
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  /// Membuat avatar untuk coin dengan initial letter
  Widget _buildCoinAvatar(String coinName, bool isSelected) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isSelected
            ? style.bullishColor.withOpacity(0.2)
            : style.gridColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          coinName.isNotEmpty ? coinName.substring(0, 1) : '?',
          style: TextStyle(
            color: isSelected ? style.bullishColor : style.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}