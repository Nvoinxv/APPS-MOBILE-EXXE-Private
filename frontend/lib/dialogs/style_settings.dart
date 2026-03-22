import 'package:flutter/material.dart';
import '../candle/candle_normal.dart';

/// Bottom sheet untuk mengatur style/theme chart
/// 
/// Memungkinkan user untuk memilih dari preset themes seperti:
/// - TradingView (default professional theme)
/// - Dark (simple dark theme)
/// - Light (bright theme untuk siang hari)
/// - Blue (alternative dark blue theme)
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
            _buildHeader(),
            const SizedBox(height: 20),
            _buildThemesSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  /// Header dengan title dan close button
  Widget _buildHeader() {
    return Row(
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
    );
  }
  
  /// Section untuk preset themes
  Widget _buildThemesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preset Themes',
          style: TextStyle(
            color: style.textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildThemeButton('TradingView', StyleThemes.tradingView()),
            _buildThemeButton('Dark', StyleThemes.dark()),
            _buildThemeButton('Light', StyleThemes.light()),
            _buildThemeButton('Blue', StyleThemes.blue()),
            _buildThemeButton('Neon', StyleThemes.neonFuturistic()),
          ],
        ),
      ],
    );
  }
  
  /// Button untuk memilih theme
  Widget _buildThemeButton(String label, CandlestickStyle theme) {
    final isCurrentTheme = _isCurrentTheme(theme);
    
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isCurrentTheme
              ? BorderSide(
                  color: theme.bullishColor,
                  width: 2,
                )
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color preview circles
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildColorCircle(theme.bullishColor),
              const SizedBox(width: 4),
              _buildColorCircle(theme.bearishColor),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: isCurrentTheme ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isCurrentTheme) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.check_circle,
              size: 16,
              color: theme.bullishColor,
            ),
          ],
        ],
      ),
    );
  }
  
  /// Build color preview circle
  Widget _buildColorCircle(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
    );
  }
  
  /// Check if theme is currently selected
  bool _isCurrentTheme(CandlestickStyle theme) {
    return style.bullishColor == theme.bullishColor &&
           style.bearishColor == theme.bearishColor &&
           style.backgroundColor == theme.backgroundColor;
  }
}

/// Class untuk menyimpan preset themes
class StyleThemes {
  StyleThemes._();
  
  /// TradingView classic theme
  static CandlestickStyle tradingView() {
    return CandlestickStyle(
      bullishColor: const Color(0xFF26A69A),
      bearishColor: const Color(0xFFEF5350),
      backgroundColor: const Color(0xFF1E222D),
      gridColor: const Color(0xFF2A2E39),
      textColor: const Color(0xFFB2B5BE),
      crosshairColor: const Color(0xFF26A69A).withOpacity(0.3),
      selectedColor: const Color(0xFF26A69A),
    );
  }
  
  /// Simple dark theme
  static CandlestickStyle dark() {
    return CandlestickStyle(
      bullishColor: Colors.green,
      bearishColor: Colors.red,
      backgroundColor: Colors.black,
      gridColor: const Color(0xFF2D2D2D),
      textColor: Colors.white70,
      crosshairColor: Colors.green.withOpacity(0.3),
      selectedColor: Colors.green,
    );
  }
  
  /// Light theme untuk siang hari
  static CandlestickStyle light() {
    return CandlestickStyle(
      bullishColor: const Color(0xFF26A69A),
      bearishColor: const Color(0xFFEF5350),
      backgroundColor: Colors.white,
      gridColor: const Color(0xFFE0E0E0),
      textColor: Colors.black87,
      crosshairColor: const Color(0xFF26A69A).withOpacity(0.3),
      selectedColor: const Color(0xFF26A69A),
    );
  }
  
  /// Blue theme
  static CandlestickStyle blue() {
    return CandlestickStyle(
      bullishColor: Colors.blue,
      bearishColor: Colors.orange,
      backgroundColor: const Color(0xFF0D1B2A),
      gridColor: const Color(0xFF1B263B),
      textColor: const Color(0xFFE0E1DD),
      crosshairColor: Colors.blue.withOpacity(0.3),
      selectedColor: Colors.blue,
    );
  }
  
