import 'package:flutter/material.dart';
import '../hooks/daily_research_hook.dart';
import '../style/apps_color_daily_search.dart';

class DailyResearchScreen extends StatefulWidget {
  final String token;
  
  const DailyResearchScreen({
    super.key,
    required this.token,
  });
  
  @override
  State<DailyResearchScreen> createState() => _DailyResearchScreenState();
}

class _DailyResearchScreenState extends State<DailyResearchScreen> {
  List<Map<String, dynamic>> researchCards = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadResearchData();
  }

  Future<void> _loadResearchData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final result = await Daily_Research_Exclusive_Hook.GetAllDailyResearch(
        token: widget.token,
      );
      
      print("📡 Daily Research API Response: $result");
      
      if (result['success'] == true) {
        final data = result['data'];
        
        if (data is List) {
          setState(() {
            researchCards = data.map((item) {
              if (item is Map<String, dynamic>) {
                return item;
              }
              return <String, dynamic>{};
            }).toList();
            isLoading = false;
          });
          
          print("✅ Loaded ${researchCards.length} research items");
          
          if (researchCards.isNotEmpty) {
            print("📦 First item keys: ${researchCards[0].keys.toList()}");
            print("📦 First item data: ${researchCards[0]}");
          }
        } else {
          setState(() {
            errorMessage = "Invalid data format: expected List, got ${data.runtimeType}";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = result['message'] ?? result['error'] ?? 'Unknown error';
          isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Error loading research: $e");
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DailySearchColorStyle.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section with Icon Logo
            Container(
              padding: const EdgeInsets.fromLTRB(48, 32, 48, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✅ Title dengan Icon Logo kayak Quant
                  Row(
                    children: [
                      // Icon Container
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              DailySearchColorStyle.primaryGreen.withOpacity(0.2),
                              DailySearchColorStyle.primaryGreen.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: DailySearchColorStyle.primaryGreen.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.analytics_outlined,
                          color: DailySearchColorStyle.primaryGreen,
                          size: 32,
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Title Text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Research',
                            style: DailySearchColorStyle.sectionTitleStyle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Latest Market Analysis & Insights',
                            style: TextStyle(
                              color: DailySearchColorStyle.subtitleText.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  _buildAddButton(),
                ],
              ),
            ),

            // Cards Grid
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: DailySearchColorStyle.primaryGreen,
                        strokeWidth: 3,
                      ),
                    )
                  : errorMessage != null
                      ? _buildErrorState()
                      : researchCards.isEmpty
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
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/upload_daily_research',
            arguments: widget.token,
          );
        },
        icon: const Icon(Icons.add, size: 18),
        label: const Text(
          'Add Research',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: DailySearchColorStyle.addButtonBackground,
          foregroundColor: DailySearchColorStyle.addButtonText,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
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
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Error: $errorMessage',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadResearchData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DailySearchColorStyle.primaryGreen,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: DailySearchColorStyle.subtitleText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No research data available',
            style: TextStyle(
              color: DailySearchColorStyle.subtitleText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Add Research" to create your first entry',
            style: TextStyle(
              color: DailySearchColorStyle.descriptionText,
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
        itemCount: researchCards.length,
        itemBuilder: (context, index) {
          final card = researchCards[index];
          
          return _ResearchCard(
            imageUrl: card['images_path']?.toString() ?? '',
            category: 'EXXE RESEARCH',
            title: card['judul']?.toString() ?? 'No Title',
            description: card['sub_judul']?.toString() ?? 'No Description',
            date: card['date']?.toString() ?? '',
            onTap: () {
              print("Tapped: ${card['judul']}");
            },
          );
        },
      ),
    );
  }
}

class _ResearchCard extends StatefulWidget {
  final String imageUrl;
  final String category;
  final String title;
  final String description;
  final String date;
  final VoidCallback onTap;

  const _ResearchCard({
    required this.imageUrl,
    required this.category,
    required this.title,
    required this.description,
    this.date = '',
    required this.onTap,
  });

  @override
  State<_ResearchCard> createState() => _ResearchCardState();
}

class _ResearchCardState extends State<_ResearchCard> {
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
          decoration: DailySearchCardTheme.cardDecoration(isHovered: isHovered),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: DailySearchColorStyle.backgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Stack(
                    children: [
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
                                  print("❌ Image load error: $error");
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
                                      color: DailySearchColorStyle.primaryGreen,
                                      strokeWidth: 2,
                                    ),
                                  );
                                },
                              )
                            : const _ChartPlaceholder(),
                      ),
                      
                      Container(
                        decoration: DailySearchCardTheme.imageOverlayDecoration(),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: DailySearchCardTheme.categoryBadgeDecoration(),
                            child: Text(
                              widget.category,
                              style: DailySearchColorStyle.categoryLabelStyle,
                            ),
                          ),

                          const SizedBox(height: 14),

                          Text(
                            widget.title,
                            style: DailySearchColorStyle.cardTitleStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.description,
                            style: DailySearchColorStyle.cardDescriptionStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.date.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.date,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
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

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DailySearchColorStyle.backgroundColor,
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
    final gridPaint = Paint()
      ..color = DailySearchColorStyle.cardBorder
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

    final paint = Paint()
      ..color = DailySearchColorStyle.chartGreen
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

    final areaPaint = Paint()
      ..color = DailySearchColorStyle.chartArea
      ..style = PaintingStyle.fill;

    final areaPath = Path()
      ..addPath(path, Offset.zero)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(areaPath, areaPaint);

    final pointPaint = Paint()
      ..color = DailySearchColorStyle.chartGreen
      ..style = PaintingStyle.fill;

    for (var point in points) {
      canvas.drawCircle(point, 3, pointPaint);
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = DailySearchColorStyle.chartGreen.withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}