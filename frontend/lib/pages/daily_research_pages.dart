import 'package:flutter/material.dart';
import '../hooks/daily_research_hook.dart';
import '../style/apps_color_daily_search.dart';
import '../postingan/postingan_daily_research.dart';

class DailyResearchSection extends StatefulWidget {
  final String token;
  
  const DailyResearchSection({
    super.key,
    required this.token,
  });
  
  @override
  State<DailyResearchSection> createState() => _DailyResearchSectionState();
}

class _DailyResearchSectionState extends State<DailyResearchSection> {
  List<Map<String, dynamic>> researchCards = [];
  bool isLoading = true;
  String? errorMessage;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> filteredResearch = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterResearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final result = await Daily_Research_Exclusive_Hook.GetAllDailyResearch(
        token: widget.token,
      );
      
      print("📡 API Response: $result");
      
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
            
            filteredResearch = researchCards;
            isLoading = false;
          });
          
          print("✅ Loaded ${researchCards.length} items");
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
      print("❌ Error loading data: $e");
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _filterResearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredResearch = researchCards;
      } else {
        filteredResearch = researchCards.where((research) {
          final title = (research['judul'] ?? '').toString().toLowerCase();
          final subtitle = (research['sub_judul'] ?? '').toString().toLowerCase();
          return title.contains(query) || subtitle.contains(query);
        }).toList();
      }
    });
  }

  void _navigateToDetail(Map<String, dynamic> researchData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostinganDailyResearchScreen(
          researchData: researchData,
        ),
      ),
    ).then((_) {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // HEADER SECTION
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LEFT: Icon + Title
              Row(
                children: [
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
                      size: 28,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Research',
                        style: DailySearchColorStyle.sectionTitleStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Latest market insights and analysis',
                        style: TextStyle(
                          color: DailySearchColorStyle.subtitleText.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // RIGHT: Search + Button
              Row(
                children: [
                  _buildSearchBar(),
                  const SizedBox(width: 16),
                  _buildAddButton(),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // CONTENT SECTION
        if (isLoading)
          SizedBox(
            height: 400,
            child: Center(
              child: CircularProgressIndicator(
                color: DailySearchColorStyle.primaryGreen,
                strokeWidth: 3,
              ),
            ),
          )
        else if (errorMessage != null)
          SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: DailySearchColorStyle.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Error loading data',
                    style: TextStyle(
                      color: DailySearchColorStyle.subtitleText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ?? 'Unknown error',
                    style: TextStyle(
                      color: Colors.red.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DailySearchColorStyle.primaryGreen,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (filteredResearch.isEmpty)
          SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: DailySearchColorStyle.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: DailySearchColorStyle.cardBorder,
                      ),
                    ),
                    child: Icon(
                      Icons.analytics_outlined,
                      size: 64,
                      color: DailySearchColorStyle.subtitleText.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 24),
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
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 0.75,
              ),
              itemCount: filteredResearch.length,
              itemBuilder: (context, index) {
                final card = filteredResearch[index];
                
                if (index == 0) {
                  print("📦 Card data structure: ${card.keys.toList()}");
                }
                
                return _ResearchCard(
                  imageUrl: card['images_path']?.toString() ?? '',
                  title: card['judul']?.toString() ?? 'No Title',
                  description: card['sub_judul']?.toString() ?? 'No Description',
                  date: card['date']?.toString() ?? '',
                  index: index,
                  onTap: () => _navigateToDetail(card),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 280,
      height: 44,
      decoration: BoxDecoration(
        color: DailySearchColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DailySearchColorStyle.cardBorder,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: DailySearchColorStyle.titleText,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search research...',
          hintStyle: const TextStyle(
            color: DailySearchColorStyle.subtitleText,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: DailySearchColorStyle.subtitleText,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: DailySearchColorStyle.subtitleText,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
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
            borderRadius: BorderRadius.circular(10),
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
}

/// ✅ GRID CARD - Konsisten dengan Color Style
class _ResearchCard extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String description;
  final String date;
  final int index;
  final VoidCallback onTap;

  const _ResearchCard({
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.date,
    required this.index,
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
          transform: Matrix4.identity()..translate(0.0, isHovered ? -8.0 : 0.0),
          decoration: DailySearchCardTheme.cardDecoration(isHovered: isHovered),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Background Image
                Positioned.fill(
                  child: widget.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImagePlaceholder();
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: DailySearchColorStyle.cardBackground,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: DailySearchColorStyle.primaryGreen,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        )
                      : _buildImagePlaceholder(),
                ),
                
                // Gradient Overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 200,
                  child: Container(
                    decoration: DailySearchCardTheme.imageOverlayDecoration(),
                  ),
                ),
                
                // Content Overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: DailySearchCardTheme.categoryBadgeDecoration(),
                          child: Text(
                            'DAILY RESEARCH',
                            style: DailySearchColorStyle.categoryLabelStyle,
                          ),
                        ),
                        
                        const SizedBox(height: 14),
                        
                        // Title
                        Text(
                          widget.title,
                          style: DailySearchColorStyle.cardTitleStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Description
                        Text(
                          widget.description,
                          style: DailySearchColorStyle.cardDescriptionStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        // Date
                        if (widget.date.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: DailySearchColorStyle.descriptionText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(widget.date),
                                style: TextStyle(
                                  color: DailySearchColorStyle.descriptionText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: DailySearchColorStyle.cardBackground,
      child: Center(
        child: Icon(
          Icons.analytics_outlined,
          size: 64,
          color: DailySearchColorStyle.subtitleText.withOpacity(0.1),
        ),
      ),
    );
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    
    try {
      final parsedDate = DateTime.parse(date);
      final now = DateTime.now();
      final difference = now.difference(parsedDate);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
      }
    } catch (e) {
      return date;
    }
  }
}