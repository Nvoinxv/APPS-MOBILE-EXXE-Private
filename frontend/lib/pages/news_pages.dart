import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../hooks/news_hook.dart';
import '../hooks/news_ai_hook.dart';
import '../style/apps_color_news.dart';
import '../postingan/postingan_news.dart';
import '../postingan/postingan_ai_news.dart';

// ---------------------------------------------------------------------------
// Unified News Item
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

  /// URL gambar — DB pakai path lokal, AI pakai Image field dari MongoDB jika ada
  String get imageUrl {
    if (source == NewsSource.ai) {
      return aiData?.imageUrl ?? '';
    }
    final d = dbData!;
    return d['Images_news']?.toString() ??
        d['images']?.toString() ??
        d['image']?.toString() ??
        '';
  }

  String get imageUrl2 {
    if (source == NewsSource.ai) return '';
    return dbData?['Images_news_2']?.toString() ?? '';
  }

  String get originalLink   => source == NewsSource.ai ? (aiData?.originalLink   ?? '') : '';
  String get sentiment      => source == NewsSource.ai ? (aiData?.sentiment      ?? '') : '';
  double get confidence     => source == NewsSource.ai ? (aiData?.confidence     ?? 0.0) : 0.0;
  double get score          => source == NewsSource.ai ? (aiData?.score          ?? 0.0) : 0.0;
  String get originalDomain => source == NewsSource.ai ? (aiData?.originalDomain ?? '') : '';
  String get generatedBody  => source == NewsSource.ai ? (aiData?.generatedBody  ?? '') : '';
  String get originalTitle  => source == NewsSource.ai ? (aiData?.originalTitle  ?? '') : '';
}

