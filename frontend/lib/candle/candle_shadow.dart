import 'package:flutter/material.dart';
import '../candlestick_chart.dart';
import '../hooks/crypto_data_hook.dart';

class ShadowCandlestickDemo extends StatefulWidget {
  const ShadowCandlestickDemo({Key? key}) : super(key: key);

  @override
  State<ShadowCandlestickDemo> createState() => _ShadowCandlestickDemoState();
}

class _ShadowCandlestickDemoState extends State<ShadowCandlestickDemo> {
  late CryptoDataHook cryptoHook;
  List<CryptoCandle> candles = [];
  bool showShadow = true; // Shadow ON by default
  
  // Shadow styles
  CandlestickStyle normalStyle = CandlestickStyle(
    shadowColor: Colors.black, // Default black shadow
  );
  
  CandlestickStyle coloredShadowStyle = CandlestickStyle(
    shadowColor: Colors.blue.withOpacity(0.5), // Colored shadow
  );
  
  CandlestickStyle glowStyle = CandlestickStyle(
    bullishColor: Colors.green,
    bearishColor: Colors.red,
    shadowColor: Colors.white.withOpacity(0.3), // White glow effect
    backgroundColor: Colors.black,
  );
  
  String selectedStyle = 'Normal';
  
  @override
  void initState() {
    super.initState();
    
    cryptoHook = CryptoDataHook(
      tickers: ['BTC-USDT'],
      interval: '15m',
      autoUpdateInterval: 60,
    );
    
    cryptoHook.onDataUpdate = (ticker, candlesData) {
      if (mounted) {
        setState(() => candles = candlesData);
      }
    };
    
    cryptoHook.startAdaptiveUpdate();
  }
  
  @override
  void dispose() {
    cryptoHook.dispose();
    super.dispose();
  }
  
  CandlestickStyle get currentStyle {
    switch (selectedStyle) {
      case 'Normal':
        return normalStyle;
      case 'Colored':
        return coloredShadowStyle;
      case 'Glow':
        return glowStyle;
      default:
        return normalStyle;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: currentStyle.backgroundColor,
      appBar: AppBar(
        backgroundColor: currentStyle.backgroundColor,
        title: Text(
          'Shadow Mode Demo',
          style: TextStyle(color: currentStyle.textColor),
        ),
        actions: [
          // Shadow toggle
          IconButton(
            icon: Icon(
              showShadow ? Icons.brightness_7 : Icons.brightness_4,
              color: currentStyle.textColor,
            ),
            onPressed: () {
              setState(() => showShadow = !showShadow);
            },
            tooltip: showShadow ? 'Shadow ON' : 'Shadow OFF',
          ),
        ],
      ),
      body: candles.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Shadow info banner
                _buildShadowInfo(),
                
                // Chart
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CandlestickChart(
                      candles: candles,
                      style: currentStyle,
                      showShadow: showShadow,
                      showVolume: true,
                      showGrid: true,
                    ),
                  ),
                ),
                