  /// Neon futuristic theme (default)
  static CandlestickStyle neonFuturistic() {
    return CandlestickStyle(
      bullishColor: const Color(0xFF00FF88), // Neon green
      bearishColor: const Color(0xFFFF0066), // Neon pink/red
      backgroundColor: const Color(0xFF0A0E17), // Deep space black
      gridColor: const Color(0xFF1A2332), // Dark blue-gray
      textColor: const Color(0xFF8B93A7), // Muted gray-blue
      crosshairColor: const Color(0xFF00FF88).withOpacity(0.3),
      selectedColor: const Color(0xFF00FFFF), // Cyan highlight
    );
  }
  
  /// Purple haze theme
  static CandlestickStyle purpleHaze() {
    return CandlestickStyle(
      bullishColor: const Color(0xFF9D4EDD),
      bearishColor: const Color(0xFFFF006E),
      backgroundColor: const Color(0xFF10002B),
      gridColor: const Color(0xFF240046),
      textColor: const Color(0xFFC77DFF),
      crosshairColor: const Color(0xFF9D4EDD).withOpacity(0.3),
      selectedColor: const Color(0xFF9D4EDD),
    );
  }
  
  /// Matrix green theme
  static CandlestickStyle matrix() {
    return CandlestickStyle(
      bullishColor: const Color(0xFF00FF41),
      bearishColor: const Color(0xFFFF0040),
      backgroundColor: const Color(0xFF0D0208),
      gridColor: const Color(0xFF003B00),
      textColor: const Color(0xFF008F11),
      crosshairColor: const Color(0xFF00FF41).withOpacity(0.3),
      selectedColor: const Color(0xFF00FF41),
    );
  }
  
  /// Ocean theme
  static CandlestickStyle ocean() {
    return CandlestickStyle(
      bullishColor: const Color(0xFF06FFA5),
      bearishColor: const Color(0xFFFF5F6D),
      backgroundColor: const Color(0xFF011627),
      gridColor: const Color(0xFF1F4788),
      textColor: const Color(0xFFB8C5D6),
      crosshairColor: const Color(0xFF06FFA5).withOpacity(0.3),
      selectedColor: const Color(0xFF06FFA5),
    );
  }
  
  /// Sunset theme
  static CandlestickStyle sunset() {
    return CandlestickStyle(
      bullishColor: const Color(0xFFFFC837),
      bearishColor: const Color(0xFFFF6B35),
      backgroundColor: const Color(0xFF1A1A2E),
      gridColor: const Color(0xFF16213E),
      textColor: const Color(0xFFEEEEEE),
      crosshairColor: const Color(0xFFFFC837).withOpacity(0.3),
      selectedColor: const Color(0xFFFFC837),
    );
  }
  
  /// Get all available themes
  static List<ThemeOption> getAllThemes() {
    return [
      ThemeOption(name: 'Neon', theme: neonFuturistic()),
      ThemeOption(name: 'TradingView', theme: tradingView()),
      ThemeOption(name: 'Dark', theme: dark()),
      ThemeOption(name: 'Light', theme: light()),
      ThemeOption(name: 'Blue', theme: blue()),
      ThemeOption(name: 'Purple', theme: purpleHaze()),
      ThemeOption(name: 'Matrix', theme: matrix()),
      ThemeOption(name: 'Ocean', theme: ocean()),
      ThemeOption(name: 'Sunset', theme: sunset()),
    ];
  }
}

/// Model untuk theme option
class ThemeOption {
  final String name;
  final CandlestickStyle theme;
  
  const ThemeOption({
    required this.name,
    required this.theme,
  });
}

/// Extension untuk StyleSettingsSheet
extension StyleSettingsSheetExtension on BuildContext {
  /// Show style settings bottom sheet
  void showStyleSettings({
    required CandlestickStyle currentStyle,
    required Function(CandlestickStyle) onStyleChanged,
  }) {
    showModalBottomSheet(
      context: this,
      backgroundColor: currentStyle.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (context) => StyleSettingsSheet(
        currentStyle: currentStyle,
        onStyleChanged: onStyleChanged,
      ),
    );
  }
}