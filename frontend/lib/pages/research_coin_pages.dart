// ============================================================
// FILE: lib/pages/research_coin_pages.dart
// ============================================================
import 'package:flutter/material.dart';
import '../hooks/research_coin_hook.dart';
import '../style/apps_colors_research_coin.dart';
import '../postingan/postingan_research_coin.dart';
import '../utils/role_guard.dart';

class ResearchCoinSection extends StatefulWidget {
  final String token;

  const ResearchCoinSection({
    super.key,
    required this.token,
  });

  @override
  State<ResearchCoinSection> createState() => _ResearchCoinSectionState();
}

class _ResearchCoinSectionState extends State<ResearchCoinSection> {
  List<Map<String, dynamic>> researchCoinCards     = [];
  List<Map<String, dynamic>> filteredResearchCoins = [];
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  RolePermission get _perm => RolePermission.of(widget.token);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterResearchCoins);
    if (_perm.canView) _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    final result = await Research_Coin_Hook.GetAllResearchCoin();

    if (result['success'] == true) {
      setState(() {
        researchCoinCards     = List<Map<String, dynamic>>.from(result['data']);
        filteredResearchCoins = researchCoinCards;
        isLoading             = false;
      });
    } else {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? result['error'] ?? 'Failed to load data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterResearchCoins() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredResearchCoins = query.isEmpty
          ? List.from(researchCoinCards)
          : researchCoinCards.where((r) {
              final title = (r['title'] ?? '').toString().toLowerCase();
              final file  = (r['file']  ?? '').toString().toLowerCase();
              return title.contains(query) || file.contains(query);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── GENERAL → centered lock banner ───────────────────────────────────────
    if (_perm.isGeneral) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: _buildHeaderLocked(),
          ),
          const SizedBox(height: 48),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SectionLockBanner(
                  sectionName: 'Research Coin',
                  token: widget.token,
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      );
    }

    // ── ADMIN / EXCLUSIVE → konten penuh ─────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        _buildHeader(showControls: true),
        // Stats bar — jumlah total research
        if (!isLoading && researchCoinCards.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 16, 48, 0),
            child: _buildStatsBar(),
          ),
        const SizedBox(height: 32),
        _buildContent(),
      ],
    );
  }

  // ─── Stats bar (konsisten sama News) ──────────────────────────────────────
  Widget _buildStatsBar() {
    return Row(
      children: [
        _StatChip(
          label: '${researchCoinCards.length} Research Reports',
          color: ResearchCoinColorStyle.greenNeon,
          icon:  Icons.currency_bitcoin,
        ),
        const SizedBox(width: 12),
        _StatChip(
          label: 'PDF Available',
          color: ResearchCoinColorStyle.greenNeon.withOpacity(0.7),
          icon:  Icons.picture_as_pdf_outlined,
        ),
      ],
    );
  }

  // ─── Header untuk general (locked) ────────────────────────────────────────
  Widget _buildHeaderLocked() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ResearchCoinColorStyle.greenNeon.withOpacity(0.2),
                ResearchCoinColorStyle.greenNeon.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ResearchCoinColorStyle.greenNeon.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(Icons.currency_bitcoin,
              color: ResearchCoinColorStyle.greenNeon, size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Research Coin',
                style: ResearchCoinColorStyle.sectionTitleStyle),
            const SizedBox(height: 4),
            Text(
              'In-depth cryptocurrency research & analysis reports',
              style: TextStyle(
                color:      ResearchCoinColorStyle.subtitleText.withOpacity(0.5),
                fontSize:   14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Header full (admin/exclusive) ────────────────────────────────────────
  Widget _buildHeader({required bool showControls}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Judul + subtitle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ResearchCoinColorStyle.greenNeon.withOpacity(0.2),
                      ResearchCoinColorStyle.greenNeon.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ResearchCoinColorStyle.greenNeon.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(Icons.currency_bitcoin,
                    color: ResearchCoinColorStyle.greenNeon, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Research Coin',
                      style: ResearchCoinColorStyle.sectionTitleStyle),
                  const SizedBox(height: 4),
                  Text(
                    'In-depth cryptocurrency research & analysis reports',
                    style: TextStyle(
                      color:      ResearchCoinColorStyle.subtitleText.withOpacity(0.5),
                      fontSize:   14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Search + Upload (hanya kalau showControls)
          if (showControls)
            Row(
              children: [
                _buildSearchBar(),
                const SizedBox(width: 16),
                UploadGuard(
                  token: widget.token,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/upload_research_coin',
                        arguments: widget.token,
                      ),
                      icon:  const Icon(Icons.add, size: 18),
                      label: const Text(
                        'Add Research Coin',
                        style: TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            ResearchCoinColorStyle.addButtonBackground,
                        foregroundColor: ResearchCoinColorStyle.addButtonText,
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
            color:       ResearchCoinColorStyle.greenNeon,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (filteredResearchCoins.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: filteredResearchCoins.map((research) {
          return _ResearchCoinCard(
            researchData: research,
            token:        widget.token,
            onDelete:     _loadData,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PostinganResearchCoinScreen(researchData: research),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Empty state — konsisten sama News ────────────────────────────────────
  Widget _buildEmptyState() {
    final isAdmin = _perm.isAdmin;
    return SizedBox(
      height: 480,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon container dengan border — konsisten sama News
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color:        ResearchCoinColorStyle.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ResearchCoinColorStyle.greenNeon.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.currency_bitcoin,
                  size:  48,
                  color: ResearchCoinColorStyle.greenNeon.withOpacity(0.35),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              _searchController.text.isEmpty
                  ? 'No research coins available'
                  : 'No research found',
              style: TextStyle(
                  color:      ResearchCoinColorStyle.subtitleText,
                  fontSize:   18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty
                  ? (isAdmin
                      ? 'Click "Add Research Coin" to publish your first research'
                      : 'Belum ada research coin tersedia, coba lagi nanti')
                  : 'Try different search keywords',
              style: TextStyle(
                  color:    ResearchCoinColorStyle.descriptionText,
                  fontSize: 14),
            ),

            // Tombol shortcut untuk admin
            if (isAdmin && _searchController.text.isEmpty) ...[
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/upload_research_coin',
                  arguments: widget.token,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ResearchCoinColorStyle.greenNeon,
                        ResearchCoinColorStyle.greenNeon.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color:      ResearchCoinColorStyle.greenNeon.withOpacity(0.25),
                        blurRadius: 16,
                        offset:     const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add,
                          color: ResearchCoinColorStyle.addButtonText,
                          size:  18),
                      const SizedBox(width: 8),
                      Text(
                        'Add Research Coin',
                        style: TextStyle(
                          color:         ResearchCoinColorStyle.addButtonText,
                          fontSize:      14,
                          fontWeight:    FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Search bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      width: 280, height: 44,
      decoration: ResearchCoinCardTheme.searchBarDecoration(
          isFocused: _searchController.text.isNotEmpty),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
            color: ResearchCoinColorStyle.searchText, fontSize: 14),
        decoration: InputDecoration(
          hintText:  'Search research coins...',
          hintStyle: const TextStyle(
              color: ResearchCoinColorStyle.searchPlaceholder, fontSize: 14),
          prefixIcon: const Icon(Icons.search,
              color: ResearchCoinColorStyle.searchPlaceholder, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      color: ResearchCoinColorStyle.searchPlaceholder,
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

// ─── Stat Chip — sama persis punya News ──────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color:      color,
                  fontSize:   12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── _ResearchCoinCard tidak ada perubahan ────────────────────────────────────
class _ResearchCoinCard extends StatefulWidget {
  final Map<String, dynamic> researchData;
  final String       token;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ResearchCoinCard({
    required this.researchData,
    required this.token,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<_ResearchCoinCard> createState() => _ResearchCoinCardState();
}

class _ResearchCoinCardState extends State<_ResearchCoinCard> {
  bool isHovered = false;

  Future<void> _handleDelete() async {
    final mongoId = widget.researchData['mongo_id'] ?? '';
    final title   = widget.researchData['title']    ?? 'this research';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ResearchCoinColorStyle.cardBackground,
        title: const Text('Delete Research',
            style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "$title"?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final result = await Research_Coin_Hook.DeleteResearchCoin(
        researchId: mongoId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            result['success'] == true
                ? 'Research deleted successfully'
                : result['message'] ?? 'Failed to delete',
          ),
          backgroundColor:
              result['success'] == true ? Colors.green : Colors.red,
        ));
        if (result['success'] == true) widget.onDelete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl    = widget.researchData['Image']?.toString()       ?? '';
    final logoCoinUrl = widget.researchData['Logo_coin']?.toString()   ?? '';
    final title       = widget.researchData['title']?.toString()       ?? 'No Title';
    final uploadedBy  = widget.researchData['uploaded_by']?.toString() ?? 'Admin';
    final createdAt   = widget.researchData['created_at']?.toString()  ?? '';
    final fileLink    = widget.researchData['file']?.toString()        ?? '';

    final fullImageUrl = imageUrl.isNotEmpty
        ? 'http://127.0.0.1:8080/$imageUrl'
        : '';
    final fullLogoUrl = logoCoinUrl.isNotEmpty
        ? 'http://127.0.0.1:8080/$logoCoinUrl'
        : '';

    final perm = RolePermission.of(widget.token);

    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit:  (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 32),
          child: AnimatedContainer(
            duration:  const Duration(milliseconds: 300),
            curve:     Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..translate(0.0, isHovered ? -4.0 : 0.0),
            decoration: BoxDecoration(
              gradient:     ResearchCoinColorStyle.cardGradient1,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isHovered
                    ? ResearchCoinColorStyle.greenNeon.withOpacity(0.3)
                    : ResearchCoinColorStyle.searchBorder,
                width: isHovered ? 1.5 : 1,
              ),
              boxShadow: isHovered
                  ? [BoxShadow(
                      color:      ResearchCoinColorStyle.greenNeon.withOpacity(0.1),
                      blurRadius: 20,
                      offset:     const Offset(0, 8),
                    )]
                  : [BoxShadow(
                      color:      Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset:     const Offset(0, 4),
                    )],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image kiri (40%) ──────────────────────────────────────
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft:    Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                    child: fullImageUrl.isNotEmpty
                        ? Image.network(
                            fullImageUrl,
                            height: 280,
                            fit:    BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildImagePlaceholder(),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 280,
                                color:  ResearchCoinColorStyle.cardBackground,
                                child:  Center(
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                        : null,
                                    color:       ResearchCoinColorStyle.greenNeon,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          )
                        : _buildImagePlaceholder(),
                  ),
                ),

                // ── Konten kanan (60%) ────────────────────────────────────
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration:
                              ResearchCoinCardTheme.badgeDecoration(),
                          child: Text('RESEARCH COIN',
                              style:
                                  ResearchCoinColorStyle.badgeTextStyle),
                        ),

                        const SizedBox(height: 16),

                        // Title + Logo
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (fullLogoUrl.isNotEmpty) ...[
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color:        Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border:       Border.all(
                                      color: ResearchCoinColorStyle.greenNeon,
                                      width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ResearchCoinColorStyle.greenNeon
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.network(
                                    fullLogoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.currency_bitcoin,
                                      color: ResearchCoinColorStyle.greenNeon,
                                      size:  24,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(title,
                                  style: const TextStyle(
                                    color:      Colors.white,
                                    fontSize:   28,
                                    fontWeight: FontWeight.bold,
                                    height:     1.2,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'Comprehensive cryptocurrency research & analysis report',
                          style: TextStyle(
                            color:      ResearchCoinColorStyle.subtitleText
                                .withOpacity(0.9),
                            fontSize:   15,
                            fontWeight: FontWeight.w400,
                            height:     1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 20),

                        // Metadata
                        Row(
                          children: [
                            if (uploadedBy.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:        ResearchCoinColorStyle.greenNeon
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.person_outline,
                                    size:  14,
                                    color: ResearchCoinColorStyle.greenNeon),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(uploadedBy,
                                      style: const TextStyle(
                                          color:      Colors.white,
                                          fontSize:   13,
                                          fontWeight: FontWeight.w600)),
                                  Text('Research Analyst',
                                      style: TextStyle(
                                          color: ResearchCoinColorStyle
                                              .greenNeon.withOpacity(0.8),
                                          fontSize:   11,
                                          fontWeight: FontWeight.w400)),
                                ],
                              ),
                            ],
                            const Spacer(),
                            if (createdAt.isNotEmpty) ...[
                              Icon(Icons.calendar_today_outlined,
                                  size:  14,
                                  color: ResearchCoinColorStyle.sourceText),
                              const SizedBox(width: 6),
                              Text(_formatDate(createdAt),
                                  style: const TextStyle(
                                      color:    ResearchCoinColorStyle.sourceText,
                                      fontSize: 12)),
                            ],
                          ],
                        ),

                        // PDF badge
                        if (fileLink.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color:        Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border:       Border.all(
                                  color: ResearchCoinColorStyle.greenNeon
                                      .withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.picture_as_pdf,
                                    size:  12,
                                    color: ResearchCoinColorStyle.greenNeon
                                        .withOpacity(0.8)),
                                const SizedBox(width: 6),
                                Text('PDF Research Report',
                                    style: TextStyle(
                                      color: ResearchCoinColorStyle.greenNeon
                                          .withOpacity(0.9),
                                      fontSize:   11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                    )),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // CTA + Delete
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text('View full research',
                                      style: TextStyle(
                                        color:      ResearchCoinColorStyle.greenNeon,
                                        fontSize:   14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      )),
                                  const SizedBox(width: 8),
                                  Icon(Icons.arrow_forward,
                                      size:  16,
                                      color: ResearchCoinColorStyle.greenNeon),
                                ],
                              ),
                            ),
                            if (perm.isAdmin)
                              IconButton(
                                onPressed: _handleDelete,
                                icon:  const Icon(Icons.delete_outline),
                                color: Colors.red.withOpacity(0.8),
                                style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.red.withOpacity(0.1)),
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

  Widget _buildImagePlaceholder() => Container(
        height: 280,
        color:  ResearchCoinColorStyle.cardBackground,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.currency_bitcoin,
                  size:  64,
                  color: ResearchCoinColorStyle.greenNeon.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text('Research Coin',
                  style: TextStyle(
                      color:    ResearchCoinColorStyle.subtitleText
                          .withOpacity(0.5),
                      fontSize: 14)),
            ],
          ),
        ),
      );

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    try {
      final p    = DateTime.parse(date);
      final diff = DateTime.now().difference(p);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7)  return '${diff.inDays}d ago';
      return '${p.day}/${p.month}/${p.year}';
    } catch (_) {
      return date;
    }
  }
}