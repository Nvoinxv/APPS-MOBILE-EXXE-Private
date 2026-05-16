import 'package:flutter/material.dart';
import '../hooks/quant_investing_hook.dart';
import '../style/apps_colors_quant.dart';
import '../postingan/postingan_quant_investing.dart';

class QuantInvestingScreen extends StatefulWidget {
  final String token;
  
  const QuantInvestingScreen({
    super.key,
    required this.token,
  });
  
  @override
  State<QuantInvestingScreen> createState() => _QuantInvestingScreenState();
}

class _QuantInvestingScreenState extends State<QuantInvestingScreen> {
  List<Map<String, dynamic>> quantCards = [];
  List<Map<String, dynamic>> filteredQuant = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _loadQuantData();
    _searchController.addListener(_filterQuant);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuantData() async {
    setState(() => isLoading = true);
    
    final result = await Quant_Exclusive_Hook.GetAllQuantExclusive(
    );
    
    print("📡 API Response: $result");
    
    if (result['success'] == true) {
      setState(() {
        quantCards = List<Map<String, dynamic>>.from(result['data']);
        filteredQuant = quantCards;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message'] ?? result['error']}'),
            backgroundColor: QuantColorStyle.chartRed,
          ),
        );
      }
    }
  }

  void _filterQuant() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredQuant = quantCards;
      } else {
        filteredQuant = quantCards.where((quant) {
          final pair = (quant['judul_pair'] ?? '').toLowerCase();
          final name = (quant['Name'] ?? '').toLowerCase();
          return pair.contains(query) || name.contains(query);
        }).toList();
      }
    });
  }

  // ✅ FUNGSI NAVIGASI KE DETAIL PAGE
  void _navigateToDetail(Map<String, dynamic> quantData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostinganQuantInvestingScreen(
          quantData: quantData,
        ),
      ),
    ).then((_) {
      // Reload data setelah kembali dari detail (optional)
      _loadQuantData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuantColorStyle.backgroundColor,
      body: Column(
        children: [
          _buildTopNavBar(),
          
          Expanded(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(48, 40, 48, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EXXE Quant Investing',
                              style: QuantColorStyle.sectionTitleStyle,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Quantitative Trading Strategies & Analysis',
                              style: TextStyle(
                                color: QuantColorStyle.subtitleText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),

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

                  Expanded(
                    child: isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: QuantColorStyle.greenNeon,
                              strokeWidth: 3,
                            ),
                          )
                        : filteredQuant.isEmpty
                            ? _buildEmptyState()
                            : _buildQuantGrid(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: QuantColorStyle.backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: QuantColorStyle.cardBorder,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          children: [
            _buildLogo(),
            const SizedBox(width: 60),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildNavButton(
                    label: 'Home',
                    icon: Icons.home_outlined,
                    onTap: () {
                      Navigator.pushReplacementNamed(
                        context,
                        '/home',
                        arguments: widget.token,
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildNavButton(
                    label: 'Quant Investing',
                    icon: Icons.show_chart,
                    isActive: true,
                    onTap: () {},
                  ),
                ],
              ),
            ),
            _buildUserProfile(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                QuantColorStyle.darkGreen,
                QuantColorStyle.primaryGreen.withOpacity(0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: QuantColorStyle.primaryGreen.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.show_chart,
            color: QuantColorStyle.greenNeon,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EXXE.LAB',
              style: TextStyle(
                color: QuantColorStyle.greenNeon,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Quant Portal',
              style: TextStyle(
                color: QuantColorStyle.descriptionText,
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required String label,
    required IconData icon,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isActive 
                ? QuantColorStyle.darkGreen.withOpacity(0.6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive 
                  ? QuantColorStyle.greenNeon.withOpacity(0.4)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive 
                    ? QuantColorStyle.greenNeon
                    : QuantColorStyle.descriptionText,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isActive 
                      ? QuantColorStyle.greenNeon
                      : QuantColorStyle.descriptionText,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: QuantColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: QuantColorStyle.cardBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: QuantColorStyle.greenNeon,
            child: Text(
              widget.token[0].toUpperCase(),
              style: TextStyle(
                color: QuantColorStyle.addButtonText,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.token.split('@')[0],
                style: TextStyle(
                  color: QuantColorStyle.titleText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Admin',
                style: TextStyle(
                  color: QuantColorStyle.greenNeon.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: QuantColorStyle.descriptionText,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isSearchFocused = hasFocus);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 280,
        height: 44,
        decoration: QuantCardTheme.searchBarDecoration(isFocused: _isSearchFocused),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(
            color: QuantColorStyle.searchText,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Search strategies...',
            hintStyle: const TextStyle(
              color: QuantColorStyle.searchPlaceholder,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: _isSearchFocused 
                  ? QuantColorStyle.greenNeon
                  : QuantColorStyle.searchPlaceholder,
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: QuantColorStyle.searchPlaceholder,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
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
            '/upload_quant',
            arguments: widget.token,
          );
        },
        icon: const Icon(Icons.add, size: 18),
        label: const Text(
          'Add Strategy',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: QuantColorStyle.addButtonBackground,
          foregroundColor: QuantColorStyle.addButtonText,
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
                return Colors.white.withOpacity(0.1);
              }
              return null;
            },
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
            Icons.analytics_outlined,
            size: 64,
            color: QuantColorStyle.descriptionText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty 
                ? 'No quant strategies available' 
                : 'No strategies found',
            style: const TextStyle(
              color: QuantColorStyle.subtitleText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Click "Add Strategy" to create your first entry'
                : 'Try different search keywords',
            style: const TextStyle(
              color: QuantColorStyle.descriptionText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 48, 32),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 0.85,
        ),
        itemCount: filteredQuant.length,
        itemBuilder: (context, index) {
          final quant = filteredQuant[index];
          return _QuantCard(
            imageUrl: quant['Image_sampul'] ?? '',
            pair: quant['judul_pair'] ?? '',
            name: quant['Name'] ?? '',
            linkTradingView: quant['Link_Trading_View'] ?? '',
            onTap: () => _navigateToDetail(quant), // ✅ PASS DATA KE DETAIL
          );
        },
      ),
    );
  }
}

class _QuantCard extends StatefulWidget {
  final String imageUrl;
  final String pair;
  final String name;
  final String linkTradingView;
  final VoidCallback onTap;

  const _QuantCard({
    required this.imageUrl,
    required this.pair,
    required this.name,
    required this.linkTradingView,
    required this.onTap,
  });

  @override
  State<_QuantCard> createState() => _QuantCardState();
}

class _QuantCardState extends State<_QuantCard> {
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
          decoration: QuantCardTheme.cardDecoration(isHovered: isHovered),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
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
                                return _buildChartPlaceholder();
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
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                            )
                          : _buildChartPlaceholder(),
                    ),
                    Container(
                      decoration: QuantCardTheme.imageOverlayDecoration(),
                    ),
                  ],
                ),
              ),

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
                            decoration: QuantCardTheme.badgeDecoration(),
                            child: Text(
                              'QUANT',
                              style: QuantColorStyle.badgeTextStyle,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.pair,
                            style: QuantColorStyle.pairStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Text(
                        widget.name,
                        style: QuantColorStyle.cardSubtitleStyle,
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

  Widget _buildChartPlaceholder() {
    return Container(
      color: QuantColorStyle.cardBackground,
      child: Center(
        child: Icon(
          Icons.candlestick_chart,
          size: 64,
          color: QuantColorStyle.descriptionText.withOpacity(0.3),
        ),
      ),
    );
  }
}