// ---------------------------------------------------------------------------
// NewsSection
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
  List<Map<String, dynamic>> _dbNews = [];
  List<GeneratedNewsArticle> _aiNews = [];
  bool _aiGenerating = false;
  String? _aiError;

  List<UnifiedNewsItem> _feed         = [];
  List<UnifiedNewsItem> _filteredFeed = [];

  bool _isDbLoading = true;
  bool _isAiLoading = false;

  final TextEditingController _searchController = TextEditingController();
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

  void _onSearchChanged() {
    final now = DateTime.now();
    _lastSearch = now;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_lastSearch == now) _filterFeed();
    });
  }

  Future<void> _loadAll() async {
  await _loadDbNews();
  if (mounted) {
    setState(() => _isDbLoading = false);
    _rebuildFeed();
  }
  await _fetchExistingAiNews(); // ← ganti: fetch saja, tidak generate
} 
  Future<void> _fetchExistingAiNews() async {
  if (!mounted) return;
  setState(() { _isAiLoading = true; _aiError = null; });

  try {
    final hook = AiNewsGenerateHook();
    await hook.generate(const GenerateNewsRequest(
      maxNews: 5, exportJson: false, exportTxt: false,
    ));
    if (hook.data != null && hook.data!.articles.isNotEmpty) {
      _aiNews = hook.data!.articles;
      if (mounted) setState(_rebuildFeed);
    }
  } catch (e) {
    if (mounted) _aiError = e.toString();
  } finally {
    if (mounted) setState(() => _isAiLoading = false);
  }
}

  Future<void> _loadDbNews() async {
    try {
      final result = await News_Exclusive_Hook.GetAllNewsExclusive();
      if (result['success'] == true) {
        _dbNews = (result['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ DB news error: $e');
    }
  }


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
    _applyFilter();
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    _filteredFeed = query.isEmpty
        ? List.from(_feed)
        : _feed.where((item) =>
            item.title.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            item.newsSource.toLowerCase().contains(query)).toList();
  }

  void _filterFeed() {
    if (!mounted) return;
    setState(_applyFilter);
  }

  Future<void> _refresh() async {
  if (!mounted) return;
  setState(() {
    _dbNews = []; _aiNews = []; _feed = [];
    _isDbLoading = true; _isAiLoading = false; _aiError = null;
  });
  await _loadAll(); // sudah tidak trigger generate
}

  void _openDbNews(UnifiedNewsItem item) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PostinganNewsScreen(newsData: item.dbData!),
    ));
  }

  void _openAiNews(UnifiedNewsItem item) {
    if (item.aiData == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PostinganAiNewsScreen(item: item),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role.toLowerCase() == 'admin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(child: _buildHeader(isAdmin)),
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 16, 48, 0),
          child: _buildStatsBar(),
        ),
        const SizedBox(height: 32),
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
                    color: NewsColorStyle.greenNeon.withOpacity(0.3), width: 1.5,
                  ),
                ),
                child: Icon(Icons.article_outlined, color: NewsColorStyle.greenNeon, size: 28),
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
        _StatChip(label: '$_dbCount Exclusive', color: NewsColorStyle.greenNeon, icon: Icons.newspaper_outlined),
        const SizedBox(width: 12),
        _StatChip(label: '$_aiCount AI Generated', color: NewsColorStyle.greenPrimary, icon: Icons.auto_awesome),
        if (_aiError != null) ...[
          const SizedBox(width: 12),
          _StatChip(label: 'AI Unavailable', color: Colors.red.shade400, icon: Icons.error_outline),
        ],
      ],
    );
  }

  Widget _buildContent(bool isAdmin) {
    if (_isDbLoading) {
      return SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator(color: NewsColorStyle.greenNeon, strokeWidth: 3)),
      );
    }
    if (_filteredFeed.isEmpty) return _buildEmptyState(isAdmin);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: ListView.builder(
        shrinkWrap: true,
        physics:    const NeverScrollableScrollPhysics(),
        itemCount:  _filteredFeed.length + (_isAiLoading && _aiNews.isEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filteredFeed.length) return const _AiLoadingCard();
          final item = _filteredFeed[index];
          return RepaintBoundary(
            child: item.source == NewsSource.database
                ? _UnifiedNewsCard(
                    key:    ValueKey('db-${item.dbData.hashCode}'),
                    item:   item,
                    onTap:  () => _openDbNews(item),
                  )
                : _UnifiedNewsCard(
                    key:    ValueKey('ai-${item.aiData.hashCode}'),
                    item:   item,
                    onTap:  () => _openAiNews(item),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 280, height: 44,
      decoration: NewsCardTheme.searchBarDecoration(isFocused: _searchController.text.isNotEmpty),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: NewsColorStyle.searchText, fontSize: 14),
        decoration: InputDecoration(
          hintText:  'Search news...',
          hintStyle: const TextStyle(color: NewsColorStyle.searchPlaceholder, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: NewsColorStyle.searchPlaceholder, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: NewsColorStyle.searchPlaceholder, size: 18),
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
          final result = await Navigator.pushNamed(context, '/upload_news', arguments: widget.token);
          if (result == true) _refresh();
        },
        icon:  const Icon(Icons.add, size: 18),
        label: const Text('Add News', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        style: ElevatedButton.styleFrom(
          backgroundColor: NewsColorStyle.addButtonBackground,
          foregroundColor: NewsColorStyle.addButtonText,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
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
            Icon(Icons.article_outlined, size: 64, color: NewsColorStyle.subtitleText.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'No news available' : 'No news found',
              style: TextStyle(color: NewsColorStyle.subtitleText, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty
                  ? (isAdmin ? 'Click "Add News" to publish your first article' : 'Check back later for news updates')
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
// UNIFIED NEWS CARD
// Card tunggal yang dipakai untuk DB news DAN AI news.
// Desain mengikuti _DbNewsCard (horizontal, image kiri, konten kanan).
// AI news: badge "AI" + sentiment, DB news: badge "NEWS" saja.
// Image: DB pakai path lokal, AI pakai field Image jika ada, fallback ke panel sentiment.
// ===========================================================================

class _UnifiedNewsCard extends StatefulWidget {
  final UnifiedNewsItem item;
  final VoidCallback    onTap;

  const _UnifiedNewsCard({super.key, required this.item, required this.onTap});

  @override
  State<_UnifiedNewsCard> createState() => _UnifiedNewsCardState();
}

class _UnifiedNewsCardState extends State<_UnifiedNewsCard> {
  bool _isHovered    = false;
  bool _imageFailed  = false;

  // ── Sentiment palette ─────────────────────────────────────────────────────
  static const _sentimentColors = <String, Color>{
    'optimis': Color(0xFF00CC44),
    'positif': Color(0xFF1E90FF),
    'netral':  Color(0xFF888780),
    'negatif': Color(0xFFFF8C42),
    'pesimis': Color(0xFFFF5A5A),
  };

  static const _sentimentArrows = <String, String>{
    'optimis': '↑',
    'positif': '↗',
    'netral':  '→',
    'negatif': '↘',
    'pesimis': '↓',
  };

  Color get _sentimentColor =>
      _sentimentColors[widget.item.sentiment.toLowerCase()] ?? const Color(0xFF888780);

  String get _sentimentArrow =>
      _sentimentArrows[widget.item.sentiment.toLowerCase()] ?? '→';

  bool get _isAi => widget.item.source == NewsSource.ai;

  // Warna aksen card: AI pakai hijau EXXE, DB pakai greenNeon
  Color get _accentColor => _isAi ? const Color(0xFF00CC44) : NewsColorStyle.greenNeon;
  Color get _neonColor   => _isAi ? const Color(0xFFBEFF00) : NewsColorStyle.greenNeon;
  Color get _bgColor     => _isAi ? const Color(0xFF0A1A0D) : NewsColorStyle.cardBackground;
  Color get _borderColor => _isAi ? const Color(0xFF1A3D20) : NewsColorStyle.searchBorder;

  // URL gambar: DB = http://127.0.0.1:8080/..., AI = Image field (opsional)
  String get _imageUrl {
    final raw = widget.item.imageUrl;
    if (raw.isEmpty) return '';
    if (_isAi) return raw; // AI: sudah full URL atau kosong
    return 'http://127.0.0.1:8080/$raw';
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    try {
      final parsed = DateTime.parse(date);
      final diff   = DateTime.now().difference(parsed);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7)  return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (_) { return date; }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: MouseRegion(
        cursor:  SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit:  (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration:  const Duration(milliseconds: 300),
            curve:     Curves.easeOutCubic,
            transform: Matrix4.identity()..translate(0.0, _isHovered ? -4.0 : 0.0),
            decoration: BoxDecoration(
              color:        _bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered ? _accentColor.withOpacity(0.5) : _borderColor,
                width: _isHovered ? 1.5 : 1.0,
              ),
              boxShadow: _isHovered
                  ? [BoxShadow(color: _accentColor.withOpacity(0.15), blurRadius: 24, spreadRadius: 0, offset: const Offset(0, 8))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Panel kiri: image atau sentiment fallback ──────────────
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft:    Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                    child: SizedBox(
                      height: 280,
                      child: _buildImagePanel(),
                    ),
                  ),
                ),

                // ── Konten kanan ───────────────────────────────────────────
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: _buildContent(item),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Panel gambar (kiri) ───────────────────────────────────────────────────

  Widget _buildImagePanel() {
    final url = _imageUrl;
    final hasImage = url.isNotEmpty && !_imageFailed;

    if (hasImage) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit:        BoxFit.cover,
            cacheWidth: 600,
            errorBuilder: (_, __, ___) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _imageFailed = true);
              });
              return _buildSentimentPanel();
            },
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : _buildSentimentPanel(),
          ),
          // Gradient overlay supaya teks terbaca
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                colors: [Colors.transparent, _bgColor.withOpacity(0.85)],
                stops:  const [0.4, 1.0],
              ),
            ),
          ),
          _buildImageBadges(),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildSentimentPanel(),
        _buildImageBadges(),
      ],
    );
  }

  Widget _buildSentimentPanel() {
    return Container(
      color: _bgColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dot grid
          CustomPaint(painter: _DotPatternPainter(color: _accentColor)),
          // Konten tengah
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isAi && widget.item.sentiment.isNotEmpty) ...[
                  // AI: tampilkan sentiment circle
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape:  BoxShape.circle,
                      color:  _sentimentColor.withOpacity(0.1),
                      border: Border.all(color: _sentimentColor.withOpacity(0.45), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _sentimentArrow,
                        style: TextStyle(fontSize: 28, color: _sentimentColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.item.sentiment.toUpperCase(),
                    style: TextStyle(color: _sentimentColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                  ),
                  if (widget.item.confidence > 0) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 96,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value:           widget.item.confidence,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          valueColor:      AlwaysStoppedAnimation(_sentimentColor),
                          minHeight:       3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${(widget.item.confidence * 100).toStringAsFixed(0)}% confidence',
                      style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
                    ),
                  ],
                ] else ...[
                  // DB atau AI tanpa sentiment: placeholder icon artikel
                  Icon(Icons.article_outlined, size: 64, color: _accentColor.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'News Article',
                    style: TextStyle(color: NewsColorStyle.subtitleText.withOpacity(0.5), fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageBadges() {
    return Stack(
      children: [
        // Badge kiri atas
        Positioned(
          top: 16, left: 16,
          child: _isAi ? _buildAiBadgePill() : _buildNewsBadgePill(),
        ),
        // Expand icon hover
        Positioned(
          top: 16, right: 16,
          child: AnimatedOpacity(
            opacity:  _isHovered ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:        Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.open_in_full_rounded, size: 12, color: _neonColor),
            ),
          ),
        ),
        // Domain tag bawah kanan (AI only)
        if (_isAi && widget.item.originalDomain.isNotEmpty)
          Positioned(
            bottom: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:        Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '# ${widget.item.originalDomain}',
                style: TextStyle(color: _accentColor.withOpacity(0.6), fontSize: 10, fontStyle: FontStyle.italic),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAiBadgePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        _accentColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: _accentColor.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 10, color: _neonColor),
          const SizedBox(width: 5),
          Text('AI NEWS', style: TextStyle(color: _neonColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        ],
      ),
    );
  }

  Widget _buildNewsBadgePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        NewsColorStyle.greenNeon.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: NewsColorStyle.greenNeon.withOpacity(0.3), width: 1),
      ),
      child: Text('NEWS', style: NewsColorStyle.badgeTextStyle),
    );
  }

  // ── Konten kanan ──────────────────────────────────────────────────────────

  Widget _buildContent(UnifiedNewsItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge baris atas
        _buildTopBadgeRow(item),
        const SizedBox(height: 16),

        // Title
        Text(
          item.title,
          style: const TextStyle(
            color: Colors.white, fontSize: 26,
            fontWeight: FontWeight.bold, height: 1.2, letterSpacing: -0.5,
          ),
          maxLines: 2, overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),

        // Description
        Text(
          item.description,
          style: TextStyle(color: NewsColorStyle.subtitleText.withOpacity(0.9), fontSize: 14, height: 1.55),
          maxLines: 3, overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 20),

        // Source + date row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:        _accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.source_outlined, size: 14, color: _accentColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.newsSource,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.date.isNotEmpty) ...[
              const SizedBox(width: 16),
              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.white.withOpacity(0.35)),
              const SizedBox(width: 6),
              Text(_formatDate(item.date), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
            ],
          ],
        ),

        // Confidence bar (AI only)
        if (_isAi && item.confidence > 0) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Confidence', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:           item.confidence,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor:      AlwaysStoppedAnimation(_sentimentColor),
                    minHeight:       4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(item.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: _sentimentColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),

        // Label tag + CTA
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:        Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border:       Border.all(color: _accentColor.withOpacity(0.2), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record, size: 8, color: _accentColor.withOpacity(0.8)),
                  const SizedBox(width: 6),
                  Text(
                    _isAi ? 'AI Market Insight' : 'Market News',
                    style: TextStyle(color: _accentColor.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // CTA
            Row(
              children: [
                Text(
                  _isAi ? 'Read AI summary' : 'Read full article',
                  style: TextStyle(color: _neonColor, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration:  const Duration(milliseconds: 200),
                  transform: Matrix4.identity()..translate(_isHovered ? 4.0 : 0.0, 0.0),
                  child: Icon(Icons.arrow_forward, size: 16, color: _neonColor),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopBadgeRow(UnifiedNewsItem item) {
    if (!_isAi) {
      // DB news: hanya badge NEWS
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: NewsCardTheme.newsBadgeDecoration(),
        child: Text('NEWS', style: NewsColorStyle.badgeTextStyle),
      );
    }

    // AI news: badge AI + sentiment chip
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:        _accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(color: _accentColor.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 12, color: _neonColor),
              const SizedBox(width: 6),
              Text('AI GENERATED NEWS', style: TextStyle(color: _neonColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ],
          ),
        ),
        if (item.sentiment.isNotEmpty) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color:        _sentimentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: _sentimentColor.withOpacity(0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: _sentimentColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(item.sentiment.toUpperCase(), style: TextStyle(color: _sentimentColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ===========================================================================
// AI Loading Skeleton
// ===========================================================================

class _AiLoadingCard extends StatefulWidget {
  const _AiLoadingCard();

  @override
  State<_AiLoadingCard> createState() => _AiLoadingCardState();
}

class _AiLoadingCardState extends State<_AiLoadingCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 32),
        height: 180,
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.04 + _anim.value * 0.08),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: const Color(0xFF1A3D20), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: NewsColorStyle.greenPrimary.withOpacity(0.5)),
            ),
            const SizedBox(width: 12),
            Text('AI sedang membuat artikel...', style: TextStyle(color: NewsColorStyle.greenPrimary.withOpacity(0.5), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Helper widgets
// ===========================================================================

class _DotPatternPainter extends CustomPainter {
  final Color color;
  const _DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 20.0;
    final paint = Paint()..color = color.withOpacity(0.1)..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter old) => old.color != color;
}

class _AiGeneratingBadge extends StatelessWidget {
  const _AiGeneratingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        NewsColorStyle.greenPrimary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: NewsColorStyle.greenPrimary.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 10, height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: NewsColorStyle.greenPrimary),
          ),
          const SizedBox(width: 6),
          Text('AI generating...', style: TextStyle(color: NewsColorStyle.greenPrimary, fontSize: 11, fontWeight: FontWeight.w500)),
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
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}