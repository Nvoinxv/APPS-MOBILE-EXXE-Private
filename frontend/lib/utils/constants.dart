import 'package:flutter/material.dart';
import '../hooks/execute_hook.dart';

/// Konstanta warna untuk tema dark futuristic
class AppColors {
  AppColors._(); // Private constructor untuk prevent instantiation
  
  // Neon colors
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonGreenDark = Color(0xFF00CC6A);
  static const Color neonPink = Color(0xFFFF0066);
  static const Color neonPinkDark = Color(0xFFCC0052);
  static const Color neonCyan = Color(0xFF00FFFF);
  static const Color neonGold = Color(0xFFFFD700);
  
  // Background colors
  static const Color deepSpaceBlack = Color(0xFF0A0E17);
  static const Color darkBackground = Color(0xFF0F1419);
  static const Color darkBlueGray = Color(0xFF1A2332);
  
  // Text colors
  static const Color mutedGrayBlue = Color(0xFF8B93A7);
  static const Color textSecondary = Color(0xFF4A5568);
  
  // TradingView theme colors
  static const Color tvBullish = Color(0xFF26A69A);
  static const Color tvBearish = Color(0xFFEF5350);
  static const Color tvBackground = Color(0xFF1E222D);
  static const Color tvGrid = Color(0xFF2A2E39);
  static const Color tvText = Color(0xFFB2B5BE);
}

/// Konstanta untuk ukuran dan spacing
class AppSizes {
  AppSizes._();
  
  // Padding & Margin
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 12.0;
  static const double paddingLarge = 16.0;
  
  // Border radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 6.0;
  static const double radiusLarge = 8.0;
  
  // Icon sizes
  static const double iconSmall = 18.0;
  static const double iconMedium = 20.0;
  static const double iconLarge = 24.0;
  
  // Font sizes
  static const double fontTiny = 10.0;
  static const double fontSmall = 11.0;
  static const double fontMedium = 12.0;
  static const double fontRegular = 14.0;
  static const double fontLarge = 16.0;
  static const double fontXLarge = 20.0;
  static const double fontHuge = 28.0;
  
  // Chart specific
  static const double volumeBarHeight = 100.0;
  static const double intervalSelectorHeight = 36.0;
  static const double avatarSize = 32.0;
  
  // Border widths
  static const double borderThin = 1.0;
  static const double borderMedium = 1.5;
  static const double strokeThin = 1.2;
  static const double strokeMedium = 3.0;
}

/// Konstanta untuk interval waktu trading
class TimeframeConstants {
  TimeframeConstants._();
  
  // Common timeframes
  static const List<String> common = [
    '1m', '5m', '15m', '1h', '4h', '1d',
  ];
  
  // All available timeframes
  static const List<String> all = [
    '1m', '3m', '5m', '15m', '30m',
    '1h', '2h', '4h', '6h', '12h',
    '1d', '3d', '1w',
  ];
  
  // Interval display symbols
  static const Map<String, String> symbols = {
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
  
  // Interval labels
  static const Map<String, String> labels = {
    '1m': '1 Minute',
    '3m': '3 Minutes',
    '5m': '5 Minutes',
    '15m': '15 Minutes',
    '30m': '30 Minutes',
    '1h': '1 Hour',
    '2h': '2 Hours',
    '4h': '4 Hours',
    '6h': '6 Hours',
    '12h': '12 Hours',
    '1d': '1 Day',
    '3d': '3 Days',
    '1w': '1 Week',
  };
  
  /// Get display symbol for interval
  static String getSymbol(String interval) {
    return symbols[interval] ?? interval;
  }
  
  /// Get full label for interval
  static String getLabel(String interval) {
    return labels[interval] ?? interval;
  }
}

/// Konstanta untuk cryptocurrency pairs
class CryptoPairs {
  CryptoPairs._();
  
  // Major crypto pairs
  static const List<String> major = [
    'BTC-USDT',
    'ETH-USDT',
    'BNB-USDT',
    'XRP-USDT',
    'ADA-USDT',
    'DOGE-USDT',
    'SOL-USDT',
    'MATIC-USDT',
  ];
  
  // Extended list with more altcoins
  static const List<String> extended = [
    'BTC-USDT',
    'ETH-USDT',
    'BNB-USDT',
    'XRP-USDT',
    'ADA-USDT',
    'DOGE-USDT',
    'SOL-USDT',
    'MATIC-USDT',
    'DOT-USDT',
    'AVAX-USDT',
    'LINK-USDT',
    'UNI-USDT',
    'ATOM-USDT',
    'LTC-USDT',
  ];
  
  /// Convert ticker to display name (remove -USDT)
  static String toDisplayName(String ticker) {
    return ticker.replaceAll('-USDT', '');
  }
  
  /// Convert ticker to trading pair format (BTC/USDT)
  static String toTradingPair(String ticker) {
    return ticker.replaceAll('-', '/');
  }
  
  /// Get coin symbol (first letter)
  static String getCoinSymbol(String ticker) {
    final coinName = toDisplayName(ticker);
    return coinName.isNotEmpty ? coinName.substring(0, 1) : '?';
  }
}

/// Konstanta untuk chart zoom dan pan
class ChartInteractionConstants {
  ChartInteractionConstants._();
  
  // Zoom limits
  static const double minScale = 0.3;
  static const double maxScale = 5.0;
  static const double defaultScale = 1.0;
  
  // Scale sensitivity
  static const double scaleThreshold = 0.01;
  
  // Crosshair
  static const double crosshairStrokeWidth = 1.2;
  static const double crosshairOpacity = 0.8;
  
