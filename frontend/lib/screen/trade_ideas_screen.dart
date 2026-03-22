import 'package:flutter/material.dart';
import '../hooks/trade_ideas_hook.dart';
import '../style/apps_colors_trade_ideas.dart';

class TradeIdeasScreen extends StatefulWidget {
  final String token;
  
  const TradeIdeasScreen({
    super.key,
    required this.token,
  });
  
  @override
  State<TradeIdeasScreen> createState() => _TradeIdeasScreenState();
}

class _TradeIdeasScreenState extends State<TradeIdeasScreen> {
  List<Map<String, dynamic>> tradeIdeasCards = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTradeIdeasData();
  }

  Future<void> _loadTradeIdeasData() async {
    setState(() => isLoading = true);
    
    final result = await Trade_Ideas_Hook.GetAllTradeIdeas(token: widget.token);
    
    if (result['success'] == true) {
      setState(() {
        tradeIdeasCards = List<Map<String, dynamic>>.from(result['data']);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message'] ?? result['error']}'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TradeIdeasColorStyle.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.fromLTRB(48, 32, 48, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title
                  Text(
                    'Trade Ideas',
                    style: TradeIdeasColorStyle.sectionTitleStyle,
                  ),

                  // Add Button
                  _buildAddButton(),
                ],
              ),
            ),

            // Cards Grid
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: TradeIdeasColorStyle.greenPrimary, // ✅ FIXED
                        strokeWidth: 3,
                      ),
                    )
                  : tradeIdeasCards.isEmpty
                      ? _buildEmptyState()
                      : _buildCardsGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/upload_trade_ideas',
              arguments: widget.token,
            );
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text(
            'Add Trade Idea',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: TradeIdeasColorStyle.addButtonBackground,
            foregroundColor: TradeIdeasColorStyle.addButtonText,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.black.withOpacity(0.1);
                }
                if (states.contains(WidgetState.pressed)) {
                  return Colors.black.withOpacity(0.2);
                }
                return null;
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 64,
            color: TradeIdeasColorStyle.subtitleText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No trade ideas available',
            style: TextStyle(
              color: TradeIdeasColorStyle.subtitleText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Add Trade Idea" to create your first entry',
            style: TextStyle(
              color: TradeIdeasColorStyle.sourceText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 48, 32),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 0.72,
        ),
        itemCount: tradeIdeasCards.length,
        itemBuilder: (context, index) {
          final card = tradeIdeasCards[index];
          return _TradeIdeasCard(
            index: index,
            tradeIdea: card['Trade_idea'] ?? '',
            tipeTrade: card['Tipe_trade'] ?? '',
            aktivasi: card['Aktivasi'] ?? '',
            entry: card['Entry']?.toDouble() ?? 0.0,
            stoploss: card['Stoploss']?.toDouble() ?? 0.0,
            target: card['Target']?.toDouble() ?? 0.0,
            status: card['Status'] ?? false,
            date: card['Date'] ?? '',
            onTap: () {
              // TODO: Navigate to detail page
            },
          );
        },
      ),
    );
  }
}

class _TradeIdeasCard extends StatefulWidget {
  final int index;
  final String tradeIdea;
  final String tipeTrade;
  final String aktivasi;
  final double entry;
  final double stoploss;
  final double target;
  final bool status;
  final String date;
  final VoidCallback onTap;

  const _TradeIdeasCard({
    required this.index,
    required this.tradeIdea,
    required this.tipeTrade,
    required this.aktivasi,
    required this.entry,
    required this.stoploss,
    required this.target,
    required this.status,
    required this.date,
    required this.onTap,
  });

  @override
  State<_TradeIdeasCard> createState() => _TradeIdeasCardState();
}