                // Style selector
                _buildStyleSelector(),
              ],
            ),
    );
  }
  
  Widget _buildShadowInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: currentStyle.gridColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            showShadow ? Icons.check_circle : Icons.cancel,
            color: showShadow ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              showShadow 
                  ? 'Shadow Mode: ENABLED - Gaussian blur with 3-layer depth'
                  : 'Shadow Mode: DISABLED - Normal candles',
              style: TextStyle(
                color: currentStyle.textColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStyleSelector() {
    final styles = ['Normal', 'Colored', 'Glow'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: currentStyle.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shadow Style:',
            style: TextStyle(
              color: currentStyle.textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: styles.map((style) {
              final isSelected = selectedStyle == style;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => selectedStyle = style);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected 
                          ? currentStyle.bullishColor 
                          : currentStyle.gridColor,
                      foregroundColor: isSelected 
                          ? Colors.white 
                          : currentStyle.textColor,
                    ),
                    child: Text(style),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          _buildStyleDescription(),
        ],
      ),
    );
  }
  
  Widget _buildStyleDescription() {
    String description;
    switch (selectedStyle) {
      case 'Normal':
        description = '🖤 Black shadow - Classic depth effect';
        break;
      case 'Colored':
        description = '💙 Blue shadow - Modern colored effect';
        break;
      case 'Glow':
        description = '✨ White glow - Neon glow effect';
        break;
      default:
        description = '';
    }
    
    return Text(
      description,
      style: TextStyle(
        color: currentStyle.textColor.withOpacity(0.7),
        fontSize: 12,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

// ===== COMPARISON VIEW: WITH VS WITHOUT SHADOW =====

class ShadowComparisonView extends StatefulWidget {
  const ShadowComparisonView({Key? key}) : super(key: key);

  @override
  State<ShadowComparisonView> createState() => _ShadowComparisonViewState();
}

class _ShadowComparisonViewState extends State<ShadowComparisonView> {
  late CryptoDataHook cryptoHook;
  List<CryptoCandle> candles = [];
  
  final style = CandlestickStyle(
    bullishColor: Color(0xFF26A69A),
    bearishColor: Color(0xFFEF5350),
    backgroundColor: Color(0xFF1E222D),
    gridColor: Color(0xFF2A2E39),
    textColor: Color(0xFFB2B5BE),
    shadowColor: Colors.black,
  );
  
  @override
  void initState() {
    super.initState();
    
    cryptoHook = CryptoDataHook(
      tickers: ['BTC-USDT'],
      interval: '15m',
      autoUpdateInterval: 60,
    );
    
    cryptoHook.onDataUpdate = (ticker, candlesData) {
      if (mounted) {
        setState(() => candles = candlesData);
      }
    };
    
    cryptoHook.startAdaptiveUpdate();
  }
  
  @override
  void dispose() {
    cryptoHook.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: style.backgroundColor,
      appBar: AppBar(
        backgroundColor: style.backgroundColor,
        title: Text(
          'Shadow Comparison',
          style: TextStyle(color: style.textColor),
        ),
      ),
      body: candles.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Without Shadow
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: style.gridColor,
                        child: Text(
                          'WITHOUT SHADOW - Normal',
                          style: TextStyle(
                            color: style.textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CandlestickChart(
                            candles: candles,
                            style: style,
                            showShadow: false, // OFF
                            showVolume: false,
                            showGrid: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Divider(color: style.gridColor, height: 2),
                
                // With Shadow
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: style.gridColor,
                        child: Text(
                          'WITH SHADOW - Gaussian Blur',
                          style: TextStyle(
                            color: style.textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CandlestickChart(
                            candles: candles,
                            style: style,
                            showShadow: true, // ON
                            showVolume: false,
                            showGrid: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ===== CUSTOM SHADOW SETTINGS =====

class CustomShadowSettings extends StatefulWidget {
  const CustomShadowSettings({Key? key}) : super(key: key);

  @override
  State<CustomShadowSettings> createState() => _CustomShadowSettingsState();
}

class _CustomShadowSettingsState extends State<CustomShadowSettings> {
  Color shadowColor = Colors.black;
  bool showShadow = true;
  
  final List<Color> shadowPresets = [
    Colors.black,
    Colors.grey,
    Colors.blue,
    Colors.purple,
    Colors.red,
    Colors.green,
    Colors.white,
  ];
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Shadow Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          SwitchListTile(
            title: Text('Enable Shadow'),
            value: showShadow,
            onChanged: (value) {
              setState(() => showShadow = value);
            },
          ),
          
          const SizedBox(height: 16),
          
          Text('Shadow Color:', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: shadowPresets.map((color) {
              final isSelected = shadowColor.value == color.value;
              return InkWell(
                onTap: () {
                  setState(() => shadowColor = color);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey,
                      width: isSelected ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Shadow Info:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            '• 3-layer Gaussian blur for depth\n'
            '• 3px offset for natural shadow\n'
            '• Decreasing opacity per layer\n'
            '• Smooth and subtle effect',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
