// ============================================================
// FILE: lib/pages/market_outlook_pages.dart
// ============================================================
import 'package:flutter/material.dart';
import '../hooks/market_outloook_hook.dart';
import '../style/apps_colors_market_outlook.dart';
import '../postingan/postingan_market_outlook.dart';
import '../utils/role_guard.dart';

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
  List<Map<String, dynamic>> outlookCards   = [];
  List<Map<String, dynamic>> filteredOutlook = [];
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  RolePermission get _perm => RolePermission.of(widget.token);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterOutlook);
    _loadData(); // semua role fetch, backend yang filter
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    final result = await Market_Outlook_Hook.getAllMarketOutlook(
        token: widget.token);

    if (result['success'] == true) {
      setState(() {
        outlookCards    = List<Map<String, dynamic>>.from(result['data']);
        filteredOutlook = outlookCards;
        isLoading       = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void _filterOutlook() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredOutlook = query.isEmpty
          ? outlookCards
          : outlookCards.where((o) {
              final title  = (o['title']  ?? '').toLowerCase();
              final isi1   = (o['Isi_1']  ?? '').toLowerCase();
              final source = (o['Source'] ?? '').toLowerCase();
              return title.contains(query) ||
                  isi1.contains(query) ||
                  source.contains(query);
            }).toList();
    });
  }

  void _navigateToDetail(Map<String, dynamic> outlookData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PostinganMarketOutlookScreen(marketOutlookData: outlookData),
      ),
    ).then((_) => _loadData());
  }

  void _showUpgradeSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Hubungi admin untuk upgrade ke Exclusive'),
        backgroundColor: const Color(0xFF1A2E1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:       MainAxisSize.min,
      children: [
        _buildHeader(),
        const SizedBox(height: 40),
        _buildContent(),
      ],
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
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
                  gradient: LinearGradient(
                    colors: [
                      MarketOutlookColorStyle.greenNeon.withOpacity(0.2),
                      MarketOutlookColorStyle.greenNeon.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: MarketOutlookColorStyle.greenNeon.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(Icons.assessment_outlined,
                    color: MarketOutlookColorStyle.greenNeon, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Market Outlook',
                      style: MarketOutlookColorStyle.sectionTitleStyle),
                  const SizedBox(height: 4),
                  Text(
                    'Market analysis and future predictions',
                    style: TextStyle(
                      color:      MarketOutlookColorStyle.subtitleText
                          .withOpacity(0.5),
                      fontSize:   14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Row(
            children: [
              if (!isLoading) _buildSearchBar(),

              // Upload → ADMIN ONLY
              UploadGuard(
                token: widget.token,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/upload_market_outlook',
                        arguments: widget.token,
                      ),
                      icon:  const Icon(Icons.add, size: 18),
                      label: const Text(
                        'Add Outlook',
                        style: TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            MarketOutlookColorStyle.addButtonBackground,
                        foregroundColor: MarketOutlookColorStyle.addButtonText,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ).copyWith(
                        overlayColor:
                            WidgetStateProperty.resolveWith<Color?>(
                          (states) {
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
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Content ──────────────────────────────────────────────────────────────
  Widget _buildContent() {
    if (isLoading) {
      return SizedBox(
        height: 400,
        child: Center(
          child: CircularProgressIndicator(
            color:       MarketOutlookColorStyle.greenNeon,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (filteredOutlook.isEmpty) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color:        MarketOutlookColorStyle.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border:       Border.all(
                      color: MarketOutlookColorStyle.cardBorder),
                ),
                child: Icon(Icons.assessment_outlined,
                    size:  64,
                    color: MarketOutlookColorStyle.subtitleText
                        .withOpacity(0.3)),
              ),
              const SizedBox(height: 24),
              Text('No market outlook available',
                  style: TextStyle(
                      color:      MarketOutlookColorStyle.subtitleText,
                      fontSize:   16,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(
                _perm.isAdmin
                    ? 'Click "Add Outlook" to create your first entry'
                    : 'Belum ada outlook tersedia, coba lagi nanti',
                style: TextStyle(
                    color:    MarketOutlookColorStyle.descriptionText,
                    fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Banner info untuk general user
        if (_perm.isGeneral) _buildGeneralInfoBanner(),

        Padding(
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
            itemCount: filteredOutlook.length,
            itemBuilder: (context, index) {
              final outlook   = filteredOutlook[index];
              final isPreview = outlook['is_preview'] == true;

              return _MarketOutlookCard(
                index:    index,
                imageUrl: outlook['Images_1'] ?? '',
                title:    (outlook['title'] ?? outlook['Judul'] ?? '').toString(),
                subtitle: outlook['Isi_1'] ?? '',
                source:   outlook['Source'] ?? 'Unknown',
                date:     (outlook['Date'] ?? '').toString(),
                isPreview: isPreview,
                onTap: isPreview
                    ? () => _showUpgradeSnackbar()
                    : () => _navigateToDetail(outlook),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Banner info general ──────────────────────────────────────────────────
  Widget _buildGeneralInfoBanner() {
    const Color green   = Color(0xFFBEFF00);
    const Color surface = Color(0xFF0F1A0F);
    const Color border  = Color(0xFF1A2E1A);

    return Container(
      margin:  const EdgeInsets.fromLTRB(48, 0, 48, 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color:        surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded,
              color: green.withOpacity(0.7), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Kamu melihat preview. Upgrade ke Exclusive untuk baca konten lengkap.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showUpgradeSnackbar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color:        green,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(
                  color:      Color(0xFF080C08),
                  fontSize:   12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Search bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      width: 280, height: 44,
      decoration: MarketOutlookCardTheme.searchBarDecoration(),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
            color: MarketOutlookColorStyle.searchText, fontSize: 14),
        decoration: InputDecoration(
          hintText:  'Search outlook...',
          hintStyle: const TextStyle(
              color: MarketOutlookColorStyle.searchPlaceholder, fontSize: 14),
          prefixIcon: const Icon(Icons.search,
              color: MarketOutlookColorStyle.searchPlaceholder, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      color: MarketOutlookColorStyle.searchPlaceholder,
                      size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
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

// ─── _MarketOutlookCard ───────────────────────────────────────────────────────
class _MarketOutlookCard extends StatefulWidget {
  final int    index;
  final String imageUrl, title, subtitle, source, date;
  final bool   isPreview;
  final VoidCallback onTap;

  const _MarketOutlookCard({
    required this.index,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.source,
    required this.date,
    required this.isPreview,
    required this.onTap,
  });

  @override
  State<_MarketOutlookCard> createState() => _MarketOutlookCardState();
}

class _MarketOutlookCardState extends State<_MarketOutlookCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    const Color green = Color(0xFFBEFF00);

    return MouseRegion(
      cursor:  widget.isPreview
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit:  (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration:  const Duration(milliseconds: 300),
          transform: Matrix4.identity()
            ..translate(0.0, (!widget.isPreview && isHovered) ? -8.0 : 0.0),
          decoration: MarketOutlookCardTheme.cardDecoration(
            isHovered: !widget.isPreview && isHovered,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // ── Background image ────────────────────────────────────────
                Positioned.fill(
                  child: widget.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholder(),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: MarketOutlookColorStyle.cardBackground,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                      : null,
                                  color:       MarketOutlookColorStyle.greenNeon,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        )
                      : _buildPlaceholder(),
                ),

                // ── Gradient overlay ────────────────────────────────────────
                Positioned(
                  left: 0, right: 0, bottom: 0, height: 200,
                  child: Container(
                      decoration:
                          MarketOutlookCardTheme.imageOverlayDecoration()),
                ),

                // ── Preview lock overlay ────────────────────────────────────
                if (widget.isPreview)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color:        Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                shape:  BoxShape.circle,
                                color:  green.withOpacity(0.1),
                                border: Border.all(
                                    color: green.withOpacity(0.35),
                                    width: 1.5),
                              ),
                              child: Icon(Icons.lock_outline_rounded,
                                  color: green.withOpacity(0.8), size: 22),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Exclusive Only',
                              style: TextStyle(
                                color:      Colors.white.withOpacity(0.7),
                                fontSize:   12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color:        green,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Upgrade',
                                style: TextStyle(
                                  color:      Color(0xFF080C08),
                                  fontSize:   11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Konten normal (exclusive/admin) ─────────────────────────
                if (!widget.isPreview)
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
                            decoration:
                                MarketOutlookCardTheme.badgeDecoration(),
                            child: Text('MARKET OUTLOOK',
                                style:
                                    MarketOutlookColorStyle.badgeTextStyle),
                          ),
                          const SizedBox(height: 14),
                          Text(widget.title,
                              style: MarketOutlookColorStyle.cardTitleStyle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Text(widget.subtitle,
                              style:
                                  MarketOutlookColorStyle.cardSubtitleStyle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (widget.source.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.source_outlined,
                                    size:  12,
                                    color: MarketOutlookColorStyle
                                        .descriptionText),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(widget.source,
                                      style: MarketOutlookColorStyle
                                          .cardDescriptionStyle,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // ── Preview: judul + tanggal di bawah overlay ───────────────
                if (widget.isPreview)
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize:       MainAxisSize.min,
                        children: [
                          Text(widget.title,
                              style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (widget.date.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.date,
                              style: TextStyle(
                                  color:    Colors.white.withOpacity(0.5),
                                  fontSize: 11),
                            ),
                          ],
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

  Widget _buildPlaceholder() => Container(
        color: MarketOutlookColorStyle.cardBackground,
        child: Center(
          child: Icon(Icons.assessment_outlined,
              size:  64,
              color: MarketOutlookColorStyle.subtitleText.withOpacity(0.1)),
        ),
      );
}