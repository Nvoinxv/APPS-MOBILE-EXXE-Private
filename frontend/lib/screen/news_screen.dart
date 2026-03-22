import 'package:flutter/material.dart';
import '../hooks/news_hook.dart';
import '../hooks/news_ai_hook.dart';
import '../style/apps_color_news.dart';
import './postingan_news_screen.dart';

// ---------------------------------------------------------------------------
// Unified News Item — wrapper untuk DB news dan AI news
// ---------------------------------------------------------------------------

enum NewsSource { database, ai }

class UnifiedNewsItem {
  final NewsSource source;

  // DB News fields
  final Map<String, dynamic>? dbData;

  // AI News fields
  final GeneratedNewsArticle? aiData;

  const UnifiedNewsItem.fromDb(this.dbData)
      : source = NewsSource.database,
        aiData = null;

  const UnifiedNewsItem.fromAi(this.aiData)
      : source = NewsSource.ai,
        dbData = null;

  // Accessor yang unified untuk card rendering
  String get title {
    if (source == NewsSource.ai) return aiData?.generatedTitle ?? '';
    final d = dbData!;
    return d['Title']?.toString() ?? d['title']?.toString() ?? 'No Title';
  }

  String get description {
    if (source == NewsSource.ai) return aiData?.generatedBody ?? '';
    final d = dbData!;
    return d['Description']?.toString() ?? d['description']?.toString() ?? '';
  }

  String get newsSource {
    if (source == NewsSource.ai) return aiData?.originalSource ?? '';
    return dbData?['source']?.toString() ?? 'Unknown';
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
    if (source == NewsSource.ai) return ''; // AI news tidak punya image lokal
    final d = dbData!;
    return d['Images_news']?.toString() ??
        d['images']?.toString() ??
        d['image']?.toString() ??
        '';
  }

  String get originalLink => source == NewsSource.ai ? (aiData?.originalLink ?? '') : '';
  String get sentiment     => source == NewsSource.ai ? (aiData?.sentiment ?? '') : '';
  double get confidence    => source == NewsSource.ai ? (aiData?.confidence ?? 0.0) : 0.0;
  String get originalDomain => source == NewsSource.ai ? (aiData?.originalDomain ?? '') : '';
}

// ---------------------------------------------------------------------------
// NewsScreen
// ---------------------------------------------------------------------------

class NewsScreen extends StatefulWidget {
  final String token;
  final String role;

  const NewsScreen({
    super.key,
    required this.token,
    required this.role,
  });

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  // DB news state
  List<Map<String, dynamic>> _dbNews = [];

  // AI news state
  List<GeneratedNewsArticle> _aiNews = [];
  bool _aiGenerating = false;
  String? _aiError;

  // Combined feed
  List<UnifiedNewsItem> _feed = [];
  List<UnifiedNewsItem> _filteredFeed = [];

  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchFocused = false;

