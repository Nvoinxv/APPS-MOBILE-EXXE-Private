import 'package:flutter/material.dart';
import '../style/apps_colors_research_coin.dart';
import '../hooks/daily_research_hook.dart';
import 'package:url_launcher/url_launcher.dart';

class PostinganDailyResearchScreen extends StatefulWidget {
  final Map<String, dynamic> researchData;
  
  const PostinganDailyResearchScreen({
    super.key,
    required this.researchData,
  });
  
  @override
  State<PostinganDailyResearchScreen> createState() => _PostinganDailyResearchScreenState();
}

class _PostinganDailyResearchScreenState extends State<PostinganDailyResearchScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOpacity = 0.0;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Debug print untuk melihat data yang diterima
    print("📊 PostinganDailyResearchScreen - Data Received:");
    print(widget.researchData);
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
    // ✅ Ambil data dari hooks - sesuai dengan struktur Daily_Research_Hook
    final images = widget.researchData['images']?.toString() ?? 
                   widget.researchData['Images']?.toString() ?? '';
    
    final video = widget.researchData['Video']?.toString() ?? 
                  widget.researchData['video']?.toString() ?? '';
    
    final title = widget.researchData['title']?.toString() ?? 
                  widget.researchData['Title']?.toString() ?? 
                  'No Title';
    
    final subTitle = widget.researchData['sub_title']?.toString() ?? 
                     widget.researchData['Sub_title']?.toString() ?? 
                     '';
    
    final date = widget.researchData['Date']?.toString() ?? 
                 widget.researchData['date']?.toString() ?? '';
    
    final source = widget.researchData['Source']?.toString() ?? 
                   widget.researchData['source']?.toString() ?? '';
    
    final deskripsi1 = widget.researchData['deskripsi_1']?.toString() ?? 
                       widget.researchData['Deskripsi_1']?.toString() ?? '';
    
    final deskripsi2 = widget.researchData['deskripsi_2']?.toString() ?? 
                       widget.researchData['Deskripsi_2']?.toString() ?? '';
    
    final deskripsi3 = widget.researchData['deskripsi_3']?.toString() ?? 
                       widget.researchData['Deskripsi_3']?.toString() ?? '';
    
    final uploader = widget.researchData['uploader']?.toString() ?? 
                     widget.researchData['user_email']?.toString() ?? 
                     'Admin';
    
    final uploadDate = widget.researchData['created_at']?.toString() ?? 
                       widget.researchData['upload_date']?.toString() ?? 
                       date;
    
    // ✅ Full image URL with base path
    final fullImageUrl = images.isNotEmpty 
        ? 'http://127.0.0.1:8080/$images' 
        : '';
    
    final fullVideoUrl = video.isNotEmpty 
        ? 'http://127.0.0.1:8080/$video' 
        : '';
    
    // Debug prints
    print("🖼️ Images Field: $images");
    print("🖼️ Full Image URL: $fullImageUrl");
    print("🎥 Video Field: $video");
    print("🎥 Full Video URL: $fullVideoUrl");
    print("📝 Title: $title");
    print("📝 Sub Title: $subTitle");
    print("📅 Date: $date");
    print("🔗 Source: $source");
    
    return Scaffold(
      backgroundColor: ResearchCoinColorStyle.backgroundColor,
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
                backgroundColor: ResearchCoinColorStyle.backgroundColor,
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
                                color: ResearchCoinColorStyle.greenNeon,
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
                              Color(0x661A3A1A),
                              Color(0xDD0D1F0D),
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
                              // Daily Research Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: ResearchCoinCardTheme.badgeDecoration(),
                                child: Text(
                                  'DAILY RESEARCH',
                                  style: ResearchCoinColorStyle.badgeTextStyle.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Research Title
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
                              
                              // Sub Title
                              if (subTitle.isNotEmpty)
                                Text(
                                  subTitle,
                                  style: TextStyle(
                                    color: ResearchCoinColorStyle.greenNeon,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        color: ResearchCoinColorStyle.greenNeon.withOpacity(0.5),
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
                  color: ResearchCoinColorStyle.backgroundColor,
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
                              color: ResearchCoinColorStyle.searchBorder,
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
                              color: ResearchCoinColorStyle.greenNeon,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              uploader,
                              style: const TextStyle(
                                color: ResearchCoinColorStyle.greenNeon,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            
                            const SizedBox(width: 24),
                            
                            // Upload Date
                            if (date.isNotEmpty) ...[
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: ResearchCoinColorStyle.sourceText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(date),
                                style: const TextStyle(
                                  color: ResearchCoinColorStyle.sourceText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                            
                            const Spacer(),
                            
                            // Source Badge
                            if (source.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: ResearchCoinColorStyle.greenNeon.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: ResearchCoinColorStyle.greenNeon.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.source_outlined,
                                      size: 14,
                                      color: ResearchCoinColorStyle.greenNeon,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      source,
                                      style: const TextStyle(
                                        color: ResearchCoinColorStyle.greenNeon,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Video Section (if available)
                      if (fullVideoUrl.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: ResearchCoinColorStyle.greenNeon,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.play_circle_outline,
                                      size: 20,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Research Video',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: ResearchCoinColorStyle.greenNeon.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: GestureDetector(
                                      onTap: () => _openVideoLink(fullVideoUrl),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Video thumbnail or placeholder
                                          Container(
                                            color: ResearchCoinColorStyle.cardBackground,
                                            child: Center(
                                              child: Icon(
                                                Icons.play_circle_filled,
                                                size: 80,
                                                color: ResearchCoinColorStyle.greenNeon,
                                              ),
                                            ),
                                          ),
                                          // Play overlay
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withOpacity(0.7),
                                                ],
                                              ),
                                            ),
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.play_circle_outline,
                                                    size: 64,
                                                    color: ResearchCoinColorStyle.greenNeon,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'Tap to play video',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
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
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Research Content Sections
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section 1
                            if (deskripsi1.isNotEmpty) ...[
                              _buildResearchSection(
                                number: '01',
                                title: 'Key Insights',
                                description: deskripsi1,
                              ),
                              const SizedBox(height: 40),
                            ],
                            
                            // Section 2
                            if (deskripsi2.isNotEmpty) ...[
                              _buildResearchSection(
                                number: '02',
                                title: 'Market Analysis',
                                description: deskripsi2,
                              ),
                              const SizedBox(height: 40),
                            ],
                            
                            // Section 3
                            if (deskripsi3.isNotEmpty) ...[
                              _buildResearchSection(
                                number: '03',
                                title: 'Conclusion',
                                description: deskripsi3,
                              ),
                              const SizedBox(height: 48),
                            ],
                            
                            // Divider
                            Container(
                              height: 1,
                              color: ResearchCoinColorStyle.searchBorder,
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
              color: ResearchCoinColorStyle.backgroundColor.withOpacity(0.95),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: ResearchCoinColorStyle.greenNeon,
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
      color: ResearchCoinColorStyle.cardBackground,
      child: Center(
        child: Icon(
          Icons.analytics_outlined,
          size: 120,
          color: ResearchCoinColorStyle.sourceText.withOpacity(0.2),
        ),
      ),
    );
  }
  
  Widget _buildResearchSection({
    required String number,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: ResearchCoinColorStyle.cardGradient1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ResearchCoinColorStyle.searchBorder,
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
                  color: ResearchCoinColorStyle.greenNeon,
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
                  color: ResearchCoinColorStyle.subtitleText,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFooterInfo() {
    final uploader = widget.researchData['uploader']?.toString() ?? 
                     widget.researchData['user_email']?.toString() ?? 
                     'Admin';
    final uploadDate = widget.researchData['created_at']?.toString() ?? 
                       widget.researchData['upload_date']?.toString() ?? 
                       widget.researchData['Date']?.toString() ?? '';
    final title = widget.researchData['title']?.toString() ?? 
                  widget.researchData['Title']?.toString() ?? '';
    final subTitle = widget.researchData['sub_title']?.toString() ?? 
                     widget.researchData['Sub_title']?.toString() ?? '';
    final source = widget.researchData['Source']?.toString() ?? 
                   widget.researchData['source']?.toString() ?? '';
    
    // Calculate total content length
    final totalContent = [
      widget.researchData['deskripsi_1']?.toString() ?? '',
      widget.researchData['deskripsi_2']?.toString() ?? '',
      widget.researchData['deskripsi_3']?.toString() ?? '',
    ].join(' ');
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ResearchCoinColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ResearchCoinColorStyle.searchBorder,
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
                  color: ResearchCoinColorStyle.greenNeon.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: ResearchCoinColorStyle.greenNeon,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'About this research',
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
            icon: Icons.title,
            label: 'Title',
            value: title,
          ),
          
          if (subTitle.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.subtitles_outlined,
              label: 'Subtitle',
              value: subTitle,
            ),
          ],
          
          const SizedBox(height: 12),
          
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
          
          if (source.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.source_outlined,
              label: 'Source',
              value: source,
            ),
          ],
          
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: ResearchCoinColorStyle.sourceText,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: ResearchCoinColorStyle.sourceText,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: ResearchCoinColorStyle.subtitleText,
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