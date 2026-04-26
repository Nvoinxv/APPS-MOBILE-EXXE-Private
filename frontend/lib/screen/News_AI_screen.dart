import 'package:flutter/material.dart';
import '../hooks/news_ai_hook.dart';
import '../style/apps_color_news.dart';

// ===========================================================================
// _AiNewsCard — unified widget untuk grid (compact) & list (horizontal)
//
// Penggunaan:
//   _AiNewsCard(item: item, onTap: () => _openAiNews(item))              // auto-detect layout
//   _AiNewsCard(item: item, onTap: ..., displayMode: AiCardMode.grid)    // paksa grid
//   _AiNewsCard(item: item, onTap: ..., displayMode: AiCardMode.list)    // paksa list
// ===========================================================================

enum AiCardMode { grid, list }

class _AiNewsCard extends StatefulWidget {
  final UnifiedNewsItem item;
  final VoidCallback    onTap;

  /// Paksa mode tertentu. Jika null, card otomatis pakai list di lebar ≥ 600.
  final AiCardMode? displayMode;

  const _AiNewsCard({
    super.key,
    required this.item,
    required this.onTap,
    this.displayMode,
  });

  @override
  State<_AiNewsCard> createState() => _AiNewsCardState();
}

class _AiNewsCardState extends State<_AiNewsCard> {
  bool _isHovered       = false;
  bool _imageFailedLoad = false;

  // ── Palette per-sentiment ─────────────────────────────────────────────────

  static const _palettes = <String, _SentimentPalette>{
    'optimis':  _SentimentPalette(
      accent:    Color(0xFF00CC44),
      neon:      Color(0xFFBEFF00),
      panelBg:   Color(0xFF0A1A0D),
      dotColor:  Color(0xFF00CC44),
      arrow:     '↑',
    ),
    'positif':  _SentimentPalette(
      accent:    Color(0xFF1E90FF),
      neon:      Color(0xFF7EC8FF),
      panelBg:   Color(0xFF0A0F1A),
      dotColor:  Color(0xFF1E90FF),
      arrow:     '↗',
    ),
    'netral':   _SentimentPalette(
      accent:    Color(0xFF888780),
      neon:      Color(0xFFBBBBB0),
      panelBg:   Color(0xFF141412),
      dotColor:  Color(0xFF888780),
      arrow:     '→',
    ),
    'negatif':  _SentimentPalette(
      accent:    Color(0xFFFF8C42),
      neon:      Color(0xFFFFB380),
      panelBg:   Color(0xFF1A0E07),
      dotColor:  Color(0xFFFF8C42),
      arrow:     '↘',
    ),
    'pesimis':  _SentimentPalette(
      accent:    Color(0xFFFF5A5A),
      neon:      Color(0xFFFF9999),
      panelBg:   Color(0xFF1A0A0A),
      dotColor:  Color(0xFFFF5A5A),
      arrow:     '↓',
    ),
  };