  // Stats
  int get _dbCount => _feed.where((e) => e.source == NewsSource.database).length;
  int get _aiCount => _feed.where((e) => e.source == NewsSource.ai).length;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterFeed);
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    // Load keduanya secara paralel
    await Future.wait([
      _loadDbNews(),
      _triggerAiBackground(),
    ]);

    _rebuildFeed();
    setState(() => _isLoading = false);
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
      }
    } catch (e) {
      debugPrint('❌ DB news error: $e');
    }
  }

  Future<void> _triggerAiBackground() async {
    setState(() {
      _aiGenerating = true;
      _aiError = null;
    });

    try {
      final hook = AiNewsGenerateBackgroundHook();

      // Fire background task
      await hook.trigger(
        maxNews:    5,
        categories: 'economy,technology,geopolitics',
        language:   'en',
      );

      if (hook.error != null) {
        _aiError = hook.error!.message;
        return;
      }

      // Background task accepted → poll sekali setelah jeda singkat
      // (opsional: bisa skip polling dan langsung fetch dari endpoint generate)
      await Future.delayed(const Duration(seconds: 3));
      await _fetchAiNews();

    } catch (e) {
      _aiError = e.toString();
      debugPrint('❌ AI background error: $e');
    } finally {
      if (mounted) setState(() => _aiGenerating = false);
    }
  }

  Future<void> _fetchAiNews() async {
    try {
      final hook = AiNewsGenerateHook();
      await hook.generate(const GenerateNewsRequest(
        maxNews:    5,
        exportJson: true,
        exportTxt:  false,
      ));

      if (hook.data != null) {
        _aiNews = hook.data!.articles;
        _rebuildFeed();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('❌ AI fetch error: $e');
    }
  }

  void _rebuildFeed() {
    final dbItems = _dbNews.map((e) => UnifiedNewsItem.fromDb(e)).toList();
    final aiItems = _aiNews.map((e) => UnifiedNewsItem.fromAi(e)).toList();

    // Interleave: setiap 2 DB news, sisipkan 1 AI news
    final combined = <UnifiedNewsItem>[];
    int dbIdx = 0, aiIdx = 0;

    while (dbIdx < dbItems.length || aiIdx < aiItems.length) {
      // Ambil 2 DB
      for (int i = 0; i < 2 && dbIdx < dbItems.length; i++, dbIdx++) {
        combined.add(dbItems[dbIdx]);
      }
      // Sisipkan 1 AI
      if (aiIdx < aiItems.length) {
        combined.add(aiItems[aiIdx++]);
      }
    }

    _feed = combined;
    _filterFeed();
  }

  void _filterFeed() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFeed = _feed;
      } else {
        _filteredFeed = _feed.where((item) {
          return item.title.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query) ||
              item.newsSource.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _refresh() async {
    _dbNews  = [];
    _aiNews  = [];
    _feed    = [];
    await _loadAll();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role.toLowerCase() == 'admin';

    return Scaffold(
      backgroundColor: NewsColorStyle.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isAdmin),
            _buildStatsBar(),
            Expanded(
              child: _isLoading
                  ? _buildLoading()
                  : _filteredFeed.isEmpty
                      ? _buildEmptyState()
                      : _buildFeed(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(bool isAdmin) {
    return Container(
      padding: const EdgeInsets.fromLTRB(48, 32, 48, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Text('News', style: NewsColorStyle.sectionTitleStyle),
              if (_aiGenerating) ...[
                const SizedBox(width: 12),
                _AiGeneratingBadge(),
              ],
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

  // ---------------------------------------------------------------------------
  // Stats bar — DB count + AI count
  // ---------------------------------------------------------------------------

  Widget _buildStatsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 48, 20),
      child: Row(
        children: [
          _StatChip(
            label: '$_dbCount Exclusive',
            color: NewsColorStyle.greenNeon,
            icon: Icons.newspaper_outlined,
          ),
          const SizedBox(width: 12),
          _StatChip(
            label: '$_aiCount AI Generated',
            color: const Color(0xFF7B61FF),
            icon: Icons.auto_awesome,
          ),
          if (_aiError != null) ...[
            const SizedBox(width: 12),
            _StatChip(
              label: 'AI Unavailable',
              color: Colors.red.shade400,
              icon: Icons.error_outline,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Feed grid
  // ---------------------------------------------------------------------------

  Widget _buildFeed() {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: NewsColorStyle.greenNeon,
      backgroundColor: NewsColorStyle.cardBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 0, 48, 32),
        child: GridView.builder(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 0.75,
          ),
          itemCount: _filteredFeed.length,
          itemBuilder: (context, index) {
            final item = _filteredFeed[index];
            return item.source == NewsSource.database
                ? _DbNewsCard(
                    index:    index,
                    item:     item,
                    onTap:    () => _openDbNews(item),
                  )
                : _AiNewsCard(
                    index: index,
                    item:  item,
                  );
          },
        ),
      ),
    );
  }

  void _openDbNews(UnifiedNewsItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostinganNewsScreen(newsData: item.dbData!),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search bar
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isSearchFocused = hasFocus),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 280,
        height: 44,
        decoration: NewsCardTheme.searchBarDecoration(isFocused: _isSearchFocused),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: NewsColorStyle.searchText, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search news...',
            hintStyle: const TextStyle(
              color: NewsColorStyle.searchPlaceholder,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: _isSearchFocused
                  ? NewsColorStyle.greenNeon
                  : NewsColorStyle.searchPlaceholder,
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: NewsColorStyle.searchPlaceholder,
                      size: 18,
                    ),
                    onPressed: _searchController.clear,
                  )
                : null,
            border:          InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical:   12,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Add button
  // ---------------------------------------------------------------------------

  Widget _buildAddButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            '/upload_news',
            arguments: widget.token,
          );
          if (result == true) _refresh();
        },
        icon:  const Icon(Icons.add, size: 18),
        label: const Text(
          'Add News',
          style: TextStyle(
            fontSize:      14,
            fontWeight:    FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: NewsColorStyle.addButtonBackground,
          foregroundColor: NewsColorStyle.addButtonText,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.hovered)
                ? Colors.black.withOpacity(0.1)
                : null,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading & empty
  // ---------------------------------------------------------------------------

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color:       NewsColorStyle.greenNeon,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading news feed...',
            style: TextStyle(
              color:    NewsColorStyle.subtitleText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.newspaper_outlined,
            size:  64,
            color: NewsColorStyle.sourceText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty ? 'No news available' : 'No news found',
            style: const TextStyle(
              color:      NewsColorStyle.subtitleText,
              fontSize:   16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Pull down to refresh'
                : 'Try different search keywords',
            style: const TextStyle(
              color:    NewsColorStyle.sourceText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// DB News Card — sama seperti _NewsCard sebelumnya
// ===========================================================================

class _DbNewsCard extends StatefulWidget {
  final int               index;
  final UnifiedNewsItem   item;
  final VoidCallback      onTap;

  const _DbNewsCard({
    required this.index,
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
    final item = widget.item;

    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit:  (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translate(0.0, isHovered ? -8.0 : 0.0),
          child: Stack(
            children: [
              // Background image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: item.imageUrl.isNotEmpty
                    ? Image.network(
                        'http://127.0.0.1:8080/${item.imageUrl}',
                        fit:    BoxFit.cover,
                        width:  double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => _placeholder(),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              color:       NewsColorStyle.greenNeon,
                              strokeWidth: 2,
                            ),
                          );
                        },
                      )
                    : _placeholder(),
              ),

              // Gradient overlay
              Container(
                decoration: NewsCardTheme.cardDecoration(
                  index:     widget.index,
                  isHovered: isHovered,
                ),
              ),

              // Content
              Container(
                decoration: NewsCardTheme.textOverlayDecoration(),
                padding:    const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:  MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical:   6,
                      ),
                      decoration: NewsCardTheme.newsBadgeDecoration(),
                      child: Text('NEWS', style: NewsColorStyle.badgeTextStyle),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      item.title,
                      style:    NewsColorStyle.newsTitleStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      item.description,
                      style:    NewsColorStyle.newsSubtitleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Icon(
                          Icons.source_outlined,
                          size:  14,
                          color: NewsColorStyle.sourceText,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.newsSource,
                            style:    NewsColorStyle.newsSourceStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.date.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.calendar_today_outlined,
                            size:  14,
                            color: NewsColorStyle.sourceText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(item.date),
                            style: NewsColorStyle.newsSourceStyle,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: NewsColorStyle.cardBackground,
      child: Center(
        child: Icon(
          Icons.newspaper,
          size:  64,
          color: NewsColorStyle.sourceText.withOpacity(0.3),
        ),
      ),
    );
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    try {
      final parsed     = DateTime.parse(date);
      final now        = DateTime.now();
      final difference = now.difference(parsed);
      if (difference.inDays == 0)      return 'Today';
      if (difference.inDays == 1)      return 'Yesterday';
      if (difference.inDays < 7)       return '${difference.inDays}d ago';
      if (difference.inDays < 30)      return '${(difference.inDays / 7).floor()}w ago';
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (_) {
      return date;
    }
  }
}

// ===========================================================================
// AI News Card — desain berbeda, ungu, ada sentiment + link sumber asli
// ===========================================================================

class _AiNewsCard extends StatefulWidget {
  final int             index;
  final UnifiedNewsItem item;

  const _AiNewsCard({required this.index, required this.item});

  @override
  State<_AiNewsCard> createState() => _AiNewsCardState();
}

class _AiNewsCardState extends State<_AiNewsCard> {
  bool isHovered = false;

  static const _aiAccent    = Color(0xFF7B61FF);
  static const _aiBg        = Color(0xFF1A1528);
  static const _aiBorder    = Color(0xFF3D2F6E);

  Color get _sentimentColor {
    switch (widget.item.sentiment.toLowerCase()) {
      case 'optimis':
      case 'positif':
        return const Color(0xFF00E5A0);
      case 'negatif':
      case 'pesimis':
        return const Color(0xFFFF5A5A);
      default:
        return const Color(0xFFAAAAAA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit:  (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve:    Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translate(0.0, isHovered ? -8.0 : 0.0),
        decoration: BoxDecoration(
          color:        _aiBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHovered ? _aiAccent : _aiBorder,
            width: isHovered ? 1.5 : 1.0,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color:   _aiAccent.withOpacity(0.25),
                    blurRadius:    24,
                    spreadRadius:  0,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: AI badge + sentiment
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // AI badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical:    5,
                    ),
                    decoration: BoxDecoration(
                      color:        _aiAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _aiAccent.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 11, color: _aiAccent),
                        const SizedBox(width: 5),
                        Text(
                          'AI NEWS',
                          style: TextStyle(
                            color:       _aiAccent,
                            fontSize:    10,
                            fontWeight:  FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sentiment badge
                  if (item.sentiment.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical:   4,
                      ),
                      decoration: BoxDecoration(
                        color:        _sentimentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width:  6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _sentimentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            item.sentiment.toUpperCase(),
                            style: TextStyle(
                              color:        _sentimentColor,
                              fontSize:     9,
                              fontWeight:   FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Title
              Text(
                item.title,
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   15,
                  fontWeight: FontWeight.w700,
                  height:     1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 10),

              // Description
              Expanded(
                child: Text(
                  item.description,
                  style: TextStyle(
                    color:    Colors.white.withOpacity(0.55),
                    fontSize: 12.5,
                    height:   1.5,
                  ),
                  overflow: TextOverflow.fade,
                ),
              ),

              const SizedBox(height: 12),

              // Confidence bar
              if (item.confidence > 0) ...[
                Row(
                  children: [
                    Text(
                      'Confidence',
                      style: TextStyle(
                        color:    Colors.white.withOpacity(0.4),
                        fontSize: 10,
                      ),
                    ),
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
                      style: TextStyle(
                        color:      _sentimentColor,
                        fontSize:   10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Divider
              Divider(color: Colors.white.withOpacity(0.08), height: 1),
              const SizedBox(height: 12),

              // Source + date + link
              Row(
                children: [
                  Icon(
                    Icons.source_outlined,
                    size:  12,
                    color: Colors.white.withOpacity(0.35),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item.newsSource,
                      style: TextStyle(
                        color:    Colors.white.withOpacity(0.45),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.date.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(item.date),
                      style: TextStyle(
                        color:    Colors.white.withOpacity(0.3),
                        fontSize: 10,
                      ),
                    ),
                  ],
                  // Link icon → buka sumber asli
                  if (item.originalLink.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        // Buka URL — gunakan url_launcher jika tersedia
                        // launchUrl(Uri.parse(item.originalLink));
                        debugPrint('🔗 Open: ${item.originalLink}');
                      },
                      child: Icon(
                        Icons.open_in_new,
                        size:  14,
                        color: _aiAccent.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),

              // Domain tag (opsional)
              if (item.originalDomain.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical:   3,
                  ),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '# ${item.originalDomain}',
                    style: TextStyle(
                      color:        Colors.white.withOpacity(0.3),
                      fontSize:     10,
                      fontStyle:    FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    try {
      final parsed     = DateTime.parse(date);
      final now        = DateTime.now();
      final difference = now.difference(parsed);
      if (difference.inDays == 0) return 'Today';
      if (difference.inDays == 1) return 'Yesterday';
      if (difference.inDays < 7)  return '${difference.inDays}d ago';
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (_) {
      return date;
    }
  }
}

// ===========================================================================
// Helper widgets
// ===========================================================================

/// Badge "AI Generating..." yang berputar di header
class _AiGeneratingBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        const Color(0xFF7B61FF).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7B61FF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width:  10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color:       const Color(0xFF7B61FF),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'AI generating...',
            style: TextStyle(
              color:      Color(0xFF7B61FF),
              fontSize:   11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip kecil untuk stats bar
class _StatChip extends StatelessWidget {
  final String  label;
  final Color   color;
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
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color:      color,
              fontSize:   12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}