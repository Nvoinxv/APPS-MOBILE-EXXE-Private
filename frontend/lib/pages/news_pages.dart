import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../hooks/news_hook.dart';
import '../hooks/news_ai_hook.dart';
import '../style/apps_color_news.dart';
import '../postingan/postingan_news.dart';

// ---------------------------------------------------------------------------
// Unified News Item (tidak berubah)
// ---------------------------------------------------------------------------

enum NewsSource { database, ai }

class UnifiedNewsItem {
  final NewsSource source;
  final Map<String, dynamic>? dbData;
  final GeneratedNewsArticle? aiData;

  const UnifiedNewsItem.fromDb(this.dbData)
      : source = NewsSource.database,
        aiData = null;

  const UnifiedNewsItem.fromAi(this.aiData)
      : source = NewsSource.ai,
        dbData = null;

  String get title {
    if (source == NewsSource.ai) return aiData?.generatedTitle ?? '';
    final d = dbData!;
    return d['Title']?.toString() ?? d['title']?.toString() ?? 'No Title';
  }

  String get description {
    if (source == NewsSource.ai) return aiData?.generatedSummary ?? '';
    final d = dbData!;
    return d['Description']?.toString() ?? d['description']?.toString() ?? '';
  }

  String get newsSource {
    if (source == NewsSource.ai) return aiData?.originalSource ?? '';
    return dbData?['source']?.toString() ?? 'Unknown Source';
  }

  String get date {
    if (source == NewsSource.ai) return aiData?.originalPublished ?? '';
    final d = dbData!;
    return d['Date']?.toString() ??
        d['date']?.toString() ??
        d['news_date']?.toString() ??
        '';
  }

  String get imageUrl {
    if (source == NewsSource.ai) return '';
    final d = dbData!;
    return d['Images_news']?.toString() ??
        d['images']?.toString() ??
        d['image']?.toString() ??
        '';
  }

  String get originalLink   => source == NewsSource.ai ? (aiData?.originalLink   ?? '') : '';
  String get sentiment      => source == NewsSource.ai ? (aiData?.sentiment      ?? '') : '';
  double get confidence     => source == NewsSource.ai ? (aiData?.confidence     ?? 0.0) : 0.0;
  String get originalDomain => source == NewsSource.ai ? (aiData?.originalDomain ?? '') : '';
  String get generatedSummary => source == NewsSource.ai ? (aiData?.generatedSummary ?? '') : '';
}

// ---------------------------------------------------------------------------
// NewsSection — OPTIMIZED
// ---------------------------------------------------------------------------

class NewsSection extends StatefulWidget {
  final String token;
  final String role;

  const NewsSection({
    super.key,
    required this.token,
    required this.role,
  });

  @override
  State<NewsSection> createState() => _NewsSectionState();
}

class _NewsSectionState extends State<NewsSection> {
  // ── State ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _dbNews = [];
  List<GeneratedNewsArticle> _aiNews = [];
  bool _aiGenerating = false;
  String? _aiError;

  List<UnifiedNewsItem> _feed         = [];
  List<UnifiedNewsItem> _filteredFeed = [];

  // FIX 1: Pisahkan loading state — DB dan AI independen
  bool _isDbLoading = true;
  bool _isAiLoading = false;

  final TextEditingController _searchController = TextEditingController();

  // FIX 2: Debounce timer untuk search, hindari rebuild tiap karakter
  DateTime? _lastSearch;

