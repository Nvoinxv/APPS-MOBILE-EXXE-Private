import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../style/apps_color_news.dart';
import '../pages/news_pages.dart'; // UnifiedNewsItem

// ===========================================================================
// PostinganAiNewsScreen
// Detail screen untuk AI news — layout & struktur identik dengan
// PostinganNewsScreen (manual), hanya tambahan badge AI + sentiment card.
// ===========================================================================

class PostinganAiNewsScreen extends StatefulWidget {
  final UnifiedNewsItem item;

  const PostinganAiNewsScreen({super.key, required this.item});

  @override
  State<PostinganAiNewsScreen> createState() => _PostinganAiNewsScreenState();
}

class _PostinganAiNewsScreenState extends State<PostinganAiNewsScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOpacity = 0.0;
  bool   _imageFailed   = false;

  UnifiedNewsItem get item => widget.item;

  // ── Warna ─────────────────────────────────────────────────────────────────
  static const _aiAccent = Color(0xFF00CC44);
  static const _aiNeon   = Color(0xFFBEFF00);

  static const _sentimentColors = <String, Color>{
    'optimis': Color(0xFF00CC44),
    'positif': Color(0xFF1E90FF),
    'netral':  Color(0xFF888780),
    'negatif': Color(0xFFFF8C42),
    'pesimis': Color(0xFFFF5A5A),
  };

  static const _sentimentArrows = <String, String>{
    'optimis': '↑', 'positif': '↗', 'netral': '→', 'negatif': '↘', 'pesimis': '↓',
  };

  Color get _sentimentColor =>
      _sentimentColors[item.sentiment.toLowerCase()] ?? const Color(0xFF888780);

  String get _sentimentArrow =>
      _sentimentArrows[item.sentiment.toLowerCase()] ?? '→';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    setState(() => _scrollOpacity = (offset / 200).clamp(0.0, 1.0));
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

  String _formatDateFull(String date) {
    if (date.isEmpty) return 'Date not available';
    try {
      final parsed = DateTime.parse(date);
      const months = ['January','February','March','April','May','June',
                      'July','August','September','October','November','December'];
      return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
    } catch (_) { return date; }
  }

  String _calculateReadingTime(String content) {
    if (content.isEmpty) return '1 min read';
    final wordCount = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final minutes   = (wordCount / 200).ceil();
    return '${minutes > 0 ? minutes : 1} min read';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NewsColorStyle.backgroundColor,
      body: Stack(
        children: [
          // ── Main scroll ────────────────────────────────────────────────
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildHeroAppBar(),
              SliverToBoxAdapter(
                child: Container(
                  color: NewsColorStyle.backgroundColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetaBar(),
                      _buildBody(),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Sticky top bar on scroll ───────────────────────────────────
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity:  _scrollOpacity,
            child: Container(
              color: NewsColorStyle.backgroundColor.withOpacity(0.95),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _aiAccent,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Copy button
                    _buildCopyButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero SliverAppBar — sama persis dengan PostinganNewsScreen ────────────

  Widget _buildHeroAppBar() {
    final imageUrl = item.imageUrl.isNotEmpty ? item.imageUrl : '';
    final hasImage = imageUrl.isNotEmpty && !_imageFailed;

    return SliverAppBar(
      expandedHeight: 500,
      pinned: true,
      backgroundColor: NewsColorStyle.backgroundColor,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.5),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _buildCopyButton(),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // ── Hero image (opsional) atau fallback sentiment panel ────
            if (hasImage)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _imageFailed = true);
                  });
                  return _buildHeroFallback();
                },
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _buildHeroFallback(),
              )
            else
              _buildHeroFallback(),

            // ── Gradient overlay ──────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x66000000), Color(0xDD000000)],
                  stops:  [0.3, 0.7, 1.0],
                ),
              ),
            ),

            // ── Title + badges overlay di bawah ───────────────────────
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge row: AI badge + sentiment
                    Row(
                      children: [
                        _buildAiBadge(),
                        if (item.sentiment.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          _buildSentimentBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 36,
                        fontWeight: FontWeight.bold, height: 1.2, letterSpacing: -0.5,
                        shadows: [Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 8)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fallback hero: dot pattern + sentiment circle (mirip card panel kiri)
  Widget _buildHeroFallback() {
    return Container(
      color: const Color(0xFF0A1A0D),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _DotPatternPainter(color: _aiAccent)),
          if (item.sentiment.isNotEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      shape:  BoxShape.circle,
                      color:  _sentimentColor.withOpacity(0.1),
                      border: Border.all(color: _sentimentColor.withOpacity(0.45), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _sentimentArrow,
                        style: TextStyle(fontSize: 36, color: _sentimentColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.sentiment.toUpperCase(),
                    style: TextStyle(color: _sentimentColor, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Metadata bar — identik dengan PostinganNewsScreen ────────────────────

  Widget _buildMetaBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: NewsColorStyle.searchBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Source
          Icon(Icons.source_outlined, size: 18, color: _aiAccent),
          const SizedBox(width: 8),
          Text(
            item.newsSource.isNotEmpty ? item.newsSource : 'AI Generated',
            style: TextStyle(color: _aiAccent, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),

          const SizedBox(width: 24),

          // Date
          if (item.date.isNotEmpty) ...[
            Icon(Icons.calendar_today_outlined, size: 16, color: NewsColorStyle.sourceText),
            const SizedBox(width: 8),
            Text(_formatDate(item.date), style: const TextStyle(color: NewsColorStyle.sourceText, fontSize: 14)),
          ],

          const Spacer(),

          // Domain tag
          if (item.originalDomain.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '# ${item.originalDomain}',
                style: TextStyle(color: _aiAccent.withOpacity(0.6), fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  // ── Body konten ───────────────────────────────────────────────────────────

  Widget _buildBody() {
    final description = item.description;
    final body        = item.generatedBody;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sentiment analysis card (AI exclusive)
          if (item.sentiment.isNotEmpty) ...[
            _buildSentimentCard(),
            const SizedBox(height: 32),
          ],

          // Description / summary (highlight box)
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: const TextStyle(
                color: NewsColorStyle.highlightText, fontSize: 20,
                fontWeight: FontWeight.w600, height: 1.4, letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 32),
          ],

          // Divider
          Container(height: 1, color: NewsColorStyle.searchBorder),
          const SizedBox(height: 32),

          // Main body paragraphs
          if (body.isNotEmpty)
            _buildParagraphs(body)
          else
            Text(
              'No content available.',
              style: TextStyle(color: NewsColorStyle.subtitleText.withOpacity(0.5), fontSize: 16),
            ),

          const SizedBox(height: 48),

          // Divider
          Container(height: 1, color: NewsColorStyle.searchBorder),
          const SizedBox(height: 32),

          // Footer info — identik dengan PostinganNewsScreen
          _buildFooterInfo(),

          // Original source card
          if (item.originalLink.isNotEmpty || item.originalTitle.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildOriginalSourceCard(),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildParagraphs(String body) {
    final paragraphs = body.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.asMap().entries.map((entry) {
        final idx  = entry.key;
        final para = entry.value;

        if (para.startsWith('## ') || para.startsWith('# ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Text(
              para.replaceFirst(RegExp(r'^#+\s*'), ''),
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18, fontWeight: FontWeight.w700, height: 1.3),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: idx < paragraphs.length - 1 ? 20 : 0),
          child: Text(
            para,
            style: const TextStyle(color: NewsColorStyle.subtitleText, fontSize: 16, fontWeight: FontWeight.w400, height: 1.8, letterSpacing: 0.1),
          ),
        );
      }).toList(),
    );
  }

  // ── Sentiment card (AI only) ──────────────────────────────────────────────

  Widget _buildSentimentCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        _sentimentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: _sentimentColor.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          // Circle icon
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  _sentimentColor.withOpacity(0.1),
              border: Border.all(color: _sentimentColor.withOpacity(0.4), width: 1.5),
            ),
            child: Center(
              child: Text(_sentimentArrow, style: TextStyle(fontSize: 20, color: _sentimentColor, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 20),

          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Sentiment Analysis', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(item.sentiment.toUpperCase(), style: TextStyle(color: _sentimentColor, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                if (item.confidence > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:           item.confidence,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor:      AlwaysStoppedAnimation(_sentimentColor),
                      minHeight:       5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${(item.confidence * 100).toStringAsFixed(1)}% confidence',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  ),
                ],
              ],
            ),
          ),

          // Score badge
          if (item.score != 0)
            Column(
              children: [
                Text('Score', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                const SizedBox(height: 4),
                Text(
                  item.score.toStringAsFixed(2),
                  style: TextStyle(color: _sentimentColor, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Footer info — identik dengan PostinganNewsScreen ─────────────────────

  Widget _buildFooterInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        NewsColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: NewsColorStyle.searchBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:        _aiAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info_outline, color: _aiAccent, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('About this article', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.source_outlined,         'Source',       item.newsSource.isNotEmpty ? item.newsSource : 'EXXE News AI'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.calendar_today_outlined,  'Published',    _formatDateFull(item.date)),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.auto_awesome,             'Generated by', 'EXXE News AI'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.access_time,              'Reading time', _calculateReadingTime(item.generatedBody)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: NewsColorStyle.sourceText),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: NewsColorStyle.sourceText, fontSize: 14)),
        Expanded(child: Text(value, style: const TextStyle(color: NewsColorStyle.subtitleText, fontSize: 14, fontWeight: FontWeight.w500))),
      ],
    );
  }

  // ── Original source card ──────────────────────────────────────────────────

  Widget _buildOriginalSourceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        NewsColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: _aiAccent.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, size: 16, color: _aiAccent),
              const SizedBox(width: 8),
              Text('Original Source', style: TextStyle(color: _aiAccent, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 16),
          if (item.originalTitle.isNotEmpty) ...[
            Text(item.originalTitle, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
            const SizedBox(height: 12),
          ],
          if (item.newsSource.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(item.newsSource, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
            ),
          if (item.originalLink.isNotEmpty) ...[
            const SizedBox(height: 16),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: item.originalLink));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:         const Text('Link copied to clipboard'),
                    backgroundColor: _aiAccent.withOpacity(0.9),
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
                        child: Text(item.originalLink, style: TextStyle(color: _aiAccent, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
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

  // ── Small reusable widgets ────────────────────────────────────────────────

  Widget _buildAiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:        _aiAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: _aiAccent.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 13, color: _aiNeon),
          const SizedBox(width: 6),
          Text('AI GENERATED NEWS', style: TextStyle(color: _aiNeon, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        ],
      ),
    );
  }

  Widget _buildSentimentBadge() {
    if (item.sentiment.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        _sentimentColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: _sentimentColor.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: _sentimentColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(item.sentiment.toUpperCase(), style: TextStyle(color: _sentimentColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
        ],
      ),
    );
  }

  Widget _buildCopyButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: item.generatedBody));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:         const Text('Article copied to clipboard'),
            backgroundColor: _aiAccent.withOpacity(0.9),
            behavior:        SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 2),
          ));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:        Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy_outlined, size: 14, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text('Copy', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Dot pattern painter (shared)
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