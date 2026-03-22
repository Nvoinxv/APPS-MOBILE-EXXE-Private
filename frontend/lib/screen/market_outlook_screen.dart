import 'package:flutter/material.dart';
import '../hooks/market_outloook_hook.dart';
import '../style/apps_colors_market_outlook.dart';

class MarketOutlookScreen extends StatefulWidget {
  final String token;
  
  const MarketOutlookScreen({
    super.key,
    required this.token,
  });
  
  @override
  State<MarketOutlookScreen> createState() => _MarketOutlookScreenState();
}

class _MarketOutlookScreenState extends State<MarketOutlookScreen> {
  List<Map<String, dynamic>> outlookCards = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOutlookData();
  }

  Future<void> _loadOutlookData() async {
    setState(() => isLoading = true);
    
    final result = await Market_Outlook_Hook.getAllMarketOutlook(token: widget.token,);
    
    if (result['success'] == true) {
      setState(() {
        outlookCards = List<Map<String, dynamic>>.from(result['data']);
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
      backgroundColor: MarketOutlookColorStyle.backgroundColor,
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
                    'Market Outlook',
                    style: MarketOutlookColorStyle.sectionTitleStyle,
                  ),

                  // Add Button
                  _buildAddButton(),
                ],
              ),
            ),

            // Cards Grid - Dinamis dari API
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: MarketOutlookColorStyle.primaryGreen,
                        strokeWidth: 3,
                      ),
                    )
                  : outlookCards.isEmpty
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
              '/upload_market_outlook',
              arguments: widget.token,
            );
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text(
            'Add Outlook',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: MarketOutlookColorStyle.addButtonBackground,
            foregroundColor: MarketOutlookColorStyle.addButtonText,
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
            Icons.show_chart_rounded,
            size: 64,
            color: MarketOutlookColorStyle.subtitleText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No market outlook data available',
            style: TextStyle(
              color: MarketOutlookColorStyle.subtitleText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Add Outlook" to create your first entry',
            style: TextStyle(
              color: MarketOutlookColorStyle.descriptionText,
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
        itemCount: outlookCards.length,
        itemBuilder: (context, index) {
          final card = outlookCards[index];
          return _OutlookCard(
            imageUrl: card['Images_1'] ?? '',
            category: 'MARKET OUTLOOK',
            title: card['title'] ?? '',
            description: card['Date'] ?? '',
            onTap: () {
              // TODO: Navigate to detail page
            },
          );
        },
      ),
    );
  }
}

class _OutlookCard extends StatefulWidget {
  final String imageUrl;
  final String category;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _OutlookCard({
    required this.imageUrl,
    required this.category,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_OutlookCard> createState() => _OutlookCardState();
}

class _OutlookCardState extends State<_OutlookCard> {
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
          decoration: MarketOutlookCardTheme.cardDecoration(isHovered: isHovered),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image/Chart Section
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: MarketOutlookColorStyle.backgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Image or Chart
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: widget.imageUrl.isNotEmpty
                            ? Image.network(
                                widget.imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return const _ChartPlaceholder();
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: MarketOutlookColorStyle.primaryGreen,
                                      strokeWidth: 2,
                                    ),
                                  );
                                },
                              )
                            : const _ChartPlaceholder(),
                      ),
                      
                      // Gradient Overlay
                      Container(
                        decoration: MarketOutlookCardTheme.imageOverlayDecoration(),
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
                          // Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: MarketOutlookCardTheme.badgeDecoration(),
                            child: Text(
                              widget.category,
                              style: MarketOutlookColorStyle.badgeTextStyle,
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Title
                          Text(
                            widget.title,
                            style: MarketOutlookColorStyle.cardTitleStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      // Description
                      Text(
                        widget.description,
                        style: MarketOutlookColorStyle.cardDescriptionStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MarketOutlookColorStyle.backgroundColor,
      padding: const EdgeInsets.all(24),
      child: CustomPaint(
        painter: _ChartPainter(),
        child: Container(),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid lines
    final gridPaint = Paint()
      ..color = MarketOutlookColorStyle.cardBorder
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

    // Draw chart line
    final paint = Paint()
      ..color = MarketOutlookColorStyle.chartGreen
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    final points = [
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.15, size.height * 0.55),
      Offset(size.width * 0.3, size.height * 0.6),
      Offset(size.width * 0.45, size.height * 0.35),
      Offset(size.width * 0.6, size.height * 0.45),
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width, size.height * 0.15),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);

    // Draw area under line
    final areaPaint = Paint()
      ..color = MarketOutlookColorStyle.chartGreen.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final areaPath = Path()
      ..addPath(path, Offset.zero)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(areaPath, areaPaint);

    // Draw data points
    final pointPaint = Paint()
      ..color = MarketOutlookColorStyle.chartGreen
      ..style = PaintingStyle.fill;

    for (var point in points) {
      canvas.drawCircle(point, 3, pointPaint);
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = MarketOutlookColorStyle.chartGreen.withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}