  int get _dbCount => _feed.where((e) => e.source == NewsSource.database).length;
  int get _aiCount => _feed.where((e) => e.source == NewsSource.ai).length;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Search dengan debounce 300ms ─────────────────────────────────────────
  // FIX 3: Debounce — jangan rebuild tiap keystroke
  void _onSearchChanged() {
    final now = DateTime.now();
    _lastSearch = now;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_lastSearch == now) _filterFeed();
    });
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    // FIX 4: Load DB dulu, tampilkan UI segera, AI di-background terpisah
    await _loadDbNews();
    if (mounted) {
      setState(() => _isDbLoading = false);
      _rebuildFeed();
    }
    // AI jalan di background — tidak blok UI
    _triggerAiBackground();
  }

  Future<void> _loadDbNews() async {
    try {
      final result = await News_Exclusive_Hook.GetAllNewsExclusive(
        token: widget.token,
      );
      if (result['success'] == true) {
        _dbNews = (result['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        throw Exception(result['message'] ?? result['error']);
      }
    } catch (e) {
      debugPrint('❌ DB news error: $e');
    }
  }

  // FIX 5: Hapus Future.delayed hardcoded, polling lebih cerdas
  Future<void> _triggerAiBackground() async {
    if (!mounted) return;
    setState(() { _isAiLoading = true; _aiGenerating = true; _aiError = null; });

    try {
      final bgHook = AiNewsGenerateBackgroundHook();
      await bgHook.trigger(
        maxNews:    5,
        categories: 'economy,technology,geopolitics',
        language:   'en',
      );

      if (bgHook.error != null) {
        _aiError = bgHook.error!.message;
        return;
      }

      // Poll dengan exponential backoff, bukan delay tetap 3 detik
      await _pollAiWithBackoff();

    } catch (e) {
      if (mounted) _aiError = e.toString();
      debugPrint('❌ AI background error: $e');
    } finally {
      if (mounted) setState(() { _isAiLoading = false; _aiGenerating = false; });
    }
  }

  // Poll sampai data siap, dengan jeda yang bertambah (bukan delay tetap)
  Future<void> _pollAiWithBackoff() async {
    const delays = [2, 3, 4, 5]; // detik, total max ~14 detik
    for (final seconds in delays) {
      await Future.delayed(Duration(seconds: seconds));
      if (!mounted) return;

      final hook = AiNewsGenerateHook();
      await hook.generate(const GenerateNewsRequest(
        maxNews: 5, exportJson: true, exportTxt: false,
      ));

      if (hook.data != null && hook.data!.articles.isNotEmpty) {
        _aiNews = hook.data!.articles;
        // FIX 6: Satu setState saja setelah semua data siap
        if (mounted) setState(_rebuildFeed);
        return; // berhasil, hentikan polling
      }
    }
  }

  // FIX 7: _rebuildFeed tidak panggil setState sendiri — caller yang panggil
  void _rebuildFeed() {
    final dbItems = _dbNews.map((e) => UnifiedNewsItem.fromDb(e)).toList();
    final aiItems = _aiNews.map((e) => UnifiedNewsItem.fromAi(e)).toList();

    final combined = <UnifiedNewsItem>[];
    int dbIdx = 0, aiIdx = 0;
    while (dbIdx < dbItems.length || aiIdx < aiItems.length) {
      for (int i = 0; i < 2 && dbIdx < dbItems.length; i++, dbIdx++) {
        combined.add(dbItems[dbIdx]);
      }
      if (aiIdx < aiItems.length) combined.add(aiItems[aiIdx++]);
    }

    _feed = combined;
    _applyFilter(); // tidak panggil setState di sini
  }

  // Filter tanpa setState — dipanggil dari context yang sudah punya setState
  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _filteredFeed = List.from(_feed);
    } else {
      _filteredFeed = _feed.where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            item.newsSource.toLowerCase().contains(query);
      }).toList();
    }
  }

  // Dipanggil dari debounce search — butuh setState
  void _filterFeed() {
    if (!mounted) return;
    setState(_applyFilter);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _dbNews = []; _aiNews = []; _feed = [];
      _isDbLoading = true; _isAiLoading = false;
      _aiError = null;
    });
    await _loadAll();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openDbNews(UnifiedNewsItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostinganNewsScreen(newsData: item.dbData!),
      ),
    );
  }

  void _openAiNews(UnifiedNewsItem item) {
    if (item.aiData == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiNewsDetailScreen(aiData: item.aiData!),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role.toLowerCase() == 'admin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header — dibungkus RepaintBoundary agar tidak ikut rebuild
        RepaintBoundary(
          child: _buildHeader(isAdmin),
        ),

        // Stats bar
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 16, 48, 0),
          child: _buildStatsBar(),
        ),

        const SizedBox(height: 32),

        // Content
        _buildContent(isAdmin),
      ],
    );
  }

  Widget _buildHeader(bool isAdmin) {
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
                      NewsColorStyle.greenNeon.withOpacity(0.2),
                      NewsColorStyle.greenNeon.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: NewsColorStyle.greenNeon.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.article_outlined,
                  color: NewsColorStyle.greenNeon,
                  size:  28,
                ),
              ),
              const SizedBox(width: 16),
              Text('News', style: NewsColorStyle.sectionTitleStyle),
              const SizedBox(width: 16),
              if (_aiGenerating) const _AiGeneratingBadge(),
            ],
          ),
          Row(
            children: [
              _buildSearchBar(),
              if (isAdmin) ...[
                const SizedBox(width: 16),
                _buildAddButton(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Row(
      children: [
        _StatChip(
          label: '$_dbCount Exclusive',
          color: NewsColorStyle.greenNeon,
          icon:  Icons.newspaper_outlined,
        ),
        const SizedBox(width: 12),
        _StatChip(
          label: '$_aiCount AI Generated',
          color: NewsColorStyle.greenPrimary,
          icon:  Icons.auto_awesome,
        ),
        if (_aiError != null) ...[
          const SizedBox(width: 12),
          _StatChip(
            label: 'AI Unavailable',
            color: Colors.red.shade400,
            icon:  Icons.error_outline,
          ),
        ],
      ],
    );
  }

  Widget _buildContent(bool isAdmin) {
    // DB masih loading
    if (_isDbLoading) {
      return SizedBox(
        height: 400,
        child: Center(
          child: CircularProgressIndicator(
            color: NewsColorStyle.greenNeon, strokeWidth: 3,
          ),
        ),
      );
    }

    // Feed kosong
    if (_filteredFeed.isEmpty) {
      return _buildEmptyState(isAdmin);
    }

    // FIX 8: ListView.builder — lazy render, tidak build semua card sekaligus
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: ListView.builder(
        shrinkWrap: true,
        physics:    const NeverScrollableScrollPhysics(), // scroll dari parent
        itemCount:  _filteredFeed.length +
            (_isAiLoading && _aiNews.isEmpty ? 1 : 0), // slot loading AI
        itemBuilder: (context, index) {
          // Slot terakhir: AI sedang loading, tampilkan skeleton
          if (index == _filteredFeed.length) {
            return const _AiLoadingCard();
          }

          final item = _filteredFeed[index];

          // FIX 9: RepaintBoundary per card — hover satu card tidak rebuild yang lain
          return RepaintBoundary(
            child: item.source == NewsSource.database
                ? _DbNewsCard(
                    key:   ValueKey('db-${item.dbData.hashCode}'),
                    item:  item,
                    onTap: () => _openDbNews(item),
                  )
                : _AiNewsCard(
                    key:   ValueKey('ai-${item.aiData.hashCode}'),
                    item:  item,
                    onTap: () => _openAiNews(item),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 280, height: 44,
      decoration: NewsCardTheme.searchBarDecoration(
        isFocused: _searchController.text.isNotEmpty,
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: NewsColorStyle.searchText, fontSize: 14),
        decoration: InputDecoration(
          hintText:  'Search news...',
          hintStyle: const TextStyle(
            color: NewsColorStyle.searchPlaceholder, fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search, color: NewsColorStyle.searchPlaceholder, size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear, color: NewsColorStyle.searchPlaceholder, size: 18,
                  ),
                  onPressed: () { _searchController.clear(); setState(() {}); },
                )
              : null,
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context, '/upload_news', arguments: widget.token,
          );
          if (result == true) _refresh();
        },
        icon:  const Icon(Icons.add, size: 18),
        label: const Text(
          'Add News',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: NewsColorStyle.addButtonBackground,
          foregroundColor: NewsColorStyle.addButtonText,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.hovered)) return Colors.black.withOpacity(0.1);
              if (states.contains(WidgetState.pressed)) return Colors.black.withOpacity(0.2);
              return null;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isAdmin) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size:  64,
              color: NewsColorStyle.subtitleText.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'No news available' : 'No news found',
              style: TextStyle(
                color: NewsColorStyle.subtitleText, fontSize: 16, fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty
                  ? (isAdmin
                      ? 'Click "Add News" to publish your first article'
                      : 'Check back later for news updates')
                  : 'Try different search keywords',
              style: TextStyle(color: NewsColorStyle.sourceText, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// AI Loading Skeleton Card — ditampilkan saat AI masih generate
// ===========================================================================

class _AiLoadingCard extends StatefulWidget {
  const _AiLoadingCard();

  @override
  State<_AiLoadingCard> createState() => _AiLoadingCardState();
}

class _AiLoadingCardState extends State<_AiLoadingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.04 + _anim.value * 0.08;
        return Container(
          margin: const EdgeInsets.only(bottom: 32),
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF1A3D20),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NewsColorStyle.greenPrimary.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI sedang membuat artikel...',
                style: TextStyle(
                  color: NewsColorStyle.greenPrimary.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===========================================================================
// DB News Card — tidak berubah signifikan, tambah ValueKey
// ===========================================================================

class _DbNewsCard extends StatefulWidget {
  final UnifiedNewsItem item;
  final VoidCallback    onTap;

  const _DbNewsCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<_DbNewsCard> createState() => _DbNewsCardState();
}

class _DbNewsCardState extends State<_DbNewsCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item         = widget.item;
    final fullImageUrl = item.imageUrl.isNotEmpty
        ? 'http://127.0.0.1:8080/${item.imageUrl}'
        : '';

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
            transform: Matrix4.identity()..translate(0.0, isHovered ? -4.0 : 0.0),
            decoration: BoxDecoration(
              gradient:     NewsColorStyle.newsCardGradient1,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isHovered
                    ? NewsColorStyle.greenNeon.withOpacity(0.3)
                    : NewsColorStyle.searchBorder,
                width: isHovered ? 1.5 : 1,
              ),
              boxShadow: isHovered
                  ? [BoxShadow(
                      color: NewsColorStyle.greenNeon.withOpacity(0.1),
                      blurRadius: 20, offset: const Offset(0, 8),
                    )]
                  : [BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10, offset: const Offset(0, 4),
                    )],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20), bottomLeft: Radius.circular(20),
                    ),
                    child: fullImageUrl.isNotEmpty
                        ? Image.network(
                            fullImageUrl, height: 280, fit: BoxFit.cover,
                            // FIX 10: cacheWidth/cacheHeight agar gambar tidak decode full size
                            cacheWidth:  600,
                            errorBuilder:  (_, __, ___) => _imagePlaceholder(),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 280, color: NewsColorStyle.cardBackground,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                        : null,
                                    color: NewsColorStyle.greenNeon, strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          )
                        : _imagePlaceholder(),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: NewsCardTheme.newsBadgeDecoration(),
                          child: Text('NEWS', style: NewsColorStyle.badgeTextStyle),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 28,
                            fontWeight: FontWeight.bold, height: 1.2, letterSpacing: -0.5,
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.description,
                          style: TextStyle(
                            color: NewsColorStyle.subtitleText.withOpacity(0.9),
                            fontSize: 15, height: 1.5, letterSpacing: 0.1,
                          ),
                          maxLines: 3, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            if (item.newsSource.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: NewsColorStyle.greenNeon.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.source_outlined,
                                    size: 14, color: NewsColorStyle.greenNeon),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.newsSource,
                                  style: const TextStyle(
                                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            const SizedBox(width: 16),
                            if (item.date.isNotEmpty) ...[
                              Icon(Icons.calendar_today_outlined,
                                  size: 14, color: NewsColorStyle.sourceText),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(item.date),
                                style: const TextStyle(
                                  color: NewsColorStyle.sourceText, fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: NewsColorStyle.greenNeon.withOpacity(0.2), width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record,
                                  size: 8, color: NewsColorStyle.greenNeon.withOpacity(0.8)),
                              const SizedBox(width: 6),
                              Text(
                                'Market News',
                                style: TextStyle(
                                  color: NewsColorStyle.greenNeon.withOpacity(0.9),
                                  fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(
                              'Read full article',
                              style: TextStyle(
                                color: NewsColorStyle.greenNeon, fontSize: 14,
                                fontWeight: FontWeight.w600, letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 16, color: NewsColorStyle.greenNeon),
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

  Widget _imagePlaceholder() {
    return Container(
      height: 280, color: NewsColorStyle.cardBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64,
                color: NewsColorStyle.greenNeon.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('News Article', style: TextStyle(
              color: NewsColorStyle.subtitleText.withOpacity(0.5), fontSize: 14,
            )),
          ],
        ),
      ),
    );
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    try {
      final parsed = DateTime.parse(date);
      final diff   = DateTime.now().difference(parsed);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7)  return '${diff.inDays}d ago';
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (_) { return date; }
  }
}

// ===========================================================================
// AI News Card — tidak berubah, tambah ValueKey
// ===========================================================================

class _AiNewsCard extends StatefulWidget {
  final UnifiedNewsItem item;
  final VoidCallback    onTap;

  const _AiNewsCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<_AiNewsCard> createState() => _AiNewsCardState();
}

class _AiNewsCardState extends State<_AiNewsCard> {
  bool isHovered = false;

  static const _aiAccent  = Color(0xFF00CC44);
  static const _aiNeon    = Color(0xFFBEFF00);
  static const _aiBg      = Color(0xFF0A1A0D);
  static const _aiBgPanel = Color(0xFF0D2010);
  static const _aiBorder  = Color(0xFF1A3D20);

  Color get _sentimentColor {
    switch (widget.item.sentiment.toLowerCase()) {
      case 'optimis': case 'positif':  return const Color(0xFFBEFF00);
      case 'negatif': case 'pesimis':  return const Color(0xFFFF5A5A);
      default:                          return const Color(0xFF66AA77);
    }
  }

  String get _sentimentEmoji {
    switch (widget.item.sentiment.toLowerCase()) {
      case 'optimis': case 'positif':  return '↑';
      case 'negatif': case 'pesimis':  return '↓';
      default:                          return '→';
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

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
            transform: Matrix4.identity()..translate(0.0, isHovered ? -4.0 : 0.0),
            decoration: BoxDecoration(
              color:        _aiBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isHovered ? _aiAccent.withOpacity(0.5) : _aiBorder,
                width: isHovered ? 1.5 : 1.0,
              ),
              boxShadow: isHovered
                  ? [BoxShadow(
                      color: _aiAccent.withOpacity(0.15),
                      blurRadius: 24, spreadRadius: 0, offset: const Offset(0, 8),
                    )]
                  : [BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10, offset: const Offset(0, 4),
                    )],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20), bottomLeft: Radius.circular(20),
                    ),
                    child: Container(
                      height: 280,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _aiAccent.withOpacity(0.18),
                            _aiBgPanel,
                          ],
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _DotPatternPainter(color: _aiAccent),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:  _sentimentColor.withOpacity(0.1),
                                    border: Border.all(
                                      color: _sentimentColor.withOpacity(0.45), width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _sentimentEmoji,
                                      style: TextStyle(
                                        fontSize: 32, color: _sentimentColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (item.sentiment.isNotEmpty)
                                  Text(
                                    item.sentiment.toUpperCase(),
                                    style: TextStyle(
                                      color: _sentimentColor, fontSize: 11,
                                      fontWeight: FontWeight.w700, letterSpacing: 1.5,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                if (item.confidence > 0) ...[
                                  SizedBox(
                                    width: 100,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value:           item.confidence,
                                        backgroundColor: Colors.white.withOpacity(0.06),
                                        valueColor:      AlwaysStoppedAnimation(_sentimentColor),
                                        minHeight:       4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${(item.confidence * 100).toStringAsFixed(0)}% confidence',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.35), fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Positioned(
                            top: 16, left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color:        _aiAccent.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _aiAccent.withOpacity(0.4), width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 10, color: _aiNeon),
                                  const SizedBox(width: 5),
                                  Text(
                                    'AI NEWS',
                                    style: TextStyle(
                                      color: _aiNeon, fontSize: 10,
                                      fontWeight: FontWeight.w700, letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 16, right: 16,
                            child: AnimatedOpacity(
                              opacity:  isHovered ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:        Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.open_in_full_rounded,
                                  size: 12, color: _aiNeon,
                                ),
                              ),
                            ),
                          ),
                          if (item.originalDomain.isNotEmpty)
                            Positioned(
                              bottom: 16, right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:        Colors.black.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '# ${item.originalDomain}',
                                  style: TextStyle(
                                    color: _aiAccent.withOpacity(0.55), fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:        _aiAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _aiAccent.withOpacity(0.3), width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, size: 12, color: _aiNeon),
                              const SizedBox(width: 6),
                              Text(
                                'AI GENERATED NEWS',
                                style: TextStyle(
                                  color: _aiNeon, fontSize: 11,
                                  fontWeight: FontWeight.w700, letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 26,
                            fontWeight: FontWeight.bold, height: 1.2, letterSpacing: -0.5,
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14, height: 1.55, letterSpacing: 0.1,
                          ),
                          maxLines: 3, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color:        _aiAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.source_outlined, size: 14, color: _aiAccent),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.newsSource,
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (item.date.isNotEmpty) ...[
                              Icon(Icons.calendar_today_outlined,
                                  size: 14, color: Colors.white.withOpacity(0.35)),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(item.date),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4), fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color:        Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _aiAccent.withOpacity(0.2), width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record,
                                  size: 8, color: _aiAccent.withOpacity(0.8)),
                              const SizedBox(width: 6),
                              Text(
                                'AI Market Insight',
                                style: TextStyle(
                                  color: _aiAccent.withOpacity(0.9), fontSize: 11,
                                  fontWeight: FontWeight.w500, letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(
                              'Read AI summary',
                              style: TextStyle(
                                color: _aiNeon, fontSize: 14,
                                fontWeight: FontWeight.w600, letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              transform: Matrix4.identity()
                                ..translate(isHovered ? 4.0 : 0.0, 0.0),
                              child: Icon(Icons.arrow_forward, size: 16, color: _aiNeon),
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

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    try {
      final parsed = DateTime.parse(date);
      final diff   = DateTime.now().difference(parsed);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7)  return '${diff.inDays}d ago';
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (_) { return date; }
  }
}

// ===========================================================================
// AI News Detail Screen — tidak berubah
// ===========================================================================

class AiNewsDetailScreen extends StatefulWidget {
  final GeneratedNewsArticle aiData;
  const AiNewsDetailScreen({super.key, required this.aiData});

  @override
  State<AiNewsDetailScreen> createState() => _AiNewsDetailScreenState();
}

class _AiNewsDetailScreenState extends State<AiNewsDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  static const _aiAccent  = Color(0xFF00CC44);
  static const _aiNeon    = Color(0xFFBEFF00);
  static const _aiBg      = Color(0xFF060E07);
  static const _cardBg    = Color(0xFF0A1A0D);
  static const _aiBorder  = Color(0xFF1A3D20);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450),
    );
    _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  GeneratedNewsArticle get d => widget.aiData;

  Color get _sentimentColor {
    switch (d.sentiment.toLowerCase()) {
      case 'optimis': case 'positif':  return _aiNeon;
      case 'negatif': case 'pesimis':  return const Color(0xFFFF5A5A);
      default:                          return const Color(0xFF66AA77);
    }
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    try {
      final parsed = DateTime.parse(date);
      final diff   = DateTime.now().difference(parsed);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7)  return '${diff.inDays} days ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (_) { return date; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _aiBg,
      body: SafeArea(
        child: FadeTransition(
          opacity:  _fadeAnim,
          child:    SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 36),
                        _buildBadgeRow(),
                        const SizedBox(height: 20),
                        _buildSummaryCard(),
                        const SizedBox(height: 20),
                        _buildTitle(),
                        const SizedBox(height: 20),
                        _buildMetaRow(),
                        const SizedBox(height: 32),
                        _buildGradientDivider(),
                        const SizedBox(height: 32),
                        _buildBody(),
                        const SizedBox(height: 40),
                        _buildGradientDivider(),
                        const SizedBox(height: 32),
                        _buildSourceCard(),
                        if (d.confidence > 0) ...[
                          const SizedBox(height: 24),
                          _buildAnalysisCard(),
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

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(48, 24, 48, 16),
      decoration: BoxDecoration(
        color: _aiBg,
        border: Border(bottom: BorderSide(color: _aiBorder.withOpacity(0.6), width: 1)),
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        _cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border:       Border.all(color: _aiBorder, width: 1),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:        _aiAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: _aiAccent.withOpacity(0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 13, color: _aiNeon),
                const SizedBox(width: 6),
                Text(
                  'AI GENERATED NEWS',
                  style: TextStyle(
                    color: _aiNeon, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: d.generatedBody));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:         const Text('Article copied to clipboard'),
                  backgroundColor: _aiAccent.withOpacity(0.9),
                  behavior:        SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  duration: const Duration(seconds: 2),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color:        _cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border:       Border.all(color: _aiBorder, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_outlined, size: 14, color: Colors.white.withOpacity(0.6)),
                    const SizedBox(width: 6),
                    Text(
                      'Copy Article',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13, fontWeight: FontWeight.w500,
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

  Widget _buildBadgeRow() {
    return Row(
      children: [
        if (d.sentiment.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:        _sentimentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: _sentimentColor.withOpacity(0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: _sentimentColor, shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  d.sentiment.toUpperCase(),
                  style: TextStyle(
                    color: _sentimentColor, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        if (d.sentiment.isNotEmpty && d.generatedAt.isNotEmpty)
          const SizedBox(width: 12),
        if (d.generatedAt.isNotEmpty)
          Row(
            children: [
              Icon(Icons.schedule_outlined, size: 13, color: Colors.white.withOpacity(0.3)),
              const SizedBox(width: 5),
              Text(
                'Generated ${_formatDate(d.generatedAt)}',
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    if (d.generatedSummary.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        _cardBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _aiBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _aiAccent.withOpacity(0.06),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3, height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_aiNeon, _aiAccent],
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              d.generatedSummary,
              style: TextStyle(
                color:    Colors.white.withOpacity(0.75),
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height:   1.55,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      d.generatedTitle,
      style: const TextStyle(
        color: Colors.white, fontSize: 30,
        fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildMetaRow() {
    return Row(
      children: [
        if (d.originalSource.isNotEmpty) ...[
          Icon(Icons.source_outlined, size: 14, color: Colors.white.withOpacity(0.35)),
          const SizedBox(width: 6),
          Text(
            d.originalSource,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 13, fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (d.originalSource.isNotEmpty && d.originalDomain.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              width: 4, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle,
              ),
            ),
          ),
        if (d.originalDomain.isNotEmpty)
          Text(
            d.originalDomain,
            style: TextStyle(
              color: _aiNeon.withOpacity(0.65), fontSize: 12, fontStyle: FontStyle.italic,
            ),
          ),
        if (d.originalPublished.isNotEmpty) ...[
          const Spacer(),
          Icon(Icons.calendar_today_outlined, size: 13, color: Colors.white.withOpacity(0.3)),
          const SizedBox(width: 5),
          Text(
            _formatDate(d.originalPublished),
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildGradientDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_aiAccent.withOpacity(0.4), _aiBorder.withOpacity(0.2), Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final paragraphs = d.generatedBody
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      return Text(
        'No content available.',
        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.asMap().entries.map((entry) {
        final index = entry.key;
        final para  = entry.value;

        if (para.startsWith('## ') || para.startsWith('# ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Text(
              para.replaceFirst(RegExp(r'^#+\s*'), ''),
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18, fontWeight: FontWeight.w700, height: 1.3,
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: index < paragraphs.length - 1 ? 20 : 0,
          ),
          child: Text(
            para,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 15.5, height: 1.78, letterSpacing: 0.15,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSourceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        _cardBg,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _aiBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, size: 16, color: _aiAccent),
              const SizedBox(width: 8),
              Text(
                'Original Source',
                style: TextStyle(
                  color: _aiAccent, fontSize: 13,
                  fontWeight: FontWeight.w700, letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (d.originalTitle.isNotEmpty) ...[
            Text(
              d.originalTitle,
              style: const TextStyle(
                color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.w600, height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              if (d.originalSource.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    d.originalSource,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55), fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (d.originalDomain.isNotEmpty)
                Text(
                  '# ${d.originalDomain}',
                  style: TextStyle(
                    color: _aiNeon.withOpacity(0.5), fontSize: 12, fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          if (d.originalLink.isNotEmpty) ...[
            const SizedBox(height: 16),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: d.originalLink));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:         const Text('Link copied to clipboard'),
                    backgroundColor: Colors.white.withOpacity(0.1),
                    behavior:        SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    duration: const Duration(seconds: 2),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color:        _aiAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border:       Border.all(color: _aiAccent.withOpacity(0.25), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new, size: 14, color: _aiAccent),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          d.originalLink,
                          style: TextStyle(color: _aiAccent, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        _cardBg,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _aiBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Analysis',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5), fontSize: 12,
              fontWeight: FontWeight.w600, letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confidence',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:           d.confidence,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        valueColor:      AlwaysStoppedAnimation(_sentimentColor),
                        minHeight:       6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(d.confidence * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: _sentimentColor, fontSize: 13, fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (d.score != 0) ...[
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value:           d.score.abs().clamp(0.0, 1.0),
                          backgroundColor: Colors.white.withOpacity(0.06),
                          valueColor:      AlwaysStoppedAnimation(_aiAccent),
                          minHeight:       6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.score.toStringAsFixed(2),
                        style: TextStyle(
                          color: _aiAccent, fontSize: 13, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Custom Painter — dot pattern
// ===========================================================================

class _DotPatternPainter extends CustomPainter {
  final Color color;
  const _DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 20.0;
    final paint   = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter old) => old.color != color;
}

// ===========================================================================
// Helper widgets
// ===========================================================================

class _AiGeneratingBadge extends StatelessWidget {
  const _AiGeneratingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        NewsColorStyle.greenPrimary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: NewsColorStyle.greenPrimary.withOpacity(0.3), width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10, height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5, color: NewsColorStyle.greenPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'AI generating...',
            style: TextStyle(
              color: NewsColorStyle.greenPrimary, fontSize: 11, fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData icon;

  const _StatChip({required this.label, required this.color, required this.icon});

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
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}