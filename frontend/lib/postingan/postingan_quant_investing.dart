import 'package:flutter/material.dart';
import '../style/apps_colors_quant.dart';
import 'package:url_launcher/url_launcher.dart';

class PostinganQuantInvestingScreen extends StatefulWidget {
  final Map<String, dynamic> quantData;
  
  const PostinganQuantInvestingScreen({
    super.key,
    required this.quantData,
  });
  
  @override
  State<PostinganQuantInvestingScreen> createState() => _PostinganQuantInvestingScreenState();
}

class _PostinganQuantInvestingScreenState extends State<PostinganQuantInvestingScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOpacity = 0.0;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Debug print untuk melihat data yang diterima
    print("📊 PostinganQuantInvestingScreen - Data Received:");
    print(widget.quantData);
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
    // ✅ FIX: Pakai "Images" dengan S (sesuai database)
    final imageChart = widget.quantData['Images_chart']?.toString() ?? 
                      widget.quantData['images_chart']?.toString() ?? 
                      widget.quantData['Image_chart']?.toString() ?? 
                      widget.quantData['image_chart']?.toString() ?? '';
    
    final imageSampul = widget.quantData['Images_sampul']?.toString() ?? 
                        widget.quantData['images_sampul']?.toString() ?? 
                        widget.quantData['Image_sampul']?.toString() ?? 
                        widget.quantData['image_sampul']?.toString() ?? '';
    
    final judulPair = widget.quantData['Judul_pair']?.toString() ?? 
                      widget.quantData['judul_pair']?.toString() ?? 
                      'No Pair';
    
    final name = widget.quantData['Name']?.toString() ?? 
                 widget.quantData['name']?.toString() ?? 
                 'Unknown Strategy';
    
    final linkTradingView = widget.quantData['Link_Trading_View']?.toString() ?? 
                            widget.quantData['link_trading_view']?.toString() ?? '';
    
    final judul1 = widget.quantData['Judul_1']?.toString() ?? '';
    final deskripsi1 = widget.quantData['Deskripsi_1']?.toString() ?? '';
    final judul2 = widget.quantData['Judul_2']?.toString() ?? '';
    final deskripsi2 = widget.quantData['Deskripsi_2']?.toString() ?? '';
    final judul3 = widget.quantData['Judul_3']?.toString() ?? '';
    final deskripsi3 = widget.quantData['Deskripsi_3']?.toString() ?? '';
    final judul4 = widget.quantData['Judul_4']?.toString() ?? '';
    final deskripsi4 = widget.quantData['Deskripsi_4']?.toString() ?? '';
    
    final uploader = widget.quantData['uploader']?.toString() ?? 
                     widget.quantData['Name']?.toString() ?? 
                     'Admin';
    final uploadDate = widget.quantData['upload_date']?.toString() ?? 
                       widget.quantData['created_at']?.toString() ?? '';
    
    // ✅ Full image URL with base path - prioritas Images_chart (dengan S)
    final fullImageUrl = imageChart.isNotEmpty 
        ? 'http://127.0.0.1:8080/$imageChart' 
        : (imageSampul.isNotEmpty ? 'http://127.0.0.1:8080/$imageSampul' : '');
    
    // Debug prints
    print("🖼️ Image Chart Field: ${widget.quantData['Images_chart']}");
    print("🖼️ Image Sampul Field: ${widget.quantData['Images_sampul']}");
    print("🖼️ Full Image URL: $fullImageUrl");
    print("📝 Pair: $judulPair");
    print("📊 Strategy: $name");
    print("🔗 TradingView Link: $linkTradingView");
    
    return Scaffold(
      backgroundColor: QuantColorStyle.backgroundColor,
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
                backgroundColor: QuantColorStyle.backgroundColor,
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
                      // Hero Image (Chart)
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
                                color: QuantColorStyle.greenNeon,
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
                              // Quant Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: QuantCardTheme.quantBadgeDecoration(),
                                child: Text(
                                  'QUANT INVESTING',
                                  style: QuantColorStyle.badgeTextStyle.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Pair Title
                              Text(
                                judulPair,
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
                              
                              // Strategy Name
                              Text(
                                name,
                                style: TextStyle(
                                  color: QuantColorStyle.greenNeon,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      color: QuantColorStyle.greenNeon.withOpacity(0.5),
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
                  color: QuantColorStyle.backgroundColor,
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
                              color: QuantColorStyle.searchBorder,
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
                              color: QuantColorStyle.greenNeon,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              uploader,
                              style: const TextStyle(
                                color: QuantColorStyle.greenNeon,
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
                                color: QuantColorStyle.sourceText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(uploadDate),
                                style: const TextStyle(
                                  color: QuantColorStyle.sourceText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                            
                            const Spacer(),
                            
                            // ✅ TradingView Link Button (FIXED)
                            if (linkTradingView.isNotEmpty)
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await _openTradingViewLink(linkTradingView);
                                },
                                icon: const Icon(
                                  Icons.show_chart,
                                  size: 16,
                                ),
                                label: const Text('View Chart'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: QuantColorStyle.greenNeon,
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
                      
                      // Strategy Analysis Sections
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section 1
                            if (judul1.isNotEmpty) ...[
                              _buildAnalysisSection(
                                number: '01',
                                title: judul1,
                                description: deskripsi1,
                              ),
                              const SizedBox(height: 40),
                            ],
                            
                            // Section 2
                            if (judul2.isNotEmpty) ...[
                              _buildAnalysisSection(
                                number: '02',
                                title: judul2,
                                description: deskripsi2,
                              ),
                              const SizedBox(height: 40),
                            ],
                            
                            // Section 3
                            if (judul3.isNotEmpty) ...[
                              _buildAnalysisSection(
                                number: '03',
                                title: judul3,
                                description: deskripsi3,
                              ),
                              const SizedBox(height: 40),
                            ],
                            
                            // Section 4
                            if (judul4.isNotEmpty) ...[
                              _buildAnalysisSection(
                                number: '04',
                                title: judul4,
                                description: deskripsi4,
                              ),
                              const SizedBox(height: 48),
                            ],
                            
                            // Divider
                            Container(
                              height: 1,
                              color: QuantColorStyle.searchBorder,
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
              color: QuantColorStyle.backgroundColor.withOpacity(0.95),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: QuantColorStyle.greenNeon,
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
                        judulPair,
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
      color: QuantColorStyle.cardBackground,
      child: Center(
        child: Icon(
          Icons.show_chart,
          size: 120,
          color: QuantColorStyle.sourceText.withOpacity(0.2),
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
        gradient: QuantColorStyle.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: QuantColorStyle.searchBorder,
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
                  color: QuantColorStyle.greenNeon,
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
                  color: QuantColorStyle.subtitleText,
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
    final uploader = widget.quantData['uploader']?.toString() ?? 
                     widget.quantData['Name']?.toString() ?? 
                     'Admin';
    final uploadDate = widget.quantData['upload_date']?.toString() ?? 
                       widget.quantData['created_at']?.toString() ?? '';
    final judulPair = widget.quantData['Judul_pair']?.toString() ?? 
                      widget.quantData['judul_pair']?.toString() ?? '';
    final name = widget.quantData['Name']?.toString() ?? 
                 widget.quantData['name']?.toString() ?? '';
    
    // Calculate total content length
    final totalContent = [
      widget.quantData['Deskripsi_1']?.toString() ?? '',
      widget.quantData['Deskripsi_2']?.toString() ?? '',
      widget.quantData['Deskripsi_3']?.toString() ?? '',
      widget.quantData['Deskripsi_4']?.toString() ?? '',
    ].join(' ');
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: QuantColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: QuantColorStyle.searchBorder,
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
                  color: QuantColorStyle.greenNeon.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: QuantColorStyle.greenNeon,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'About this strategy',
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
            icon: Icons.trending_up,
            label: 'Trading Pair',
            value: judulPair,
          ),
          
          const SizedBox(height: 12),
          
          _buildInfoRow(
            icon: Icons.auto_graph,
            label: 'Strategy',
            value: name,
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
          color: QuantColorStyle.sourceText,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: QuantColorStyle.sourceText,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: QuantColorStyle.subtitleText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
  
  // ✅ FUNGSI UNTUK BUKA TRADINGVIEW LINK
  Future<void> _openTradingViewLink(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      
      // Check if TradingView app is installed (for mobile)
      // Jika di HP dan app installed, akan buka app
      // Jika tidak, buka di browser
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Buka di app/browser eksternal
        );
        print("✅ Opening TradingView: $url");
      } else {
        print("❌ Cannot launch URL: $url");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot open TradingView link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print("❌ Error opening TradingView: $e");
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