import 'package:flutter/material.dart';
import '../hooks/crypto_data_hook.dart';

/// Helper class untuk formatting dan utility functions
class ChartHelpers {
  ChartHelpers._(); // Private constructor

  /// Format waktu berdasarkan interval yang dipilih
  /// 
  /// - Interval menit (m): HH:mm
  /// - Interval jam (h): DD/MM HH:00
  /// - Interval hari/minggu: DD/MM/YYYY
  static String formatTime(DateTime time, String interval) {
    if (interval.contains('m')) {
      // Format untuk minute intervals: 09:30
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (interval.contains('h')) {
      // Format untuk Shour intervals: 15/12 14:00
      return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:00';
    } else {
      // Format untuk day/week intervals: 15/12/2024
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  /// Format harga dengan simbol dollar dan 2 decimal places
  static String formatPrice(double price) {
    return '\$${price.toStringAsFixed(2)}';
  }

  /// Format volume tanpa decimal places
  static String formatVolume(double volume) {
    return volume.toStringAsFixed(0);
  }

  /// Format perubahan harga dengan tanda + atau -
  static String formatPriceChange(double change) {
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(2)}';
  }

  /// Format perubahan persentase
  static String formatPercentChange(double percent) {
    return '${percent.toStringAsFixed(2)}%';
  }

  /// Hitung perubahan harga dari dua candle
  static double calculatePriceChange(CryptoCandle current, CryptoCandle previous) {
    return current.close - previous.close;
  }

  /// Hitung persentase perubahan harga
  static double calculatePercentChange(CryptoCandle current, CryptoCandle previous) {
    final change = calculatePriceChange(current, previous);
    return (change / previous.close) * 100;
  }

  /// Check apakah perubahan harga positif
  static bool isPriceChangePositive(double change) {
    return change >= 0;
  }
}

/// Helper class untuk mendapatkan DateTime dari berbagai format CryptoCandle
class CandleDateTimeHelper {
  CandleDateTimeHelper._();

  /// Mencoba mendapatkan DateTime dari candle dengan berbagai field names
  /// 
  /// Tries: timestamp, dateTime, openTime, date
  /// Fallback: DateTime.now()
  static DateTime getDateTime(CryptoCandle candle) {
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
            // Fallback ke current time jika semua gagal
            return DateTime.now();
          }
        }
      }
    }
  }

  /// Get timestamp dalam milliseconds
  static int getTimestamp(CryptoCandle candle) {
    return getDateTime(candle).millisecondsSinceEpoch;
  }

  /// Check apakah candle dalam rentang waktu tertentu
  static bool isWithinRange(CryptoCandle candle, DateTime start, DateTime end) {
    final candleTime = getDateTime(candle);
    return candleTime.isAfter(start) && candleTime.isBefore(end);
  }
}

/// Helper class untuk kalkulasi price range dari candles
class PriceRangeHelper {
  PriceRangeHelper._();

  /// Dapatkan harga minimum dari list candles
  static double getMinPrice(List<CryptoCandle> candles) {
    if (candles.isEmpty) return 0;
    return candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
  }

  /// Dapatkan harga maksimum dari list candles
  static double getMaxPrice(List<CryptoCandle> candles) {
    if (candles.isEmpty) return 0;
    return candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
  }

  /// Dapatkan range harga (max - min)
  static double getPriceRange(List<CryptoCandle> candles) {
    return getMaxPrice(candles) - getMinPrice(candles);
  }

  /// Dapatkan harga rata-rata
  static double getAveragePrice(List<CryptoCandle> candles) {
    if (candles.isEmpty) return 0;
    final sum = candles.fold<double>(0, (sum, c) => sum + c.close);
    return sum / candles.length;
  }

  /// Dapatkan volume maksimum
  static double getMaxVolume(List<CryptoCandle> candles) {
    if (candles.isEmpty) return 0;
    return candles.map((c) => c.volume).reduce((a, b) => a > b ? a : b);
  }

  /// Dapatkan total volume
  static double getTotalVolume(List<CryptoCandle> candles) {
    if (candles.isEmpty) return 0;
    return candles.fold<double>(0, (sum, c) => sum + c.volume);
  }
}

/// Helper class untuk chart interaction calculations
class ChartInteractionHelper {
  ChartInteractionHelper._();

  /// Clamp scale value antara min dan max
  static double clampScale(double scale, {double min = 0.3, double max = 5.0}) {
    return scale.clamp(min, max);
  }

  /// Hitung scale ratio untuk zoom interaction
  static double calculateScaleRatio(double newScale, double oldScale) {
    return newScale / oldScale;
  }

  /// Hitung adjusted offset setelah zoom
  static Offset calculateZoomOffset({
    required double focalPoint,
    required double currentOffsetX,
    required double scaleRatio,
  }) {
    return Offset(
      focalPoint - (focalPoint - currentOffsetX) * scaleRatio,
      0,
    );
  }

  /// Hitung pan offset
  static Offset calculatePanOffset({
    required Offset currentOffset,
    required Offset delta,
  }) {
    return Offset(
      currentOffset.dx + delta.dx,
      0,
    );
  }

  /// Check apakah scale berubah signifikan
  static bool isScaleChanged(double scale, {double threshold = 0.01}) {
    return (scale - 1.0).abs() > threshold;
  }

  /// Hitung candle index dari posisi tap
  static int? getCandleIndexFromPosition({
    required Offset position,
    required double chartWidth,
    required int candleCount,
    required double scale,
    required Offset offset,
  }) {
    if (candleCount == 0) return null;
    
    final adjustedX = (position.dx - offset.dx) / scale;
    final candleWidth = chartWidth / candleCount;
    final index = (adjustedX / candleWidth).floor();
    
    if (index >= 0 && index < candleCount) {
      return index;
    }
    
    return null;
  }
}

