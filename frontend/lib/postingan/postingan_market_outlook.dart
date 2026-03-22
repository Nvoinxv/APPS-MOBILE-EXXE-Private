import 'package:flutter/material.dart';
import '../style/apps_colors_market_outlook.dart';
import 'package:url_launcher/url_launcher.dart';

class PostinganMarketOutlookScreen extends StatefulWidget {
  final Map<String, dynamic> marketOutlookData;
  
  const PostinganMarketOutlookScreen({
    super.key,
    required this.marketOutlookData,
  });
  
  @override
  State<PostinganMarketOutlookScreen> createState() => _PostinganMarketOutlookScreenState();
}

class _PostinganMarketOutlookScreenState extends State<PostinganMarketOutlookScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOpacity = 0.0;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Debug print untuk melihat data yang diterima
    print("📊 PostinganMarketOutlookScreen - Data Received:");
    print(widget.marketOutlookData);
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
    // ✅ Extract data sesuai Market Outlook Hook structure
    final image1 = widget.marketOutlookData['Images_1']?.toString() ?? 
                   widget.marketOutlookData['images_1']?.toString() ?? '';
    
    final image2 = widget.marketOutlookData['Images_2']?.toString() ?? 
                   widget.marketOutlookData['images_2']?.toString() ?? '';
    
    final image3 = widget.marketOutlookData['Images_3']?.toString() ?? 
                   widget.marketOutlookData['images_3']?.toString() ?? '';
    
    final title = widget.marketOutlookData['title']?.toString() ?? 
                  widget.marketOutlookData['Title']?.toString() ?? 
                  'Market Outlook';
    
    final date = widget.marketOutlookData['Date']?.toString() ?? 
                 widget.marketOutlookData['date']?.toString() ?? '';
    
    final videoDrive = widget.marketOutlookData['Video_Drive']?.toString() ?? 
                       widget.marketOutlookData['video_drive']?.toString() ?? '';
    
    final source = widget.marketOutlookData['Source']?.toString() ?? 
                   widget.marketOutlookData['source']?.toString() ?? '';
    
    final isi1 = widget.marketOutlookData['Isi_1']?.toString() ?? '';
    final isi2 = widget.marketOutlookData['Isi_2']?.toString() ?? '';
    final isi3 = widget.marketOutlookData['Isi_3']?.toString() ?? '';
    
    final uploader = widget.marketOutlookData['uploader']?.toString() ?? 'Admin';
    final uploadDate = widget.marketOutlookData['upload_date']?.toString() ?? 
                       widget.marketOutlookData['created_at']?.toString() ?? 
                       date;
    
    // ✅ Full image URL with base path - prioritas Images_1
    final fullImageUrl = image1.isNotEmpty 
        ? 'http://127.0.0.1:8080/$image1' 
        : (image2.isNotEmpty 
            ? 'http://127.0.0.1:8080/$image2' 
            : (image3.isNotEmpty ? 'http://127.0.0.1:8080/$image3' : ''));
    
    // Debug prints
    print("🖼️ Image 1 Field: ${widget.marketOutlookData['Images_1']}");
    print("🖼️ Image 2 Field: ${widget.marketOutlookData['Images_2']}");
    print("🖼️ Image 3 Field: ${widget.marketOutlookData['Images_3']}");
    print("🖼️ Full Image URL: $fullImageUrl");
    print("📝 Title: $title");
    print("📅 Date: $date");
    print("📺 Video Drive: $videoDrive");
    print("📰 Source: $source");
    
    return Scaffold(
      backgroundColor: MarketOutlookColorStyle.backgroundColor,
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
                backgroundColor: MarketOutlookColorStyle.backgroundColor,
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
                            print("❌ Tried URL: $fullImageUrl");
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
                                color: MarketOutlookColorStyle.greenNeon,
                              ),
                            );
                          },
                        )
                      else
                        _buildImagePlaceholder(),
                      
                      // Gradient Overlay - GREEN THEME
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x66001100),
                              Color(0xDD000A00),
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
                              // Market Outlook Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: MarketOutlookCardTheme.badgeDecoration(),
                                child: Text(
                                  'MARKET OUTLOOK',
                                  style: MarketOutlookColorStyle.badgeTextStyle.copyWith(
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
                              
                              const SizedBox(height: 8),
                              
                              // Date
                              if (date.isNotEmpty)
                                Text(
                                  _formatDateFull(date),
                                  style: TextStyle(
                                    color: MarketOutlookColorStyle.greenNeon,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        color: MarketOutlookColorStyle.greenNeon.withOpacity(0.5),
                                        offset: const Offset(0, 2),
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
                  color: MarketOutlookColorStyle.backgroundColor,
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
                              color: MarketOutlookColorStyle.searchBorder,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Uploader
                            Icon(
                              Icons.person_outline,
                              size: 18,
                              color: MarketOutlookColorStyle.greenNeon,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              uploader,
                              style: const TextStyle(
                                color: MarketOutlookColorStyle.greenNeon,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            
                            const SizedBox(width: 24),
                            
                            // Upload Date
                            if (uploadDate.isNotEmpty) ...[
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: MarketOutlookColorStyle.descriptionText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(uploadDate),
                                style: const TextStyle(
                                  color: MarketOutlookColorStyle.descriptionText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                            
                            const Spacer(),
                            
                            // ✅ Video Drive Link Button
                            if (videoDrive.isNotEmpty)
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await _openVideoLink(videoDrive);
                                },
                                icon: const Icon(
                                  Icons.play_circle_outline,
                                  size: 16,
                                ),
                                label: const Text('Watch Video'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MarketOutlookColorStyle.greenNeon,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Analysis Sections
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section 1
                            if (isi1.isNotEmpty) ...[
                              _buildAnalysisSection(
                                number: '01',
                                title: 'Market Analysis',
                                description: isi1,
                                image: image1,
                              ),
                              const SizedBox(height: 40),
                            ],
                            
                            // Section 2
                            if (isi2.isNotEmpty) ...[
                              _buildAnalysisSection(
                                number: '02',
                                title: 'Key Insights',
                                description: isi2,
                                image: image2,
                              ),
                              const SizedBox(height: 40),
                            ],
                            
                            // Section 3
                            if (isi3.isNotEmpty) ...[
                              _buildAnalysisSection(
                                number: '03',
                                title: 'Outlook & Recommendations',
                                description: isi3,
                                image: image3,
                              ),
                              const SizedBox(height: 48),
                            ],
                            
                            // Divider
                            Container(
                              height: 1,
                              color: MarketOutlookColorStyle.searchBorder,
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
              color: MarketOutlookColorStyle.backgroundColor.withOpacity(0.95),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: MarketOutlookColorStyle.greenNeon,
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
      color: MarketOutlookColorStyle.cardBackground,
      child: Center(
        child: Icon(
          Icons.assessment_outlined,
          size: 120,
          color: MarketOutlookColorStyle.descriptionText.withOpacity(0.2),
        ),
      ),
    );
  }
  
  Widget _buildAnalysisSection({
    required String number,
    required String title,
    required String description,
    String? image,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: MarketOutlookColorStyle.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MarketOutlookColorStyle.searchBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Section Number Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: MarketOutlookColorStyle.greenNeon,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.only(left: 56),
              child: Text(
                description,
                style: const TextStyle(
                  color: MarketOutlookColorStyle.subtitleText,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
          
          // ✅ Display image if available
          if (image != null && image.isNotEmpty) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                'http://127.0.0.1:8080/$image',
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: MarketOutlookColorStyle.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 48,
                        color: MarketOutlookColorStyle.descriptionText.withOpacity(0.3),
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: MarketOutlookColorStyle.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: MarketOutlookColorStyle.greenNeon,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFooterInfo() {
    final uploader = widget.marketOutlookData['uploader']?.toString() ?? 'Admin';
    final uploadDate = widget.marketOutlookData['upload_date']?.toString() ?? 
                       widget.marketOutlookData['created_at']?.toString() ?? 
                       widget.marketOutlookData['Date']?.toString() ?? '';
    final title = widget.marketOutlookData['title']?.toString() ?? 
                  widget.marketOutlookData['Title']?.toString() ?? '';
    final source = widget.marketOutlookData['Source']?.toString() ?? 
                   widget.marketOutlookData['source']?.toString() ?? '';
    
    // Calculate total content length
    final totalContent = [
      widget.marketOutlookData['Isi_1']?.toString() ?? '',
      widget.marketOutlookData['Isi_2']?.toString() ?? '',
      widget.marketOutlookData['Isi_3']?.toString() ?? '',
    ].join(' ');
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MarketOutlookColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MarketOutlookColorStyle.searchBorder,
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
                  color: MarketOutlookColorStyle.greenNeon.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: MarketOutlookColorStyle.greenNeon,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'About this report',
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
            icon: Icons.article_outlined,
            label: 'Title',
            value: title,
          ),
          
          const SizedBox(height: 12),
          
          if (source.isNotEmpty) ...[
            _buildInfoRow(
              icon: Icons.source_outlined,
              label: 'Source',
              value: source,
            ),
            const SizedBox(height: 12),
          ],
          
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Uploaded by',
            value: uploader,
          ),
          
          const SizedBox(height: 12),
          
          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Published',
            value: _formatDateFull(uploadDate),
          ),
          
          const SizedBox(height: 12),
          
          _buildInfoRow(
            icon: Icons.access_time,
            label: 'Reading time',
            value: _calculateReadingTime(totalContent),
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
          color: MarketOutlookColorStyle.descriptionText,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: MarketOutlookColorStyle.descriptionText,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: MarketOutlookColorStyle.subtitleText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
  
  // ✅ FUNGSI UNTUK BUKA VIDEO LINK
  Future<void> _openVideoLink(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        print("✅ Opening Video: $url");
      } else {
        print("❌ Cannot launch URL: $url");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot open video link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print("❌ Error opening video: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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