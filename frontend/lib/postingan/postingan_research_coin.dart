import 'package:flutter/material.dart';
import '../style/apps_colors_research_coin.dart';
import 'package:url_launcher/url_launcher.dart';

class PostinganResearchCoinScreen extends StatefulWidget {
  final Map<String, dynamic> researchData;
  
  const PostinganResearchCoinScreen({
    super.key,
    required this.researchData,
  });
  
  @override
  State<PostinganResearchCoinScreen> createState() => _PostinganResearchCoinScreenState();
}

class _PostinganResearchCoinScreenState extends State<PostinganResearchCoinScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOpacity = 0.0;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Debug print untuk melihat data yang diterima
    print("📊 PostinganResearchCoinScreen - Data Received:");
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
    // Extract data dari researchData (sesuai dengan struktur dari Research Coin API)
    final imageUrl = widget.researchData['Image']?.toString() ?? 
                     widget.researchData['image']?.toString() ?? '';
    
    final logoCoinUrl = widget.researchData['Logo_coin']?.toString() ?? 
                        widget.researchData['logo_coin']?.toString() ?? '';
    
    final title = widget.researchData['title']?.toString() ?? 
                  widget.researchData['Title']?.toString() ?? 
                  'No Title';
    
    final fileLink = widget.researchData['file']?.toString() ?? 
                     widget.researchData['File']?.toString() ?? '';
    
    final uploader = widget.researchData['uploader']?.toString() ?? 
                     widget.researchData['uploaded_by']?.toString() ?? 
                     'Admin';
    
    final uploadDate = widget.researchData['upload_date']?.toString() ?? 
                       widget.researchData['created_at']?.toString() ?? '';
    
    final mongoId = widget.researchData['mongo_id']?.toString() ?? 
                    widget.researchData['_id']?.toString() ?? '';
    
    // Full image URL with base path
    final fullImageUrl = imageUrl.isNotEmpty 
        ? 'http://127.0.0.1:8080/$imageUrl' 
        : '';
    
    final fullLogoUrl = logoCoinUrl.isNotEmpty 
        ? 'http://127.0.0.1:8080/$logoCoinUrl' 
        : '';
    
    // Debug prints
    print("🖼️ Image URL: $fullImageUrl");
    print("🪙 Logo URL: $fullLogoUrl");
    print("📝 Title: $title");
    print("📄 File Link: $fileLink");
    
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
                              // Research Coin Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: ResearchCoinCardTheme.badgeDecoration(),
                                child: Text(
                                  'RESEARCH COIN',
                                  style: ResearchCoinColorStyle.badgeTextStyle.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Coin Logo + Title
                              Row(
                                children: [
                                  // Coin Logo (jika ada)
                                  if (fullLogoUrl.isNotEmpty) ...[
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: ResearchCoinColorStyle.greenNeon.withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: Image.network(
                                          fullLogoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(
                                              Icons.currency_bitcoin,
                                              color: ResearchCoinColorStyle.greenNeon,
                                              size: 28,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                  ],
                                  
                                  // Title
                                  Expanded(
                                    child: Text(
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
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Subtitle
                              Text(
                                'Cryptocurrency Research & Analysis',
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
                            if (uploadDate.isNotEmpty) ...[
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: ResearchCoinColorStyle.sourceText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(uploadDate),
                                style: const TextStyle(
                                  color: ResearchCoinColorStyle.sourceText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                            
                            const Spacer(),
                            
                            // Download PDF Button
                            if (fileLink.isNotEmpty)
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await _openPdfLink(fileLink);
                                },
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  size: 16,
                                ),
                                label: const Text('Download PDF'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ResearchCoinColorStyle.greenNeon,
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
                      
                      // Research Content Section
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Overview Section
                            _buildAnalysisSection(
                              number: '01',
                              title: 'Research Overview',
                              description: 'This comprehensive research document provides in-depth analysis and insights about $title. Access the full PDF report to explore detailed metrics, technical analysis, market trends, and strategic recommendations.',
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Key Highlights Section
                            _buildAnalysisSection(
                              number: '02',
                              title: 'Key Highlights',
                              description: 'The research covers fundamental analysis, tokenomics review, market positioning, competitive landscape, risk assessment, and future growth potential. Download the complete document for comprehensive insights.',
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // How to Access Section
                            _buildAnalysisSection(
                              number: '03',
                              title: 'Access Full Report',
                              description: 'Click the "Download PDF" button above to access the complete research report. The document includes detailed charts, data analysis, expert commentary, and actionable investment insights.',
                            ),
                            
                            const SizedBox(height: 48),
                            
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
          Icons.currency_bitcoin,
          size: 120,
          color: ResearchCoinColorStyle.sourceText.withOpacity(0.2),
        ),
      ),
    );
  }
  
  Widget _buildAnalysisSection({
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
                     widget.researchData['uploaded_by']?.toString() ?? 
                     'Admin';
    final uploadDate = widget.researchData['upload_date']?.toString() ?? 
                       widget.researchData['created_at']?.toString() ?? '';
    final title = widget.researchData['title']?.toString() ?? 
                  widget.researchData['Title']?.toString() ?? '';
    final fileLink = widget.researchData['file']?.toString() ?? 
                     widget.researchData['File']?.toString() ?? '';
    
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
            icon: Icons.currency_bitcoin,
            label: 'Coin/Token',
            value: title,
          ),
          
          const SizedBox(height: 12),
          
          _buildInfoRow(
            icon: Icons.description_outlined,
            label: 'Document Type',
            value: 'Research Report (PDF)',
          ),
          
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
          
          const SizedBox(height: 12),
          
          _buildInfoRow(
            icon: Icons.link,
            label: 'Document Link',
            value: fileLink.isNotEmpty ? 'Available' : 'Not available',
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
  
  Future<void> _openPdfLink(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print("✅ Opening PDF: $url");
      } else {
        print("❌ Cannot launch URL: $url");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot open PDF link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print("❌ Error opening PDF: $e");
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
}