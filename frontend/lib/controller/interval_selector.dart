import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Helper class untuk convert interval ke symbol
class IntervalSymbols {
  static String getSymbol(String interval) {
    final symbols = {
      '1m': '1m',
      '3m': '3m',
      '5m': '5m',
      '15m': '15m',
      '30m': '30m',
      '1h': '1H',
      '2h': '2H',
      '4h': '4H',
      '6h': '6H',
      '12h': '12H',
      '1d': '1D',
      '3d': '3D',
      '1w': '1W',
      '1M': '1M',
    };
    return symbols[interval] ?? interval;
  }
}

/// Interval Selector Widget
/// 
/// Horizontal scrollable selector untuk memilih timeframe/interval chart.
/// 
/// Features:
/// - Horizontal scrollable list
/// - Visual feedback untuk selected interval
/// - Gradient & glow effect saat selected
/// - Auto-scroll ke selected item
/// - Custom colors support
/// - Tooltip support
/// - Grouped intervals (optional)
/// - Loading state support
class IntervalSelector extends StatefulWidget {
  /// Currently selected interval
  final String selectedInterval;
  
  /// List of available intervals
  final List<String>? availableIntervals;
  
  /// Callback when interval changes
  final ValueChanged<String> onChanged;
  
  /// Custom height (default: 36)
  final double? height;
  
  /// Enable tooltips showing full interval name
  final bool showTooltips;
  
  /// Custom background color
  final Color? backgroundColor;
  
  /// Custom border color
  final Color? borderColor;
  
  /// Custom selected color (gradient)
  final Color? selectedColor;
  
  /// Custom unselected text color
  final Color? unselectedColor;
  
  /// Enable auto-scroll to selected item
  final bool autoScrollToSelected;
  
  /// Loading state (shows skeleton)
  final bool isLoading;
  
  /// Enable haptic feedback
  final bool enableHaptic;
  
  /// Group intervals by category (minutes, hours, days)
  final bool groupIntervals;
  
  /// Custom padding
  final EdgeInsets? padding;
  
  const IntervalSelector({
    Key? key,
    required this.selectedInterval,
    required this.onChanged,
    this.availableIntervals,
    this.height,
    this.showTooltips = false,
    this.backgroundColor,
    this.borderColor,
    this.selectedColor,
    this.unselectedColor,
    this.autoScrollToSelected = true,
    this.isLoading = false,
    this.enableHaptic = true,
    this.groupIntervals = false,
    this.padding,
  }) : super(key: key);

  @override
  State<IntervalSelector> createState() => _IntervalSelectorState();
}

class _IntervalSelectorState extends State<IntervalSelector> {
  late ScrollController _scrollController;
  
