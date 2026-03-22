import 'package:flutter/material.dart';
import '../hooks/market_outloook_hook.dart';
import '../style/apps_colors_market_outlook.dart';
import '../postingan/postingan_market_outlook.dart';

class MarketOutlookSection extends StatefulWidget {
  final String token;
  
  const MarketOutlookSection({
    super.key,
    required this.token,
  });
  
  @override
  State<MarketOutlookSection> createState() => _MarketOutlookSectionState();
}

class _MarketOutlookSectionState extends State<MarketOutlookSection> {
  List<Map<String, dynamic>> outlookCards = [];
  List<Map<String, dynamic>> filteredOutlook = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterOutlook);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    final result = await Market_Outlook_Hook.getAllMarketOutlook(token: widget.token);
    
    if (result['success'] == true) {
      setState(() {
        outlookCards = List<Map<String, dynamic>>.from(result['data']);
        filteredOutlook = outlookCards;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void _filterOutlook() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredOutlook = outlookCards;
      } else {
        filteredOutlook = outlookCards.where((outlook) {
          final title = (outlook['title'] ?? '').toLowerCase();
          final isi1 = (outlook['Isi_1'] ?? '').toLowerCase();
          final source = (outlook['Source'] ?? '').toLowerCase();
          return title.contains(query) || 
                 isi1.contains(query) || 
                 source.contains(query);
        }).toList();
      }
    });
  }

  void _navigateToDetail(Map<String, dynamic> outlookData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostinganMarketOutlookScreen(
          marketOutlookData: outlookData,
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
        // HEADER SECTION - Konsisten dengan Quant Investing
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
                          MarketOutlookColorStyle.greenNeon.withOpacity(0.2),
                          MarketOutlookColorStyle.greenNeon.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: MarketOutlookColorStyle.greenNeon.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.assessment_outlined,
                      color: MarketOutlookColorStyle.greenNeon,
                      size: 28,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Market Outlook',
                        style: MarketOutlookColorStyle.sectionTitleStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Market analysis and future predictions',
                        style: TextStyle(
                          color: MarketOutlookColorStyle.subtitleText.withOpacity(0.5),
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
                color: MarketOutlookColorStyle.greenNeon,
                strokeWidth: 3,
              ),
            ),
          )
        else if (filteredOutlook.isEmpty)
          SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: MarketOutlookColorStyle.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: MarketOutlookColorStyle.cardBorder,
                      ),
                    ),
                    child: Icon(
                      Icons.assessment_outlined,
                      size: 64,
                      color: MarketOutlookColorStyle.subtitleText.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No market outlook available',
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
              itemCount: filteredOutlook.length,
              itemBuilder: (context, index) {
                final outlook = filteredOutlook[index];
                return _MarketOutlookCard(
                  index: index,
                  imageUrl: outlook['Images_1'] ?? '',
                  title: outlook['title'] ?? '',
                  subtitle: outlook['Isi_1'] ?? '',
                  source: outlook['Source'] ?? 'Unknown',
                  date: outlook['Date'] ?? '',
                  onTap: () => _navigateToDetail(outlook),
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
      decoration: MarketOutlookCardTheme.searchBarDecoration(),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: MarketOutlookColorStyle.searchText,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search outlook...',
          hintStyle: const TextStyle(
            color: MarketOutlookColorStyle.searchPlaceholder,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: MarketOutlookColorStyle.searchPlaceholder,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: MarketOutlookColorStyle.searchPlaceholder,
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

/// ✅ GRID CARD - Konsisten dengan Quant Investing Layout
class _MarketOutlookCard extends StatefulWidget {
  final int index;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String source;
  final String date;
  final VoidCallback onTap;

  const _MarketOutlookCard({
    required this.index,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.source,
    required this.date,
    required this.onTap,
  });

  @override
  State<_MarketOutlookCard> createState() => _MarketOutlookCardState();
}

class _MarketOutlookCardState extends State<_MarketOutlookCard> {
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
          decoration: MarketOutlookCardTheme.cardDecoration(isHovered: isHovered),
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
                              color: MarketOutlookColorStyle.cardBackground,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: MarketOutlookColorStyle.greenNeon,
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
                    decoration: MarketOutlookCardTheme.imageOverlayDecoration(),
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
                          decoration: MarketOutlookCardTheme.badgeDecoration(),
                          child: Text(
                            'MARKET OUTLOOK',
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
                        
                        const SizedBox(height: 8),
                        
                        // Subtitle
                        Text(
                          widget.subtitle,
                          style: MarketOutlookColorStyle.cardSubtitleStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        // Source & Date
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Source
                            if (widget.source.isNotEmpty) ...[
                              Icon(
                                Icons.source_outlined,
                                size: 12,
                                color: MarketOutlookColorStyle.descriptionText,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.source,
                                  style: MarketOutlookColorStyle.cardDescriptionStyle,
                                  overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: MarketOutlookColorStyle.cardBackground,
      child: Center(
        child: Icon(
          Icons.assessment_outlined,
          size: 64,
          color: MarketOutlookColorStyle.subtitleText.withOpacity(0.1),
        ),
      ),
    );
  }
}