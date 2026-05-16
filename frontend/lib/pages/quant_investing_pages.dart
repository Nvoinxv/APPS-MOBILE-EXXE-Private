// ============================================================
// FILE: lib/pages/quant_investing_pages.dart
// ============================================================
import 'package:flutter/material.dart';
import '../hooks/quant_investing_hook.dart';
import '../style/app_typography_style.dart';
import '../style/apps_colors_quant.dart';
import '../postingan/postingan_quant_investing.dart';
import '../utils/role_guard.dart';

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
  List<Map<String, dynamic>> quantCards     = [];
  List<Map<String, dynamic>> filteredQuants = [];
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  late final RolePermission _perm;

  @override
  void initState() {
    super.initState();
    _perm = RolePermission.of(widget.token);
    _searchController.addListener(_filterQuants);
    if (_perm.canView) _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final result = await Quant_Exclusive_Hook.GetAllQuantExclusive();
    if (result['success'] == true) {
      setState(() {
        quantCards     = List<Map<String, dynamic>>.from(result['data']);
        filteredQuants = quantCards;
        isLoading      = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void _filterQuants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredQuants = query.isEmpty
          ? quantCards
          : quantCards.where((q) {
              final title = (q['judul_pair'] ?? '').toLowerCase();
              final name  = (q['Name']       ?? '').toLowerCase();
              return title.contains(query) || name.contains(query);
            }).toList();
    });
  }

  void _navigateToDetail(Map<String, dynamic> quantData) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              PostinganQuantInvestingScreen(quantData: quantData)),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    // ── GENERAL → centered lock banner ───────────────────────────────────────
    if (_perm.isGeneral) {
      return Container(
        color:   QuantColorStyle.backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header simplified tanpa controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: _buildHeaderLocked(),
            ),
            const SizedBox(height: 48),
            // Banner center + constrained width
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SectionLockBanner(
                    sectionName: 'EXXE Quant Investing',
                    token: widget.token,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      );
    }

    // ── ADMIN / EXCLUSIVE → konten penuh ─────────────────────────────────────
    return Container(
      color:   QuantColorStyle.backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:       MainAxisSize.min,
        children: [
          _buildHeader(showControls: true),
          const SizedBox(height: 40),
          if (isLoading)
            SizedBox(
              height: 400,
              child: Center(
                child: CircularProgressIndicator(
                    color: QuantColorStyle.greenNeon, strokeWidth: 3),
              ),
            )
          else if (filteredQuants.isEmpty)
            _buildEmptyState()
          else
            _buildGrid(),
        ],
      ),
    );
  }

  // ─── Header untuk general (locked) — tanpa search & upload ───────────────
  Widget _buildHeaderLocked() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              QuantColorStyle.greenNeon.withOpacity(0.2),
              QuantColorStyle.greenNeon.withOpacity(0.05),
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: QuantColorStyle.greenNeon.withOpacity(0.3),
                width: 1.5),
          ),
          child: Icon(Icons.auto_graph_rounded,
              color: QuantColorStyle.greenNeon, size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EXXE Quant Investing',
                style: QuantColorStyle.sectionTitleStyle),
            const SizedBox(height: 4),
            Text(
              'Quantitative Trading Strategies & Analysis',
              style: TextStyle(
                  color:      QuantColorStyle.subtitleText.withOpacity(0.5),
                  fontSize:   14,
                  fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Header full (admin/exclusive) ───────────────────────────────────────
  Widget _buildHeader({required bool showControls}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    QuantColorStyle.greenNeon.withOpacity(0.2),
                    QuantColorStyle.greenNeon.withOpacity(0.05),
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: QuantColorStyle.greenNeon.withOpacity(0.3),
                      width: 1.5),
                ),
                child: Icon(Icons.auto_graph_rounded,
                    color: QuantColorStyle.greenNeon, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EXXE Quant Investing',
                      style: QuantColorStyle.sectionTitleStyle),
                  const SizedBox(height: 4),
                  Text(
                    'Quantitative Trading Strategies & Analysis',
                    style: TextStyle(
                        color:      QuantColorStyle.subtitleText.withOpacity(0.5),
                        fontSize:   14,
                        fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ],
          ),

          if (showControls)
            Row(
              children: [
                _buildSearchBar(),
                const SizedBox(width: 16),
                UploadGuard(
                  token: widget.token,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                        context, '/upload_quant',
                        arguments: widget.token),
                    icon:  const Icon(Icons.add, size: 18),
                    label: const Text('Add Strategy',
                        style: TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuantColorStyle.addButtonBackground,
                      foregroundColor: QuantColorStyle.addButtonText,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.builder(
        shrinkWrap: true,
        physics:    const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   3,
          crossAxisSpacing: 24,
          mainAxisSpacing:  24,
          childAspectRatio: 0.75,
        ),
        itemCount: filteredQuants.length,
        itemBuilder: (context, index) {
          final quant = filteredQuants[index];
          return _QuantCard(
            imageUrl:        quant['Image_sampul']      ?? '',
            title:           quant['judul_pair']        ?? '',
            author:          quant['Name']              ?? 'Unknown',
            tradingViewLink: quant['Link_Trading_View'] ?? '',
            index:           index,
            onTap:           () => _navigateToDetail(quant),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:        QuantColorStyle.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border:       Border.all(color: QuantColorStyle.cardBorder),
              ),
              child: Icon(Icons.show_chart_rounded,
                  size:  64,
                  color: QuantColorStyle.subtitleText.withOpacity(0.2)),
            ),
            const SizedBox(height: 24),
            Text('No quant strategies available',
                style: TextStyle(
                    color:      QuantColorStyle.subtitleText.withOpacity(0.7),
                    fontSize:   16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(
              _perm.isAdmin
                  ? 'Click "Add Strategy" to create your first entry'
                  : 'Belum ada strategi tersedia, coba lagi nanti',
              style: TextStyle(
                  color:    QuantColorStyle.descriptionText.withOpacity(0.4),
                  fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 280, height: 44,
      decoration: QuantCardTheme.searchBarDecoration(),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: QuantColorStyle.searchText, fontSize: 14),
        decoration: InputDecoration(
          hintText:  'Search strategies...',
          hintStyle: TextStyle(
              color: QuantColorStyle.searchPlaceholder, fontSize: 14),
          prefixIcon: Icon(Icons.search,
              color: QuantColorStyle.searchPlaceholder, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear,
                      color: QuantColorStyle.searchPlaceholder, size: 18),
                  onPressed: _searchController.clear,
                )
              : null,
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

// ─── _QuantCard ───────────────────────────────────────────────────────────────
class _QuantCard extends StatefulWidget {
  final String imageUrl, title, author, tradingViewLink;
  final int    index;
  final VoidCallback onTap;

  const _QuantCard({
    required this.imageUrl,
    required this.title,
    required this.author,
    required this.tradingViewLink,
    required this.index,
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
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit:  (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration:  const Duration(milliseconds: 300),
          transform: Matrix4.identity()
            ..translate(0.0, isHovered ? -8.0 : 0.0),
          decoration: QuantCardTheme.cardDecoration(
              index: widget.index, isHovered: isHovered),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(
                  child: widget.imageUrl.isNotEmpty
                      ? Image.network(widget.imageUrl, fit: BoxFit.cover)
                      : Container(
                          color: QuantColorStyle.cardBackground,
                          child: Center(
                            child: Icon(Icons.show_chart,
                                size:  64,
                                color: QuantColorStyle.subtitleText
                                    .withOpacity(0.1)),
                          ),
                        ),
                ),
                Positioned(
                    left: 0, right: 0, bottom: 0, height: 200,
                    child: Container(
                        decoration: QuantCardTheme.textOverlayDecoration())),
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize:       MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: QuantCardTheme.badgeDecoration(),
                          child: Text('QUANT ANALYSIS',
                              style: QuantColorStyle.badgeTextStyle.copyWith(
                                  color: QuantColorStyle.quantBadgeText)),
                        ),
                        const SizedBox(height: 14),
                        Text(widget.title,
                            style:    QuantColorStyle.cardTitleStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                        Row(children: [
                          CircleAvatar(
                            radius:          12,
                            backgroundColor: QuantColorStyle.greenNeon,
                            child: Text(
                              widget.author[0].toUpperCase(),
                              style: TextStyle(
                                  color:      QuantColorStyle.addButtonText,
                                  fontSize:   10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(widget.author,
                                style:    QuantColorStyle.quantSourceStyle,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
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