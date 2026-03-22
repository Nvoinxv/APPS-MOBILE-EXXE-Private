import 'package:flutter/material.dart';
import '../style/apps_color_news.dart';

class PostinganNewsScreen extends StatefulWidget {
  final Map<String, dynamic> newsData;
  
  const PostinganNewsScreen({
    super.key,
    required this.newsData,
  });
  
  @override
  State<PostinganNewsScreen> createState() => _PostinganNewsScreenState();
}

class _PostinganNewsScreenState extends State<PostinganNewsScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOpacity = 0.0;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Debug print untuk melihat data yang diterima
    print("📰 PostinganNewsScreen - Data Received:");
    print(widget.newsData);
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    final offset = _scrollController.offset;
    setState(() {
      _scrollOpacity = (offset / 200).clamp(0.0, 1.0);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Support both MongoDB field names (Capital) and standard names (lowercase)
    final imageUrl = widget.newsData['Images_news']?.toString() ?? 
                     widget.newsData['images']?.toString() ?? 
                     widget.newsData['image']?.toString() ?? '';
    
    final title = widget.newsData['Title']?.toString() ?? 
                  widget.newsData['title']?.toString() ?? 
                  'No Title';
    
    final description = widget.newsData['Description']?.toString() ?? 
                       widget.newsData['description']?.toString() ?? '';
    
    final source = widget.newsData['source']?.toString() ?? 'Unknown Source';
    
    final date = widget.newsData['Date']?.toString() ?? 
                 widget.newsData['date']?.toString() ?? 
                 widget.newsData['news_date']?.toString() ?? '';
    
    final content = widget.newsData['content']?.toString() ?? 
                   widget.newsData['Description']?.toString() ?? 
                   widget.newsData['description']?.toString() ?? '';
    
    // Full image URL with base path
    final fullImageUrl = imageUrl.isNotEmpty ? 'http://127.0.0.1:8080/$imageUrl' : '';
    
    // Debug prints
    print("🖼️ Image URL: $fullImageUrl");
    print("📝 Title: $title");
    print("📄 Content length: ${content.length} chars");
    
    return Scaffold(
      backgroundColor: NewsColorStyle.backgroundColor,
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Hero Image Header
              SliverAppBar(
                expandedHeight: 500,
                pinned: true,
                backgroundColor: NewsColorStyle.backgroundColor,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Hero Image
                      if (fullImageUrl.isNotEmpty)
                        Image.network(
                          fullImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print("❌ Error loading image: $error");
                            return _buildImagePlaceholder();
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: NewsColorStyle.greenNeon,
                              ),
                            );
                          },
                        )
                      else
                        _buildImagePlaceholder(),
                      
                      // Gradient Overlay
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x66000000),
                              Color(0xDD000000),
                            ],
                            stops: [0.3, 0.7, 1.0],
                          ),
                        ),
                      ),
                      
                      // Title Overlay at Bottom
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // News Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: NewsCardTheme.newsBadgeDecoration(),
                                child: Text(
                                  'NEWS',
                                  style: NewsColorStyle.badgeTextStyle.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Title
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(0, 2),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Content Section
              SliverToBoxAdapter(
                child: Container(
                  color: NewsColorStyle.backgroundColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Metadata Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: NewsColorStyle.searchBorder,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Source
                            Icon(
                              Icons.source_outlined,
                              size: 18,
                              color: NewsColorStyle.greenNeon,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              source,
                              style: const TextStyle(
                                color: NewsColorStyle.greenNeon,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            
                            const SizedBox(width: 24),
                            
                            // Date
                            if (date.isNotEmpty) ...[
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: NewsColorStyle.sourceText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(date),
                                style: const TextStyle(
                                  color: NewsColorStyle.sourceText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Description
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Subtitle/Summary
                            if (description.isNotEmpty) ...[
                              Text(
                                description,
                                style: const TextStyle(
                                  color: NewsColorStyle.highlightText,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              
                              const SizedBox(height: 32),
                            ],
                            
                            // Main Content
                            Text(
                              content.isNotEmpty ? content : 'No content available',
                              style: const TextStyle(
                                color: NewsColorStyle.subtitleText,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                height: 1.8,
                                letterSpacing: 0.1,
                              ),
                            ),
                            
                            const SizedBox(height: 48),
                            
                            // Divider
                            Container(
                              height: 1,
                              color: NewsColorStyle.searchBorder,
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Footer Info
                            _buildFooterInfo(),
                            
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Floating Back Button (appears on scroll)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _scrollOpacity,
            child: Container(
              color: NewsColorStyle.backgroundColor.withOpacity(0.95),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: NewsColorStyle.greenNeon,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.black,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImagePlaceholder() {
    return Container(
      color: NewsColorStyle.cardBackground,
      child: Center(
        child: Icon(
          Icons.newspaper,
          size: 120,
          color: NewsColorStyle.sourceText.withOpacity(0.2),
        ),
      ),
    );
  }
  
  Widget _buildFooterInfo() {
    final source = widget.newsData['source']?.toString() ?? 'Unknown';
    final date = widget.newsData['Date']?.toString() ?? 
                 widget.newsData['date']?.toString() ?? 
                 widget.newsData['news_date']?.toString() ?? '';
    final content = widget.newsData['content']?.toString() ?? 
                   widget.newsData['Description']?.toString() ?? 
                   widget.newsData['description']?.toString() ?? '';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: NewsColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NewsColorStyle.searchBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NewsColorStyle.greenNeon.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: NewsColorStyle.greenNeon,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'About this article',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoRow(
            icon: Icons.source_outlined,
            label: 'Source',
            value: source,
          ),
          
          const SizedBox(height: 12),
          
          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Published',
            value: _formatDateFull(date),
          ),
          
          const SizedBox(height: 12),
          
          _buildInfoRow(
            icon: Icons.access_time,
            label: 'Reading time',
            value: _calculateReadingTime(content),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: NewsColorStyle.sourceText,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: NewsColorStyle.sourceText,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: NewsColorStyle.subtitleText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
      print("❌ Error parsing date: $e");
      return date;
    }
  }
  
  String _formatDateFull(String date) {
    if (date.isEmpty) return 'Date not available';
    
    try {
      final parsedDate = DateTime.parse(date);
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[parsedDate.month - 1]} ${parsedDate.day}, ${parsedDate.year}';
    } catch (e) {
      print("❌ Error parsing full date: $e");
      return date;
    }
  }
  
  String _calculateReadingTime(String content) {
    if (content.isEmpty) return '1 min read';
    
    final wordCount = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final minutes = (wordCount / 200).ceil(); // Average reading speed: 200 words/min
    return '${minutes > 0 ? minutes : 1} min read';
  }
}