/// Helper class untuk style dan theming
class StyleHelper {
  StyleHelper._();

  /// Buat BoxDecoration dengan gradient untuk active state
  static BoxDecoration createActiveDecoration({
    required Color primaryColor,
    required Color secondaryColor,
    required double borderRadius,
    double primaryOpacity = 0.2,
    double secondaryOpacity = 0.1,
    double shadowBlur = 8.0,
    double shadowOpacity = 0.2,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          primaryColor.withOpacity(primaryOpacity),
          secondaryColor.withOpacity(secondaryOpacity),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(
        color: primaryColor,
        width: 1.5,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withOpacity(shadowOpacity),
          blurRadius: shadowBlur,
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// Buat BoxDecoration untuk inactive state
  static BoxDecoration createInactiveDecoration({
    required Color backgroundColor,
    required Color borderColor,
    required double borderRadius,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      border: Border.all(
        color: borderColor,
        width: 1.5,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  /// Buat TextStyle dengan conditional color
  static TextStyle createButtonTextStyle({
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    double fontSize = 11,
    FontWeight? fontWeight,
    double letterSpacing = 0.5,
  }) {
    return TextStyle(
      color: isActive ? activeColor : inactiveColor,
      fontSize: fontSize,
      fontWeight: fontWeight ?? (isActive ? FontWeight.bold : FontWeight.w600),
      letterSpacing: letterSpacing,
    );
  }
}

/// Helper class untuk validasi data
class DataValidator {
  DataValidator._();

  /// Check apakah list candles valid dan tidak kosong
  static bool isCandlesValid(List<CryptoCandle>? candles) {
    return candles != null && candles.isNotEmpty;
  }

  /// Check apakah ticker valid
  static bool isTickerValid(String? ticker) {
    return ticker != null && ticker.isNotEmpty;
  }

  /// Check apakah interval valid
  static bool isIntervalValid(String? interval) {
    return interval != null && interval.isNotEmpty;
  }

  /// Check apakah index dalam range
  static bool isIndexInRange(int? index, List list) {
    if (index == null) return false;
    return index >= 0 && index < list.length;
  }
}

/// Helper class untuk konversi dan parsing
class ConversionHelper {
  ConversionHelper._();

  /// Convert ticker ke display name (remove -USDT)
  static String tickerToDisplayName(String ticker) {
    return ticker.replaceAll('-USDT', '');
  }

  /// Convert ticker ke trading pair format (BTC/USDT)
  static String tickerToTradingPair(String ticker) {
    return ticker.replaceAll('-', '/');
  }

  /// Get coin symbol (first letter)
  static String getCoinSymbol(String ticker) {
    final coinName = tickerToDisplayName(ticker);
    return coinName.isNotEmpty ? coinName.substring(0, 1) : '?';
  }

  /// Parse opacity dari hexadecimal
  static Color colorWithOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
}

/// Helper class untuk menu context
class MenuHelper {
  MenuHelper._();

  /// Create menu item untuk context menu
  static PopupMenuItem<T> createMenuItem<T>({
    required T value,
    required IconData icon,
    required String text,
    required Color iconColor,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return PopupMenuItem<T>(
      value: value,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// Hitung position untuk context menu
  static RelativeRect calculateMenuPosition(
    Offset globalPosition,
    Size overlaySize,
  ) {
    return RelativeRect.fromRect(
      globalPosition & const Size(40, 40),
      Offset.zero & overlaySize,
    );
  }
}

/// Helper class untuk loading state management
class LoadingStateHelper {
  LoadingStateHelper._();

  /// Create loading widget dengan custom style
  static Widget createLoadingWidget({
    required Color color,
    required String message,
    required Color textColor,
    double strokeWidth = 3.0,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: color,
            strokeWidth: strokeWidth,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Create error message
  static String createErrorMessage(String ticker, String interval, String error) {
    return '⚠️ Error $ticker $interval: $error';
  }
}

/// Helper class untuk animation dan transitions
class AnimationHelper {
  AnimationHelper._();

  /// Standard duration untuk crosshair hide delay
  static const Duration crosshairHideDelay = Duration(milliseconds: 100);

  /// Standard duration untuk animations
  static const Duration standardDuration = Duration(milliseconds: 200);
  
  /// Fast animation duration
  static const Duration fastDuration = Duration(milliseconds: 100);
  
  /// Slow animation duration
  static const Duration slowDuration = Duration(milliseconds: 300);

  /// Create delayed callback
  static void delayedCallback({
    required Duration delay,
    required VoidCallback callback,
  }) {
    Future.delayed(delay, callback);
  }
}

/// Helper class untuk geometry calculations
class GeometryHelper {
  GeometryHelper._();

  /// Hitung distance antara dua points
  static double distanceBetween(Offset point1, Offset point2) {
    final dx = point2.dx - point1.dx;
    final dy = point2.dy - point1.dy;
    return (dx * dx + dy * dy);
  }

  /// Check apakah point dalam radius dari target
  static bool isPointNear(
    Offset point,
    Offset target, {
    double radius = 20.0,
  }) {
    return distanceBetween(point, target) <= radius * radius;
  }

  /// Clamp offset dalam boundaries
  static Offset clampOffset(
    Offset offset, {
    required Size chartSize,
  }) {
    return Offset(
      offset.dx.clamp(0, chartSize.width),
      offset.dy.clamp(0, chartSize.height),
    );
  }
}