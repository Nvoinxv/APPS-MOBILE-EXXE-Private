import 'package:flutter/material.dart';
import '../hooks/research_coin_hook.dart';
import '../style/apps_colors_research_coin.dart';
import '../postingan/postingan_research_coin.dart';

class ResearchCoinScreen extends StatefulWidget {
  final String token;
  
  const ResearchCoinScreen({
    super.key,
    required this.token,
  });
  
  @override
  State<ResearchCoinScreen> createState() => _ResearchCoinScreenState();
}

class _ResearchCoinScreenState extends State<ResearchCoinScreen> {
  List<Map<String, dynamic>> researchPosts = [];
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
      final result = await Research_Coin_Hook.GetAllResearchCoin(
      );
      
      print("📡 Research Coin API Response: $result");
      
      if (result['success'] == true) {
        final data = result['data'];
        
        if (data is List) {
          setState(() {
            researchPosts = data.map((item) {
              if (item is Map<String, dynamic>) {
                return item;
              }
              return <String, dynamic>{};
            }).toList();
            isLoading = false;
          });
          
          print("✅ Loaded ${researchPosts.length} research posts");
          
          if (researchPosts.isNotEmpty) {
            print("📦 First item keys: ${researchPosts[0].keys.toList()}");
            print("📦 First item data: ${researchPosts[0]}");
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
      backgroundColor: ResearchCoinColorStyle.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section with Icon Logo (Street View Style)
            Container(
              padding: const EdgeInsets.fromLTRB(48, 32, 48, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title dengan Icon Logo
                  Row(
                    children: [
                      // Icon Container
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ResearchCoinColorStyle.greenPrimary.withOpacity(0.2),
                              ResearchCoinColorStyle.greenPrimary.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ResearchCoinColorStyle.greenPrimary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.analytics_outlined,
                          color: ResearchCoinColorStyle.greenPrimary,
                          size: 32,
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Title Text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Research Coin',
                            style: ResearchCoinColorStyle.sectionTitleStyle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'In-Depth Cryptocurrency Analysis',
                            style: TextStyle(
                              color: ResearchCoinColorStyle.subtitleText.withOpacity(0.7),
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

            // Posts Feed (Timeline Layout)
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: ResearchCoinColorStyle.greenPrimary,
                        strokeWidth: 3,
                      ),
                    )
                  : errorMessage != null
                      ? _buildErrorState()
                      : researchPosts.isEmpty
                          ? _buildEmptyState()
                          : _buildPostsFeed(),
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
            '/upload_research_coin',
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
          backgroundColor: ResearchCoinColorStyle.addButtonBackground,
          foregroundColor: ResearchCoinColorStyle.addButtonText,
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
              backgroundColor: ResearchCoinColorStyle.greenPrimary,
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
            color: ResearchCoinColorStyle.subtitleText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No research available',
            style: TextStyle(
              color: ResearchCoinColorStyle.subtitleText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Add Research" to publish your first analysis',
            style: TextStyle(
              color: ResearchCoinColorStyle.descriptionText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsFeed() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(48, 0, 48, 32),
      itemCount: researchPosts.length,
      itemBuilder: (context, index) {
        final post = researchPosts[index];
        
        return _ResearchPostCard(
          postData: post,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostinganResearchCoinScreen(
                  researchData: post,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// ✅ CARD DESIGN - Timeline/Feed Layout (Street View Style)
class _ResearchPostCard extends StatefulWidget {
  final Map<String, dynamic> postData;
  final VoidCallback onTap;

  const _ResearchPostCard({
    required this.postData,
    required this.onTap,
  });

  @override
  State<_ResearchPostCard> createState() => _ResearchPostCardState();
}

class _ResearchPostCardState extends State<_ResearchPostCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Extract data sesuai Research Coin Hook
    final imagesPath = widget.postData['images_path']?.toString() ?? '';
    final judul = widget.postData['judul']?.toString() ?? 'No Title';
    final subJudul = widget.postData['sub_judul']?.toString() ?? '';
    final date = widget.postData['date']?.toString() ?? '';
    final uploaderEmail = widget.postData['user_email']?.toString() ?? '';
    final uploaderName = uploaderEmail.isNotEmpty 
        ? uploaderEmail.split('@')[0] 
        : 'Unknown';
    
    final fullImageUrl = imagesPath.isNotEmpty 
        ? 'http://127.0.0.1:8080/$imagesPath' 
        : '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 32),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..translate(0.0, isHovered ? -4.0 : 0.0),
            decoration: BoxDecoration(
              gradient: ResearchCoinColorStyle.cardGradient1,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isHovered 
                    ? ResearchCoinColorStyle.greenPrimary.withOpacity(0.3)
                    : ResearchCoinColorStyle.cardBorder,
                width: isHovered ? 1.5 : 1,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: ResearchCoinColorStyle.greenPrimary.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Section (Left Side - 40%)
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                    child: fullImageUrl.isNotEmpty
                        ? Image.network(
                            fullImageUrl,
                            height: 280,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder();
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 280,
                                color: ResearchCoinColorStyle.cardBackground,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: ResearchCoinColorStyle.greenPrimary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          )
                        : _buildImagePlaceholder(),
                  ),
                ),
                
                // Content Section (Right Side - 60%)
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: ResearchCoinCardTheme.badgeDecoration(),
                              child: Text(
                                'EXXE RESEARCH',
                                style: ResearchCoinColorStyle.badgeTextStyle,
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Title
                            Text(
                              judul,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Subtitle
                            if (subJudul.isNotEmpty)
                              Text(
                                subJudul,
                                style: TextStyle(
                                  color: ResearchCoinColorStyle.subtitleText.withOpacity(0.9),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  height: 1.5,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            
                            const SizedBox(height: 20),
                            
                            // Metadata Row
                            Row(
                              children: [
                                // Uploader Info
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: ResearchCoinColorStyle.greenPrimary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: ResearchCoinColorStyle.greenPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  uploaderName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                
                                const Spacer(),
                                
                                // Date
                                if (date.isNotEmpty) ...[
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 14,
                                    color: ResearchCoinColorStyle.sourceText,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDate(date),
                                    style: const TextStyle(
                                      color: ResearchCoinColorStyle.sourceText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            
                            // Category Tag
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: ResearchCoinColorStyle.greenPrimary.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.analytics_outlined,
                                    size: 12,
                                    color: ResearchCoinColorStyle.greenPrimary.withOpacity(0.8),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cryptocurrency Analysis',
                                    style: TextStyle(
                                      color: ResearchCoinColorStyle.greenPrimary.withOpacity(0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        // Read More Button
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(
                              'Read full research',
                              style: TextStyle(
                                color: ResearchCoinColorStyle.greenPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: ResearchCoinColorStyle.greenPrimary,
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
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 280,
      color: ResearchCoinColorStyle.cardBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: ResearchCoinColorStyle.greenPrimary.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Research Analysis',
              style: TextStyle(
                color: ResearchCoinColorStyle.subtitleText.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
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