  // Delays (milliseconds)
  static const int crosshairHideDelay = 100;
  
  // Auto update interval (seconds)
  static const int autoUpdateInterval = 60;
}

/// Konstanta untuk control buttons
class ControlButtonConstants {
  ControlButtonConstants._();
  
  // Button labels with icons
  static const String volume = '📊 Volume';
  static const String grid = '⊞ Grid';
  static const String cross = '✛ Cross';
  static const String fibonacci = '📐 Fib';
  static const String reset = '↺ Reset';
  static const String riskRatio = 'R:R';
  
  // Mode icons
  static const String buyIcon = '📈';
  static const String sellIcon = '📉';
}

/// Konstanta untuk menu items
class MenuConstants {
  MenuConstants._();
  
  // Risk Ratio menu
  static const String switchMode = 'Switch to';
  static const String lock = 'Lock';
  static const String unlock = 'Unlock';
  static const String deleteRiskRatio = 'Delete Risk Ratio';
  
  // Fibonacci menu
  static const String lockFibonacci = 'Lock Fibonacci';
  static const String unlockFibonacci = 'Unlock Fibonacci';
  static const String deleteFibonacci = 'Delete Fibonacci';
  
  // Style settings
  static const String chartStyleSettings = 'Chart Style Settings';
  static const String presetThemes = 'Preset Themes';
}

/// Konstanta untuk preset themes
class ThemePresets {
  ThemePresets._();
  
  static const String tradingView = 'TradingView';
  static const String dark = 'Dark';
  static const String light = 'Light';
  static const String blue = 'Blue';
}

/// Konstanta untuk animasi dan shadows
class EffectConstants {
  EffectConstants._();
  
  // Shadow
  static const double shadowBlur = 8.0;
  static const double shadowSpread = 0.0;
  static const double shadowOpacity = 0.2;
  static const double shadowOpacityStrong = 0.3;
  
  // Gradient opacity
  static const double gradientOpacityPrimary = 0.3;
  static const double gradientOpacitySecondary = 0.2;
  static const double gradientOpacityLight = 0.1;
  
  // Border opacity
  static const double borderOpacity = 0.3;
  
  // Text opacity
  static const double textOpacityMedium = 0.6;
  static const double textOpacityLight = 0.7;
}

/// Konstanta untuk label candle info
class CandleLabels {
  CandleLabels._();
  
  static const String open = 'O';
  static const String high = 'H';
  static const String low = 'L';
  static const String close = 'C';
  static const String volume = 'V';
}

/// Konstanta untuk error messages
class ErrorMessages {
  ErrorMessages._();
  
  static const String errorPrefix = '⚠️ Error';
  static const String loadingPrefix = 'Loading';
  static const String allDataReady = '✅ All timeframes loaded';
}

/// Konstanta untuk default values
class DefaultValues {
  DefaultValues._();
  
  static const String defaultTicker = 'BTC-USDT';
  static const String defaultInterval = '15m';
  
  // Initial state
  static const bool showVolumeDefault = true;
  static const bool showGridDefault = true;
  static const bool showCrosshairDefault = true;
  static const bool isLoadingDefault = true;
}

/// Helper untuk mendapatkan gradient colors
class GradientHelper {
  GradientHelper._();
  
  /// Gradient untuk neon green (bullish)
  static LinearGradient greenGradient({
    double primaryOpacity = EffectConstants.gradientOpacityPrimary,
    double secondaryOpacity = EffectConstants.gradientOpacitySecondary,
  }) {
    return LinearGradient(
      colors: [
        AppColors.neonGreen.withOpacity(primaryOpacity),
        AppColors.neonGreenDark.withOpacity(secondaryOpacity),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Gradient untuk neon pink (bearish)
  static LinearGradient pinkGradient({
    double primaryOpacity = EffectConstants.gradientOpacityPrimary,
    double secondaryOpacity = EffectConstants.gradientOpacitySecondary,
  }) {
    return LinearGradient(
      colors: [
        AppColors.neonPink.withOpacity(primaryOpacity),
        AppColors.neonPinkDark.withOpacity(secondaryOpacity),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Gradient untuk background
  static LinearGradient backgroundGradient() {
    return const LinearGradient(
      colors: [
        AppColors.deepSpaceBlack,
        AppColors.darkBackground,
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }
}

/// Helper untuk box shadows
class ShadowHelper {
  ShadowHelper._();
  
  /// Shadow untuk neon green
  static List<BoxShadow> greenShadow({
    double opacity = EffectConstants.shadowOpacity,
  }) {
    return [
      BoxShadow(
        color: AppColors.neonGreen.withOpacity(opacity),
        blurRadius: EffectConstants.shadowBlur,
        spreadRadius: EffectConstants.shadowSpread,
      ),
    ];
  }
  
  /// Shadow untuk neon pink
  static List<BoxShadow> pinkShadow({
    double opacity = EffectConstants.shadowOpacity,
  }) {
    return [
      BoxShadow(
        color: AppColors.neonPink.withOpacity(opacity),
        blurRadius: EffectConstants.shadowBlur,
        spreadRadius: EffectConstants.shadowSpread,
      ),
    ];
  }
}

/// Konstanta untuk API endpoints
class ApiConstants {
  ApiConstants._();

  // Ganti dengan IP/domain backend lo
  static const String baseUrl = 'http://127.0.0.1:8080'; // emulator Android
  // static const String baseUrl = 'http://localhost:8000'; // web/desktop
  // static const String baseUrl = 'https://api.exxelab.com'; // production

  static const String execute = '$baseUrl/execute';
  static const String health  = '$baseUrl/health';
}