  // Getter untuk intervals dengan fallback ke default
  List<String> get _intervals => widget.availableIntervals ?? TimeframeConstants.common;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    if (widget.autoScrollToSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected();
      });
    }
  }
  
  @override
  void didUpdateWidget(IntervalSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.autoScrollToSelected && 
        oldWidget.selectedInterval != widget.selectedInterval) {
      _scrollToSelected();
    }
  }
  
  void _scrollToSelected() {
    final index = _intervals.indexOf(widget.selectedInterval);
    if (index != -1 && _scrollController.hasClients) {
      // Approximate item width: 50px per item
      final position = index * 50.0;
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingSkeleton();
    }
    
    if (widget.groupIntervals) {
      return _buildGroupedIntervals();
    }
    
    return _buildStandardSelector();
  }
  
  Widget _buildStandardSelector() {
    final bgColor = widget.backgroundColor ?? const Color(0xFF0F1419);
    final borderColor = widget.borderColor ?? const Color(0xFF1A2332);
    
    return Container(
      height: widget.height ?? 36,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: _intervals.length,
        itemBuilder: (context, index) {
          final interval = _intervals[index];
          return _buildIntervalButton(interval);
        },
      ),
    );
  }
  
  Widget _buildIntervalButton(String interval) {
    final isSelected = interval == widget.selectedInterval;
    final symbol = IntervalSymbols.getSymbol(interval);
    
    final selectedColor = widget.selectedColor ?? const Color(0xFF00FF88);
    final unselectedColor = widget.unselectedColor ?? const Color(0xFF4A5568);
    
    final button = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: GestureDetector(
        onTap: () {
          if (widget.enableHaptic) {
            // HapticFeedback.selectionClick();
          }
          widget.onChanged(interval);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: isSelected 
                ? LinearGradient(
                    colors: [
                      selectedColor.withOpacity(0.3),
                      selectedColor.withOpacity(0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? selectedColor : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: selectedColor.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ] : null,
          ),
          child: Center(
            child: Text(
              symbol,
              style: TextStyle(
                color: isSelected ? selectedColor : unselectedColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
    
    if (widget.showTooltips) {
      return Tooltip(
        message: _getIntervalLabel(interval),
        waitDuration: const Duration(milliseconds: 500),
        child: button,
      );
    }
    
    return button;
  }
  
  Widget _buildLoadingSkeleton() {
    return Container(
      height: widget.height ?? 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1419),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF1A2332),
          width: 1,
        ),
      ),
      child: Row(
        children: List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Container(
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildGroupedIntervals() {
    final groupsList = _groupIntervalsByType();
    
    return Container(
      height: widget.height ?? 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? const Color(0xFF0F1419),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.borderColor ?? const Color(0xFF1A2332),
          width: 1,
        ),
      ),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: groupsList.length,
        itemBuilder: (context, index) {
          final group = groupsList[index];
          return _buildIntervalGroup(group, groupsList);
        },
      ),
    );
  }
  
  Widget _buildIntervalGroup(Map<String, dynamic> group, List<Map<String, dynamic>> allGroups) {
    return Row(
      children: [
        // Group label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            group['label'],
            style: const TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Intervals in group
        ...group['intervals'].map<Widget>((interval) {
          return _buildIntervalButton(interval);
        }).toList(),
        // Divider
        if (group != allGroups.last)
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: const Color(0xFF1A2332),
          ),
      ],
    );
  }
  
  List<Map<String, dynamic>> _groupIntervalsByType() {
    final minutes = <String>[];
    final hours = <String>[];
    final days = <String>[];
    
    for (final interval in _intervals) {
      if (interval.contains('m')) {
        minutes.add(interval);
      } else if (interval.contains('h')) {
        hours.add(interval);
      } else {
        days.add(interval);
      }
    }
    
    final groupsList = <Map<String, dynamic>>[];
    
    if (minutes.isNotEmpty) {
      groupsList.add({'label': 'MIN', 'intervals': minutes});
    }
    if (hours.isNotEmpty) {
      groupsList.add({'label': 'HOUR', 'intervals': hours});
    }
    if (days.isNotEmpty) {
      groupsList.add({'label': 'DAY', 'intervals': days});
    }
    
    return groupsList;
  }
  
  String _getIntervalLabel(String interval) {
    final labels = {
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
      '1M': '1 Month',
    };
    
    return labels[interval] ?? interval;
  }
}

/// Preset Interval Groups
/// 
/// Common timeframe combinations untuk trading
class IntervalPresets {
  /// Scalping intervals (very short term)
  static const scalping = ['1m', '3m', '5m'];
  
  /// Day trading intervals
  static const dayTrading = ['5m', '15m', '30m', '1h'];
  
  /// Swing trading intervals
  static const swingTrading = ['1h', '4h', '1d'];
  
  /// Position trading intervals (long term)
  static const positionTrading = ['1d', '3d', '1w'];
  
  /// All common intervals
  static const all = [
    '1m', '3m', '5m', '15m', '30m',
    '1h', '2h', '4h', '6h', '12h',
    '1d', '3d', '1w'
  ];
  
  /// Minimal set (most popular)
  static const minimal = ['5m', '15m', '1h', '4h', '1d'];
}