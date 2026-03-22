import 'package:flutter/material.dart';
import '../hooks/quant_investing_hook.dart';
import '../style/app_typography_style.dart';
import '../style/apps_colors_quant.dart';
import '../postingan/postingan_quant_investing.dart'; 

class QuantInvestingSection extends StatefulWidget {
  final String token;
  
  const QuantInvestingSection({
    super.key,
    required this.token,
  });
  
  @override
  State<QuantInvestingSection> createState() => _QuantInvestingSectionState();
}

class _QuantInvestingSectionState extends State<QuantInvestingSection> {
  List<Map<String, dynamic>> quantCards = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> filteredQuants = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterQuants);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    final result = await Quant_Exclusive_Hook.GetAllQuantExclusive(
      token: widget.token,
    );

    print("📡 API Response: $result");
    
    if (result['success'] == true) {
      setState(() {
        quantCards = List<Map<String, dynamic>>.from(result['data']);
        filteredQuants = quantCards;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void _filterQuants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredQuants = quantCards;
      } else {
        filteredQuants = quantCards.where((quant) {
          final title = (quant['judul_pair'] ?? '').toLowerCase();
          final name = (quant['Name'] ?? '').toLowerCase();
          return title.contains(query) || name.contains(query);
        }).toList();
      }
    });
  }

  void _navigateToDetail(Map<String, dynamic> quantData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostinganQuantInvestingScreen(
          quantData: quantData,
        ),
      ),
    ).then((_) {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ HAPUS Scaffold & SingleChildScrollView
    return Container(
      color: QuantColorStyle.backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ✅ PENTING!
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        color: QuantColorStyle.subtitleText.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildSearchBar(),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
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
                          vertical: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          if (isLoading)
            SizedBox(
              height: 400,
              child: Center(
                child: CircularProgressIndicator(
                  color: QuantColorStyle.greenNeon,
                  strokeWidth: 3,
                ),
              ),
            )
          else if (filteredQuants.isEmpty)
            SizedBox(
              height: 400,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: QuantColorStyle.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: QuantColorStyle.cardBorder,
                        ),
                      ),
                      child: Icon(
                        Icons.show_chart_rounded,
                        size: 64,
                        color: QuantColorStyle.subtitleText.withOpacity(0.2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No quant strategies available',
                      style: TextStyle(
                        color: QuantColorStyle.subtitleText.withOpacity(0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Click "Add Strategy" to create your first entry',
                      style: TextStyle(
                        color: QuantColorStyle.descriptionText.withOpacity(0.4),
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
                shrinkWrap: true, // ✅ PENTING!
                physics: const NeverScrollableScrollPhysics(), // ✅ PENTING!
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.75,
                ),
                itemCount: filteredQuants.length,
                itemBuilder: (context, index) {
                  final quant = filteredQuants[index];
                  return _QuantCard(
                    imageUrl: quant['Image_sampul'] ?? '',
                    title: quant['judul_pair'] ?? '',
                    author: quant['Name'] ?? 'Unknown',
                    tradingViewLink: quant['Link_Trading_View'] ?? '',
                    index: index,
                    onTap: () => _navigateToDetail(quant),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 280,
      height: 44,
      decoration: QuantCardTheme.searchBarDecoration(),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: QuantColorStyle.searchText,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search strategies...',
          hintStyle: TextStyle(
            color: QuantColorStyle.searchPlaceholder,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: QuantColorStyle.searchPlaceholder,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: QuantColorStyle.searchPlaceholder,
                    size: 18,
                  ),
                  onPressed: _searchController.clear,
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
}

class _QuantCard extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String author;
  final String tradingViewLink;
  final int index;
  final VoidCallback onTap; // ✅ TAMBAHKAN CALLBACK

  const _QuantCard({
    required this.imageUrl,
    required this.title,
    required this.author,
    required this.tradingViewLink,
    required this.index,
    required this.onTap, // ✅ REQUIRED
  });

  @override
  State<_QuantCard> createState() => _QuantCardState();
}

class _QuantCardState extends State<_QuantCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click, // ✅ CURSOR POINTER
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap, // ✅ TRIGGER NAVIGATION
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          transform: Matrix4.identity()..translate(0.0, isHovered ? -8.0 : 0.0),
          decoration: QuantCardTheme.cardDecoration(
            index: widget.index,
            isHovered: isHovered,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(
                  child: widget.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.imageUrl,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: QuantColorStyle.cardBackground,
                          child: Center(
                            child: Icon(
                              Icons.show_chart,
                              size: 64,
                              color: QuantColorStyle.subtitleText.withOpacity(0.1),
                            ),
                          ),
                        ),
                ),
                
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 200,
                  child: Container(
                    decoration: QuantCardTheme.textOverlayDecoration(),
                  ),
                ),
                
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: QuantCardTheme.badgeDecoration(),
                          child: Text(
                            'QUANT ANALYSIS',
                            style: QuantColorStyle.badgeTextStyle.copyWith(
                              color: QuantColorStyle.quantBadgeText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.title,
                          style: QuantColorStyle.cardTitleStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: QuantColorStyle.greenNeon,
                              child: Text(
                                widget.author[0].toUpperCase(),
                                style: TextStyle(
                                  color: QuantColorStyle.addButtonText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.author,
                                style: QuantColorStyle.quantSourceStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
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
}