  _SentimentPalette get _palette =>
      _palettes[widget.item.sentiment.toLowerCase()] ?? _palettes['netral']!;

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Coba bangun URL thumbnail dari domain (og:image via Google favicon proxy
  /// sebagai fallback pertama, lalu placeholder logo).
  /// Untuk og:image sejati perlu HTTP fetch — di sini kita pakai dua tier:
  ///   1. Domain screenshot via Google favicon CDN (cepat, no-CORS)
  ///   2. Jika gagal → _SentimentPanel
  String? get _thumbnailUrl {
    final domain = widget.item.originalDomain;
    if (domain.isEmpty) return null;
    // Tier 1: favicon CDN sebagai quick-thumbnail
    // Ganti dengan og:image endpoint internal jika backend menyediakannya.
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=256';
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

  // ── Build root ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mode = widget.displayMode ??
        (MediaQuery.of(context).size.width >= 600 ? AiCardMode.list : AiCardMode.grid);

    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: mode == AiCardMode.list
            ? _buildListCard()
            : _buildGridCard(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIST CARD  — full-width horizontal, same structure as _DbNewsCard
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildListCard() {
    final p     = _palette;
    final item  = widget.item;

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: AnimatedContainer(
        duration:  const Duration(milliseconds: 300),
        curve:     Curves.easeOutCubic,
        transform: Matrix4.identity()..translate(0.0, _isHovered ? -4.0 : 0.0),
        decoration: BoxDecoration(
          color:        p.panelBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered ? p.accent.withOpacity(0.5) : p.accent.withOpacity(0.18),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: _isHovered
              ? [BoxShadow(
                  color:       p.accent.withOpacity(0.15),
                  blurRadius:  24,
                  spreadRadius: 0,
                  offset:      const Offset(0, 8),
                )]
              : [BoxShadow(
                  color:      Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset:     const Offset(0, 4),
                )],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Panel kiri: thumbnail / sentiment panel ────────────────────
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft:    Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: _buildImagePanel(height: 280, mode: AiCardMode.list),
              ),
            ),

            // ── Konten kanan ──────────────────────────────────────────────
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _buildListContent(p, item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListContent(_SentimentPalette p, UnifiedNewsItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge baris atas
        _AiBadge(accent: p.accent, neon: p.neon),
        const SizedBox(height: 16),

        // Title
        Text(
          item.title,
          style: const TextStyle(
            color:      Colors.white,
            fontSize:   26,
            fontWeight: FontWeight.bold,
            height:     1.2,
            letterSpacing: -0.5,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),

        // Description
        Text(
          item.description,
          style: TextStyle(
            color:    Colors.white.withOpacity(0.6),
            fontSize: 14,
            height:   1.55,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 20),

        // Sentiment badge + confidence
        _SentimentBadge(palette: p, sentiment: item.sentiment),
        if (item.confidence > 0) ...[
          const SizedBox(height: 10),
          _ConfidenceBar(palette: p, value: item.confidence),
        ],
        const SizedBox(height: 20),

        // Source row
        _SourceRow(
          source: item.newsSource,
          date:   _formatDate(item.date),
          domain: item.originalDomain,
          accent: p.accent,
        ),
        const SizedBox(height: 16),

        // CTA
        Row(
          children: [
            Text(
              'Read AI summary',
              style: TextStyle(
                color:      p.neon,
                fontSize:   14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration:  const Duration(milliseconds: 200),
              transform: Matrix4.identity()
                ..translate(_isHovered ? 4.0 : 0.0, 0.0),
              child: Icon(Icons.arrow_forward, size: 16, color: p.neon),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GRID CARD  — compact, mirip _DbNewsCard grid (childAspectRatio 0.75)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGridCard() {
    final p    = _palette;
    final item = widget.item;

    return AnimatedContainer(
      duration:  const Duration(milliseconds: 300),
      curve:     Curves.easeOutCubic,
      transform: Matrix4.identity()..translate(0.0, _isHovered ? -8.0 : 0.0),
      decoration: BoxDecoration(
        color:        p.panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isHovered ? p.accent : p.accent.withOpacity(0.2),
          width: _isHovered ? 1.5 : 1.0,
        ),
        boxShadow: _isHovered
            ? [BoxShadow(
                color:      p.accent.withOpacity(0.25),
                blurRadius: 24,
                offset:     const Offset(0, 8),
              )]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail / sentiment panel — 45% tinggi card
          Flexible(
            flex: 45,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: _buildImagePanel(height: double.infinity, mode: AiCardMode.grid),
            ),
          ),

          // Konten bawah — 55% sisanya
          Flexible(
            flex: 55,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _buildGridContent(p, item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridContent(_SentimentPalette p, UnifiedNewsItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge + sentiment chip di satu baris
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _AiBadge(accent: p.accent, neon: p.neon, compact: true),
            _SentimentChip(palette: p, sentiment: item.sentiment),
          ],
        ),
        const SizedBox(height: 10),

        // Title
        Text(
          item.title,
          style: const TextStyle(
            color:      Colors.white,
            fontSize:   14,
            fontWeight: FontWeight.w700,
            height:     1.3,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),

        // Description
        Expanded(
          child: Text(
            item.description,
            style: TextStyle(
              color:    Colors.white.withOpacity(0.5),
              fontSize: 12,
              height:   1.5,
            ),
            overflow: TextOverflow.fade,
          ),
        ),

        // Confidence bar
        if (item.confidence > 0) ...[
          const SizedBox(height: 8),
          _ConfidenceBar(palette: p, value: item.confidence, compact: true),
        ],

        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
        ),

        // Source + domain tag
        _SourceRow(
          source: item.newsSource,
          date:   _formatDate(item.date),
          domain: item.originalDomain,
          accent: p.accent,
          compact: true,
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // IMAGE PANEL  — og:image → favicon CDN → sentiment fallback
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildImagePanel({required double height, required AiCardMode mode}) {
    final p      = _palette;
    final url    = _thumbnailUrl;
    final isGrid = mode == AiCardMode.grid;

    Widget background;

    if (url != null && !_imageFailedLoad) {
      // Coba load gambar domain
      background = Image.network(
        url,
        fit:    BoxFit.cover,
        width:  double.infinity,
        height: height,
        errorBuilder: (_, __, ___) {
          // Kalau gagal, tandai dan render sentiment panel
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _imageFailedLoad = true);
          });
          return _SentimentPanel(palette: p, item: widget.item, isGrid: isGrid, height: height);
        },
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return _SentimentPanel(palette: p, item: widget.item, isGrid: isGrid, height: height);
        },
      );
    } else {
      // Tidak ada URL atau gambar gagal → langsung sentiment panel
      background = _SentimentPanel(palette: p, item: widget.item, isGrid: isGrid, height: height);
    }

    return SizedBox(
      height: height == double.infinity ? null : height,
      child:  Stack(
        fit: StackFit.expand,
        children: [
          background,

          // Gradient overlay supaya teks di atas gambar terbaca
          if (url != null && !_imageFailedLoad)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    p.panelBg.withOpacity(0.85),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),

          // AI badge (selalu tampil di atas)
          Positioned(
            top:  12,
            left: 12,
            child: _AiBadgePill(accent: p.accent, neon: p.neon),
          ),

          // Expand icon saat hover
          Positioned(
            top:   12,
            right: 12,
            child: AnimatedOpacity(
              opacity:  _isHovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding:    const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color:        Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.open_in_full_rounded, size: 11, color: p.neon),
              ),
            ),
          ),

          // Domain tag di sudut bawah kanan
          if (widget.item.originalDomain.isNotEmpty)
            Positioned(
              bottom: 10,
              right:  10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '# ${widget.item.originalDomain}',
                  style: TextStyle(
                    color:     p.accent.withOpacity(0.6),
                    fontSize:  10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// _SentimentPanel — fallback jika tidak ada gambar
// Dot pattern + sentiment circle (dinamis per-label)
// ===========================================================================

class _SentimentPanel extends StatelessWidget {
  final _SentimentPalette palette;
  final UnifiedNewsItem   item;
  final bool              isGrid;
  final double            height;

  const _SentimentPanel({
    required this.palette,
    required this.item,
    required this.isGrid,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;

    return Container(
      height: height == double.infinity ? null : height,
      color:  p.panelBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dot grid pattern
          CustomPaint(painter: _DotPatternPainter(color: p.accent)),

          // Sentiment circle + label + confidence bar
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Arrow circle
                Container(
                  width:  isGrid ? 56 : 72,
                  height: isGrid ? 56 : 72,
                  decoration: BoxDecoration(
                    shape:  BoxShape.circle,
                    color:  p.accent.withOpacity(0.1),
                    border: Border.all(
                      color: p.accent.withOpacity(0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      p.arrow,
                      style: TextStyle(
                        fontSize:   isGrid ? 24 : 30,
                        color:      p.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: isGrid ? 8 : 10),

                // Sentiment label
                if (item.sentiment.isNotEmpty)
                  Text(
                    item.sentiment.toUpperCase(),
                    style: TextStyle(
                      color:        p.accent,
                      fontSize:     isGrid ? 9 : 11,
                      fontWeight:   FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),

                if (item.confidence > 0) ...[
                  SizedBox(height: isGrid ? 6 : 8),
                  SizedBox(
                    width: isGrid ? 72 : 96,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:           item.confidence,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        valueColor:      AlwaysStoppedAnimation(p.accent),
                        minHeight:       3,
                      ),
                    ),
                  ),
                  SizedBox(height: isGrid ? 4 : 6),
                  Text(
                    '${(item.confidence * 100).toStringAsFixed(0)}% confidence',
                    style: TextStyle(
                      color:    Colors.white.withOpacity(0.35),
                      fontSize: isGrid ? 9 : 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Sub-widgets — reusable pieces
// ===========================================================================

/// Badge "✦ AI GENERATED NEWS" dengan ukuran normal atau compact
class _AiBadge extends StatelessWidget {
  final Color  accent;
  final Color  neon;
  final bool   compact;

  const _AiBadge({
    required this.accent,
    required this.neon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical:   compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color:        accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: accent.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: compact ? 10 : 12, color: neon),
          SizedBox(width: compact ? 4 : 6),
          Text(
            compact ? 'AI' : 'AI GENERATED NEWS',
            style: TextStyle(
              color:         neon,
              fontSize:      compact ? 9 : 11,
              fontWeight:    FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill "AI NEWS" yang ditempel di atas panel gambar
class _AiBadgePill extends StatelessWidget {
  final Color accent;
  final Color neon;

  const _AiBadgePill({required this.accent, required this.neon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color:        accent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: accent.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 10, color: neon),
          const SizedBox(width: 5),
          Text(
            'AI NEWS',
            style: TextStyle(
              color:         neon,
              fontSize:      10,
              fontWeight:    FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sentiment badge — baris label + dot untuk list card
class _SentimentBadge extends StatelessWidget {
  final _SentimentPalette palette;
  final String            sentiment;

  const _SentimentBadge({required this.palette, required this.sentiment});

  @override
  Widget build(BuildContext context) {
    if (sentiment.isEmpty) return const SizedBox.shrink();
    final p = palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        p.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: p.accent.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  7,
            height: 7,
            decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            sentiment.toUpperCase(),
            style: TextStyle(
              color:         p.accent,
              fontSize:      11,
              fontWeight:    FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sentiment chip kecil — untuk pojok kanan grid card
class _SentimentChip extends StatelessWidget {
  final _SentimentPalette palette;
  final String            sentiment;

  const _SentimentChip({required this.palette, required this.sentiment});

  @override
  Widget build(BuildContext context) {
    if (sentiment.isEmpty) return const SizedBox.shrink();
    final p = palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        p.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  5,
            height: 5,
            decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            sentiment.toUpperCase(),
            style: TextStyle(
              color:         p.accent,
              fontSize:      8,
              fontWeight:    FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Confidence bar dengan label opsional compact
class _ConfidenceBar extends StatelessWidget {
  final _SentimentPalette palette;
  final double            value;
  final bool              compact;

  const _ConfidenceBar({
    required this.palette,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Row(
      children: [
        Text(
          'Confidence',
          style: TextStyle(
            color:    Colors.white.withOpacity(0.4),
            fontSize: compact ? 9 : 11,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           value,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor:      AlwaysStoppedAnimation(p.accent),
              minHeight:       compact ? 3 : 4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(value * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color:      p.accent,
            fontSize:   compact ? 9 : 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Source + date + domain tag
class _SourceRow extends StatelessWidget {
  final String source;
  final String date;
  final String domain;
  final Color  accent;
  final bool   compact;

  const _SourceRow({
    required this.source,
    required this.date,
    required this.domain,
    required this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Source icon
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color:        accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(Icons.source_outlined, size: compact ? 11 : 13, color: accent),
        ),
        const SizedBox(width: 7),

        // Source name
        Expanded(
          child: Text(
            source,
            style: TextStyle(
              color:      Colors.white,
              fontSize:   compact ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Date
        if (date.isNotEmpty) ...[
          const SizedBox(width: 10),
          Icon(
            Icons.calendar_today_outlined,
            size:  compact ? 11 : 13,
            color: Colors.white.withOpacity(0.35),
          ),
          const SizedBox(width: 4),
          Text(
            date,
            style: TextStyle(
              color:    Colors.white.withOpacity(0.4),
              fontSize: compact ? 10 : 12,
            ),
          ),
        ],

        // Domain tag
        if (domain.isNotEmpty && !compact) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '# $domain',
              style: TextStyle(
                color:     accent.withOpacity(0.6),
                fontSize:  11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ===========================================================================
// Dot pattern painter (sama seperti di AiNewsDetailScreen)
// ===========================================================================

class _DotPatternPainter extends CustomPainter {
  final Color color;
  const _DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 18.0;
    final paint   = Paint()
      ..color = color.withOpacity(0.12)
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
// Data class palette per-sentiment
// ===========================================================================

class _SentimentPalette {
  final Color  accent;   // warna utama UI (border, badge, CTA)
  final Color  neon;     // warna highlight terang (text CTA, badge text)
  final Color  panelBg;  // background panel gambar / card
  final Color  dotColor; // warna dot pattern
  final String arrow;    // simbol arah sentimen

  const _SentimentPalette({
    required this.accent,
    required this.neon,
    required this.panelBg,
    required this.dotColor,
    required this.arrow,
  });
}