class _TradeIdeasCardState extends State<_TradeIdeasCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translate(0.0, isHovered ? -8.0 : 0.0),
          decoration: tradeIdeasCardTheme.cardDecoration(
            index: widget.index,
            isHovered: isHovered,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chart/Visual Section
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: TradeIdeasColorStyle.backgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Trade Chart Visualization
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: _TradeChartVisual(
                          entry: widget.entry,
                          stoploss: widget.stoploss,
                          target: widget.target,
                          tipeTrade: widget.tipeTrade,
                        ),
                      ),
                      
                      // Gradient Overlay
                      Container(
                        decoration: tradeIdeasCardTheme.textOverlayDecoration(),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Section
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Trade Ideas Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: tradeIdeasCardTheme.tradeIdeasBadgeDecoration(),
                            child: Text(
                              'TRADE IDEAS',
                              style: TradeIdeasColorStyle.badgeTextStyle,
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Trade Idea Title
                          Text(
                            widget.tradeIdea,
                            style: TradeIdeasColorStyle.tradeIdeasTitleStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      // Trade Info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.tipeTrade.toUpperCase(),
                                style: TradeIdeasColorStyle.tradeIdeasSubtitleStyle,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.status 
                                      ? TradeIdeasColorStyle.greenPrimary.withOpacity(0.2) // ✅ FIXED
                                      : TradeIdeasColorStyle.sourceText.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.status ? 'ACTIVE' : 'CLOSED',
                                  style: TextStyle(
                                    color: widget.status 
                                        ? TradeIdeasColorStyle.greenPrimary // ✅ FIXED
                                        : TradeIdeasColorStyle.sourceText,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Entry: ${widget.entry} • TP: ${widget.target}',
                            style: TradeIdeasColorStyle.tradeIdeasSourceStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TradeChartVisual extends StatelessWidget {
  final double entry;
  final double stoploss;
  final double target;
  final String tipeTrade;

  const _TradeChartVisual({
    required this.entry,
    required this.stoploss,
    required this.target,
    required this.tipeTrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TradeIdeasColorStyle.backgroundColor,
      padding: const EdgeInsets.all(24),
      child: CustomPaint(
        painter: _TradeChartPainter(
          entry: entry,
          stoploss: stoploss,
          target: target,
          isBuy: tipeTrade.toLowerCase().contains('buy'),
        ),
        child: Container(),
      ),
    );
  }
}

class _TradeChartPainter extends CustomPainter {
  final double entry;
  final double stoploss;
  final double target;
  final bool isBuy;

  _TradeChartPainter({
    required this.entry,
    required this.stoploss,
    required this.target,
    required this.isBuy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid lines
    final gridPaint = Paint()
      ..color = TradeIdeasColorStyle.searchBorder
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Calculate price positions
    final maxPrice = [entry, stoploss, target].reduce((a, b) => a > b ? a : b);
    final minPrice = [entry, stoploss, target].reduce((a, b) => a < b ? a : b);
    final priceRange = maxPrice - minPrice;

    double getY(double price) {
      if (priceRange == 0) return size.height * 0.5;
      return size.height - ((price - minPrice) / priceRange * size.height * 0.8) - size.height * 0.1;
    }

    // Draw candlestick chart
    final candlePaint = Paint()
      ..color = TradeIdeasColorStyle.greenLight
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final candleWidth = size.width / 8;

    for (int i = 0; i < 7; i++) {
      final x = candleWidth * i + candleWidth / 2;
      final baseY = getY(entry);
      final variation = (i * 10 % 30 - 15).toDouble();
      
      // Draw candle
      canvas.drawLine(
        Offset(x, baseY - 15 + variation),
        Offset(x, baseY + 15 + variation),
        candlePaint,
      );
      
      // Draw body
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, baseY + variation),
          width: 8,
          height: 20,
        ),
        Paint()
          ..color = i % 2 == 0 
              ? TradeIdeasColorStyle.greenPrimary 
              : TradeIdeasColorStyle.greenLight
          ..style = PaintingStyle.fill,
      );
    }

    // Draw entry line
    final entryY = getY(entry);
    canvas.drawLine(
      Offset(0, entryY),
      Offset(size.width, entryY),
      Paint()
        ..color = TradeIdeasColorStyle.greenPrimary // ✅ FIXED
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Draw target line
    final targetY = getY(target);
    canvas.drawLine(
      Offset(0, targetY),
      Offset(size.width, targetY),
      Paint()
        ..color = TradeIdeasColorStyle.greenLight.withOpacity(0.7)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Draw stoploss line
    final slY = getY(stoploss);
    canvas.drawLine(
      Offset(0, slY),
      Offset(size.width, slY),
      Paint()
        ..color = Colors.red.withOpacity(0.7)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Draw area fill
    final areaPath = Path()
      ..moveTo(0, entryY)
      ..lineTo(size.width, entryY)
      ..lineTo(size.width, targetY)
      ..lineTo(0, targetY)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..color = TradeIdeasColorStyle.greenPrimary.withOpacity(0.15)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}