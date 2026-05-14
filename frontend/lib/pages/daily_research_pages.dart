// ============================================================
// FILE: lib/pages/daily_research_pages.dart
// ============================================================
import 'package:flutter/material.dart';
import '../hooks/daily_research_hook.dart';
import '../style/apps_color_daily_search.dart';
import '../postingan/postingan_daily_research.dart';
import '../utils/role_guard.dart';

class DailyResearchSection extends StatefulWidget {
  final String token;

  const DailyResearchSection({
    super.key,
    required this.token,
  });

  @override
  State<DailyResearchSection> createState() => _DailyResearchSectionState();
}

class _DailyResearchSectionState extends State<DailyResearchSection> {
  List<Map<String, dynamic>> researchCards    = [];
  List<Map<String, dynamic>> filteredResearch = [];
  bool isLoading    = true;
  String? errorMessage;

  final TextEditingController _searchController = TextEditingController();

  // Getter — selalu fresh dari token
  RolePermission get _perm => RolePermission.of(widget.token);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterResearch);
    _loadData(); // semua role fetch, backend yang filter
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading    = true;
      errorMessage = null;
    });

    try {
      final result = await Daily_Research_Exclusive_Hook.GetAllDailyResearch(
      );

      if (result['success'] == true) {
        final data = result['data'];
        if (data is List) {
          setState(() {
            researchCards    = data.map((item) {
              return item is Map<String, dynamic> ? item : <String, dynamic>{};
            }).toList();
            filteredResearch = researchCards;
            isLoading        = false;
          });
        } else {
          setState(() {
            errorMessage = 'Invalid data format';
            isLoading    = false;
          });
        }
      } else {
        setState(() {
          errorMessage = result['message'] ?? result['error'] ?? 'Unknown error';
          isLoading    = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading    = false;
      });
    }
  }

  void _filterResearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredResearch = query.isEmpty
          ? researchCards
          : researchCards.where((r) {
              final title    = (r['judul']     ?? '').toString().toLowerCase();
              final subtitle = (r['sub_judul'] ?? '').toString().toLowerCase();
              return title.contains(query) || subtitle.contains(query);
            }).toList();
    });
  }

  void _navigateToDetail(Map<String, dynamic> researchData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostinganDailyResearchScreen(researchData: researchData),
      ),
    ).then((_) => _loadData());
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
                      DailySearchColorStyle.primaryGreen.withOpacity(0.2),
                      DailySearchColorStyle.primaryGreen.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DailySearchColorStyle.primaryGreen.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(Icons.analytics_outlined,
                    color: DailySearchColorStyle.primaryGreen, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Research',
                      style: DailySearchColorStyle.sectionTitleStyle),
                  const SizedBox(height: 4),
                  Text(
                    'Latest market insights and analysis',
                    style: TextStyle(
                      color:      DailySearchColorStyle.subtitleText.withOpacity(0.5),
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
              if (!isLoading && errorMessage == null) _buildSearchBar(),

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
                        '/upload_daily_research',
                        arguments: widget.token,
                      ),
                      icon:  const Icon(Icons.add, size: 18),
                      label: const Text(
                        'Add Research',
                        style: TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DailySearchColorStyle.addButtonBackground,
                        foregroundColor: DailySearchColorStyle.addButtonText,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ).copyWith(
                        overlayColor: WidgetStateProperty.resolveWith<Color?>(
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
            color:       DailySearchColorStyle.primaryGreen,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color:        DailySearchColorStyle.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Icon(Icons.error_outline,
                    size: 64, color: Colors.red.withOpacity(0.7)),
              ),
              const SizedBox(height: 24),
              Text('Error loading data',
                  style: TextStyle(
                      color:      DailySearchColorStyle.subtitleText,
                      fontSize:   16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                errorMessage ?? 'Unknown error',
                style: TextStyle(color: Colors.red.withOpacity(0.8), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DailySearchColorStyle.primaryGreen,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredResearch.isEmpty) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color:        DailySearchColorStyle.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DailySearchColorStyle.cardBorder),
                ),
                child: Icon(Icons.analytics_outlined,
                    size:  64,
                    color: DailySearchColorStyle.subtitleText.withOpacity(0.3)),
              ),
              const SizedBox(height: 24),
              Text('No research data available',
                  style: TextStyle(
                      color:      DailySearchColorStyle.subtitleText,
                      fontSize:   16,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(
                _perm.isAdmin
                    ? 'Click "Add Research" to create your first entry'
                    : 'Belum ada research tersedia, coba lagi nanti',
                style: TextStyle(
                    color:    DailySearchColorStyle.descriptionText,
                    fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // ── GENERAL → info banner di atas grid ──────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
            itemCount: filteredResearch.length,
            itemBuilder: (context, index) {
              final card      = filteredResearch[index];
              final isPreview = card['is_preview'] == true;

              return _ResearchCard(
                imageUrl:    card['images_path']?.toString() ?? '',
                title:       card['judul']?.toString()      ?? 'No Title',
                description: card['sub_judul']?.toString()  ?? 'No Description',
                date:        card['date']?.toString()       ?? '',
                index:       index,
                isPreview:   isPreview,
                // General tidak bisa tap ke detail
                onTap: isPreview
                    ? () => _showUpgradeSnackbar()
                    : () => _navigateToDetail(card),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Banner info untuk general user ──────────────────────────────────────
  Widget _buildGeneralInfoBanner() {
    const Color green  = Color(0xFFBEFF00);
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
                color:    Colors.white.withOpacity(0.55),
                fontSize: 13,
              ),
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

  // ─── Search bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      width: 280, height: 44,
      decoration: BoxDecoration(
        color:        DailySearchColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: DailySearchColorStyle.cardBorder),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
            color: DailySearchColorStyle.titleText, fontSize: 14),
        decoration: InputDecoration(
          hintText:  'Search research...',
          hintStyle: const TextStyle(
              color: DailySearchColorStyle.subtitleText, fontSize: 14),
          prefixIcon: const Icon(Icons.search,
              color: DailySearchColorStyle.subtitleText, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      color: DailySearchColorStyle.subtitleText, size: 18),
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

// ─── _ResearchCard ────────────────────────────────────────────────────────────
// isPreview = true  → general user, card dikunci, ada lock overlay
// isPreview = false → exclusive/admin, card normal
class _ResearchCard extends StatefulWidget {
  final String imageUrl, title, description, date;
  final int    index;
  final bool   isPreview;
  final VoidCallback onTap;

  const _ResearchCard({
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.date,
    required this.index,
    required this.isPreview,
    required this.onTap,
  });

  @override
  State<_ResearchCard> createState() => _ResearchCardState();
}

class _ResearchCardState extends State<_ResearchCard> {
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
          decoration: DailySearchCardTheme.cardDecoration(
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
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: DailySearchColorStyle.cardBackground,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                      : null,
                                  color:       DailySearchColorStyle.primaryGreen,
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
                      decoration: DailySearchCardTheme.imageOverlayDecoration()),
                ),

                // ── Preview blur overlay untuk general ──────────────────────
                if (widget.isPreview)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
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
                                    color: green.withOpacity(0.35), width: 1.5),
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
                                letterSpacing: 0.3,
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

                // ── Konten card (judul, desc, date) — selalu tampil ─────────
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
                                DailySearchCardTheme.categoryBadgeDecoration(),
                            child: Text('DAILY RESEARCH',
                                style:
                                    DailySearchColorStyle.categoryLabelStyle),
                          ),
                          const SizedBox(height: 14),
                          Text(widget.title,
                              style:    DailySearchColorStyle.cardTitleStyle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Text(widget.description,
                              style: DailySearchColorStyle.cardDescriptionStyle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (widget.date.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size:  12,
                                    color: DailySearchColorStyle.descriptionText),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDate(widget.date),
                                  style: TextStyle(
                                      color:      DailySearchColorStyle.descriptionText,
                                      fontSize:   11,
                                      fontWeight: FontWeight.w400),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // ── Preview: tampilkan judul + tanggal di bawah overlay ─────
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
                              _formatDate(widget.date),
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
        color: DailySearchColorStyle.cardBackground,
        child: Center(
          child: Icon(Icons.analytics_outlined,
              size:  64,
              color: DailySearchColorStyle.subtitleText.withOpacity(0.1)),
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