import '../models/script_file.dart';
// =============================================================================
// postingan_tradingview.dart
// Path: frontend/lib/postingan/postingan_tradingview.dart
//
// FIX: "Add Indicator" / "New Indicator" button tidak bisa dipencet.
//
// Root causes:
//   1. IndicatorEmptyState — "New Indicator" button tidak wrapped GestureDetector,
//      hanya Container dekoratif. Ditambah onCreateNew callback + GestureDetector.
//
//   2. IndicatorListView — tidak ada tombol "+" untuk buat indikator baru
//      ketika list sudah berisi item. Ditambah onCreateNew param + header action button.
//
//   3. Alur create baru:
//      onCreateNew() dipanggil → parent (screen) handle via hook:
//        a. hook.workspace.addFile(folderId, 'untitled_indicator.py')
//        b. hook.openFile(newFile)
//      → editor terbuka dengan file kosong siap ditulis.
//
// Tidak ada perubahan di: IndicatorCard, IndicatorSearchBar,
// IndicatorPreviewSheet, semua internal small widgets.
//
// FIX OVERFLOW: Row count + New Indicator button di IndicatorListView
// overflow karena parent constraint ~128px. Fix: Flexible pada Text + button
// dikecilkan / ellipsis ditambah. Juga fix overflow bottom di card footer
// dengan Flexible pada author column.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../style/apps_colors_tradingview.dart';
import '../pages/tradingview_pages.dart';
import '../utils/python_syntax_highlighter.dart';
import '../hooks/tradingview_hook.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL: IndicatorMeta
// ─────────────────────────────────────────────────────────────────────────────

enum IndicatorCategory {
  momentum,
  trend,
  volatility,
  volume,
  custom,
}

enum IndicatorOwnership {
  shared,   // published admin, semua bisa lihat
  personal, // milik user sendiri
}

class IndicatorMeta {
  final String             id;
  final String             name;
  final String             description;
  final IndicatorCategory  category;
  final IndicatorOwnership ownership;
  final String             authorId;
  final String             authorLabel;
  final List<String>       tags;
  final String             previewCode;
  final ScriptFile         linkedFile;
  final DateTime           updatedAt;
  final bool               isFavorite;

  const IndicatorMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.ownership,
    required this.authorId,
    required this.authorLabel,
    required this.tags,
    required this.previewCode,
    required this.linkedFile,
    required this.updatedAt,
    this.isFavorite = false,
  });

  IndicatorMeta copyWith({bool? isFavorite}) => IndicatorMeta(
    id:           id,
    name:         name,
    description:  description,
    category:     category,
    ownership:    ownership,
    authorId:     authorId,
    authorLabel:  authorLabel,
    tags:         tags,
    previewCode:  previewCode,
    linkedFile:   linkedFile,
    updatedAt:    updatedAt,
    isFavorite:   isFavorite ?? this.isFavorite,
  );

  String get categoryLabel {
    switch (category) {
      case IndicatorCategory.momentum:   return 'Momentum';
      case IndicatorCategory.trend:      return 'Trend';
      case IndicatorCategory.volatility: return 'Volatility';
      case IndicatorCategory.volume:     return 'Volume';
      case IndicatorCategory.custom:     return 'Custom';
    }
  }

  Color categoryColor(EditorThemeState theme) {
    switch (category) {
      case IndicatorCategory.momentum:   return theme.syntax.keyword;
      case IndicatorCategory.trend:      return theme.syntax.builtinFunc;
      case IndicatorCategory.volatility: return theme.syntax.fstring;
      case IndicatorCategory.volume:     return theme.syntax.typehint;
      case IndicatorCategory.custom:     return theme.syntax.decorator;
    }
  }

  bool get isShared => ownership == IndicatorOwnership.shared;
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: IndicatorCard
// ─────────────────────────────────────────────────────────────────────────────

class IndicatorCard extends StatefulWidget {
  const IndicatorCard({
    super.key,
    required this.indicator,
    required this.permission,
    required this.theme,
    required this.onSelect,
    this.onDelete,
    this.onEdit,
    this.onToggleFavorite,
    this.isSelected = false,
  });

  final IndicatorMeta           indicator;
  final EditorPermission        permission;
  final EditorThemeState        theme;
  final VoidCallback            onSelect;
  final VoidCallback?           onDelete;
  final VoidCallback?           onEdit;
  final VoidCallback?           onToggleFavorite;
  final bool                    isSelected;

  @override
  State<IndicatorCard> createState() => _IndicatorCardState();
}

class _IndicatorCardState extends State<IndicatorCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  bool get _canEdit => widget.permission.canEdit(
      ownerId: widget.indicator.isShared
          ? EditorPermission.sharedOwnerId
          : widget.permission.userId);

  bool get _canDelete => widget.permission.canDelete(
      ownerId: widget.indicator.isShared
          ? EditorPermission.sharedOwnerId
          : widget.permission.userId);

  @override
  Widget build(BuildContext context) {
    final t      = widget.theme;
    final chrome = t.chrome;
    final syntax = t.syntax;
    final ind    = widget.indicator;
    final cat    = ind.categoryColor(t);

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown:   (_) => _pressCtrl.forward(),
        onTapUp:     (_) => _pressCtrl.reverse(),
        onTapCancel: ()  => _pressCtrl.reverse(),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onSelect();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showActionSheet(context);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? chrome.surface.withOpacity(0.95)
                : chrome.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected
                  ? cat.withOpacity(0.6)
                  : chrome.gutterBorder,
              width: widget.isSelected ? 1.5 : 1.0,
            ),
            boxShadow: widget.isSelected
                ? [BoxShadow(color: cat.withOpacity(0.12), blurRadius: 12)]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color:  cat,
                        shape:  BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: cat.withOpacity(0.5), blurRadius: 6),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        ind.name,
                        style: TextStyle(
                          color:      syntax.plain,
                          fontSize:   14,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.onToggleFavorite != null)
                      GestureDetector(
                        onTap: widget.onToggleFavorite,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            ind.isFavorite
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size:  18,
                            color: ind.isFavorite
                                ? const Color(0xFFFFD600)
                                : syntax.comment,
                          ),
                        ),
                      ),
                    if (widget.isSelected) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle_rounded, size: 18, color: cat),
                    ],
                  ],
                ),
              ),

              // ── Description ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Text(
                  ind.description,
                  maxLines:  2,
                  overflow:  TextOverflow.ellipsis,
                  style: TextStyle(
                    color:    syntax.comment,
                    fontSize: 12,
                    height:   1.45,
                  ),
                ),
              ),

              // ── Code snippet preview ──────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        chrome.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: chrome.gutterBorder.withOpacity(0.6)),
                ),
                child: SelectableText.rich(
                  PythonSyntaxHighlighter.buildTextSpan(
                    ind.previewCode,
                    theme: widget.theme,
                  ),
                  style: TextStyle(
                    fontFamily: widget.theme.typography.fontFamily,
                    fontSize:   11,
                    height:     1.5,
                  ),
                  maxLines: 4,
                ),
              ),

              // ── Footer ───────────────────────────────────────────────────
              // FIX: Wrap seluruh footer Row dengan overflow protection.
              // Tag chips dibungkus Flexible agar tidak paksa meluber,
              // author column di sisi kanan juga pakai Flexible + ellipsis.
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Row(
                  children: [
                    // FIX: Wrap chip area dengan Flexible supaya tidak overflow
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: _TagChip(
                              label:  ind.categoryLabel,
                              color:  cat,
                              chrome: chrome,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: _TagChip(
                              label: ind.isShared ? 'Shared' : 'Private',
                              color: ind.isShared
                                  ? syntax.builtinConst
                                  : syntax.decorator,
                              chrome: chrome,
                            ),
                          ),
                          if (ind.tags.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: _TagChip(
                                label:  ind.tags.first,
                                color:  syntax.comment,
                                chrome: chrome,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // FIX: author column pakai Flexible + ellipsis agar tidak overflow
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ind.authorLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:      syntax.comment.withOpacity(0.7),
                              fontSize:   10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _formatDate(ind.updatedAt),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:    syntax.comment.withOpacity(0.45),
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (_canEdit || _canDelete)
                _AdminActionBar(
                  canEdit:   _canEdit,
                  canDelete: _canDelete,
                  chrome:    chrome,
                  syntax:    syntax,
                  onEdit:    widget.onEdit,
                  onDelete:  widget.onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context:         context,
      backgroundColor: Colors.transparent,
      barrierColor:    Colors.black.withOpacity(0.5),
      builder:         (_) => _IndicatorActionSheet(
        indicator:  widget.indicator,
        permission: widget.permission,
        theme:      widget.theme,
        onSelect:   widget.onSelect,
        onEdit:     widget.onEdit,
        onDelete:   widget.onDelete,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7)  return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: IndicatorListView
//
//  FIX: tambah param onCreateNew + hook.
//  onCreateNew dipanggil ketika user tap "New Indicator" — parent screen
//  yang handle logic bikin file baru via hook dan navigate ke editor.
//
//  Juga tambah header action button "+" di count label row supaya user
//  bisa buat indikator baru meski list sudah ada isinya.
// ─────────────────────────────────────────────────────────────────────────────

class IndicatorListView extends StatefulWidget {
  const IndicatorListView({
    super.key,
    required this.indicators,
    required this.permission,
    required this.theme,
    required this.onSelect,
    // FIX: callback buat bikin indikator baru — wajib ada
    required this.onCreateNew,
    this.onDelete,
    this.onEdit,
    this.selectedId,
  });

  final List<IndicatorMeta>            indicators;
  final EditorPermission               permission;
  final EditorThemeState               theme;
  final void Function(IndicatorMeta)   onSelect;

  /// FIX: dipanggil ketika user mau buat indikator baru.
  /// Parent screen handle: buat ScriptFile kosong via hook, lalu openFile.
  final VoidCallback                   onCreateNew;

  final void Function(IndicatorMeta)?  onDelete;
  final void Function(IndicatorMeta)?  onEdit;
  final String?                        selectedId;

  @override
  State<IndicatorListView> createState() => _IndicatorListViewState();
}

class _IndicatorListViewState extends State<IndicatorListView> {
  String                _query          = '';
  IndicatorCategory?    _activeCategory;
  IndicatorOwnership?   _activeOwnership;
  final List<IndicatorMeta> _favorites  = [];

  List<IndicatorMeta> get _filtered {
    return widget.indicators.where((ind) {
      final matchQuery = _query.isEmpty ||
          ind.name.toLowerCase().contains(_query.toLowerCase()) ||
          ind.description.toLowerCase().contains(_query.toLowerCase()) ||
          ind.tags.any((t) => t.toLowerCase().contains(_query.toLowerCase()));
      final matchCat = _activeCategory == null || ind.category == _activeCategory;
      final matchOwn = _activeOwnership == null || ind.ownership == _activeOwnership;
      return matchQuery && matchCat && matchOwn;
    }).toList()
      ..sort((a, b) {
        final aFav = _favorites.any((f) => f.id == a.id) ? 0 : 1;
        final bFav = _favorites.any((f) => f.id == b.id) ? 0 : 1;
        if (aFav != bFav) return aFav.compareTo(bFav);
        if (a.isShared != b.isShared) return a.isShared ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
  }

  @override
  Widget build(BuildContext context) {
    final chrome = widget.theme.chrome;
    final syntax = widget.theme.syntax;

    // FIX: Column pakai mainAxisSize.max (mengisi semua ruang dari parent),
    // list area pakai Expanded — valid karena parent sudah bounded via Expanded
    // di _TradingViewShell. mainAxisSize.min adalah sumber overflow karena
    // Flutter tetap coba render children melebihi batas fixed height parent.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        // ── Search bar ────────────────────────────────────────────────────
        IndicatorSearchBar(
          theme:    widget.theme,
          onSearch: (q) => setState(() => _query = q),
        ),

        // ── Filter chips ──────────────────────────────────────────────────
        _FilterChipRow(
          theme:              widget.theme,
          activeCategory:     _activeCategory,
          activeOwnership:    _activeOwnership,
          onCategoryChanged:  (c) => setState(() => _activeCategory  = c),
          onOwnershipChanged: (o) => setState(() => _activeOwnership = o),
        ),

        // ── Count + New button ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  '${_filtered.length} indicator${_filtered.length == 1 ? '' : 's'}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: syntax.comment.withOpacity(0.6), fontSize: 11,
                  ),
                ),
              ),
              if (widget.permission.canCreate) ...[
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onCreateNew();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color:        chrome.cursorColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: chrome.cursorColor.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 13, color: chrome.cursorColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'New',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:      chrome.cursorColor,
                                fontSize:   11,
                                fontWeight: FontWeight.w700,
                              ),
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
        ),

        // ── List / empty state — Expanded mengisi sisa ruang ─────────────
        Expanded(
          child: _filtered.isEmpty
              ? IndicatorEmptyState(
                  theme:       widget.theme,
                  query:       _query,
                  onCreateNew: widget.permission.canCreate
                      ? widget.onCreateNew
                      : null,
                )
              : ListView.builder(
                  itemCount: _filtered.length,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemBuilder: (_, i) {
                    final ind   = _filtered[i];
                    final isFav = _favorites.any((f) => f.id == ind.id);
                    return IndicatorCard(
                      indicator:  ind.copyWith(isFavorite: isFav),
                      permission: widget.permission,
                      theme:      widget.theme,
                      isSelected: ind.id == widget.selectedId,
                      onSelect:   () => widget.onSelect(ind),
                      onDelete:   widget.onDelete != null
                          ? () => widget.onDelete!(ind)
                          : null,
                      onEdit:     widget.onEdit != null
                          ? () => widget.onEdit!(ind)
                          : null,
                      onToggleFavorite: () => setState(() {
                        if (isFav) {
                          _favorites.removeWhere((f) => f.id == ind.id);
                        } else {
                          _favorites.add(ind);
                        }
                      }),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: IndicatorSearchBar
// ─────────────────────────────────────────────────────────────────────────────

class IndicatorSearchBar extends StatefulWidget {
  const IndicatorSearchBar({
    super.key,
    required this.theme,
    required this.onSearch,
  });

  final EditorThemeState      theme;
  final void Function(String) onSearch;

  @override
  State<IndicatorSearchBar> createState() => _IndicatorSearchBarState();
}

class _IndicatorSearchBarState extends State<IndicatorSearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = widget.theme.chrome;
    final syntax = widget.theme.syntax;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: TextField(
        controller: _ctrl,
        onChanged:  widget.onSearch,
        style: TextStyle(
          color:      syntax.plain,
          fontSize:   13,
          fontFamily: widget.theme.typography.fontFamily,
        ),
        decoration: InputDecoration(
          hintText:  'Search indicators…',
          hintStyle: TextStyle(color: syntax.comment.withOpacity(0.5), fontSize: 13),
          filled:    true,
          fillColor: chrome.background,
          isDense:   true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          prefixIcon: Icon(Icons.search_rounded, color: syntax.comment, size: 18),
          suffixIcon: _ctrl.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    widget.onSearch('');
                    setState(() {});
                  },
                  child: Icon(Icons.close_rounded, color: syntax.comment, size: 16),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:   BorderSide(color: chrome.gutterBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:   BorderSide(color: chrome.gutterBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:   BorderSide(color: chrome.cursorColor.withOpacity(0.6)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: IndicatorPreviewSheet
// ─────────────────────────────────────────────────────────────────────────────

class IndicatorPreviewSheet extends StatelessWidget {
  const IndicatorPreviewSheet({
    super.key,
    required this.indicator,
    required this.permission,
    required this.theme,
    required this.hook,
    this.onUse,
  });

  final IndicatorMeta           indicator;
  final EditorPermission        permission;
  final EditorThemeState        theme;
  final IsolatedTradingViewHook hook;
  final VoidCallback?           onUse;

  static void show(
    BuildContext context, {
    required IndicatorMeta           indicator,
    required EditorPermission        permission,
    required EditorThemeState        theme,
    required IsolatedTradingViewHook hook,
    VoidCallback?                    onUse,
  }) {
    showModalBottomSheet<void>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      barrierColor:       Colors.black.withOpacity(0.6),
      builder: (_) => IndicatorPreviewSheet(
        indicator:  indicator,
        permission: permission,
        theme:      theme,
        hook:       hook,
        onUse:      onUse,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chrome     = theme.chrome;
    final syntax     = theme.syntax;
    final cat        = indicator.categoryColor(theme);
    final isReadOnly = indicator.isShared && !permission.isAdmin;
    final screenH    = MediaQuery.of(context).size.height;

    return Container(
      height:     screenH * 0.88,
      decoration: BoxDecoration(
        color:        chrome.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: chrome.gutterBorder)),
      ),
      child: Column(
        children: [

          // ── Handle ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color:        syntax.comment.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color:  cat,
                    shape:  BoxShape.circle,
                    boxShadow: [BoxShadow(color: cat.withOpacity(0.5), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    indicator.name,
                    style: TextStyle(
                      color: syntax.plain, fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isReadOnly) _ReadOnlyTag(chrome: chrome),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded, color: syntax.comment, size: 20),
                ),
              ],
            ),
          ),

          // ── Meta row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: [
                _TagChip(label: indicator.categoryLabel, color: cat, chrome: chrome),
                const SizedBox(width: 6),
                _TagChip(
                  label: indicator.isShared ? 'Shared' : 'Private',
                  color: indicator.isShared ? syntax.builtinConst : syntax.decorator,
                  chrome: chrome,
                ),
                ...indicator.tags.take(2).map((tag) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _TagChip(label: tag, color: syntax.comment, chrome: chrome),
                )),
                const Spacer(),
                Text(
                  'by ${indicator.authorLabel}',
                  style: TextStyle(color: syntax.comment.withOpacity(0.6), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // ── Description ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              indicator.description,
              style: TextStyle(color: syntax.plain.withOpacity(0.75), fontSize: 13, height: 1.55),
            ),
          ),

          // ── Code divider label ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  'SOURCE CODE',
                  style: TextStyle(
                    color: syntax.comment.withOpacity(0.55), fontSize: 9.5,
                    fontWeight: FontWeight.w700, letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: indicator.linkedFile.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied to clipboard',
                            style: TextStyle(color: syntax.plain)),
                        backgroundColor: chrome.surface,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, color: syntax.comment, size: 14),
                      const SizedBox(width: 4),
                      Text('Copy', style: TextStyle(color: syntax.comment, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Full code view ────────────────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color:        chrome.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: chrome.gutterBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: PythonCodeView(
                  source:          indicator.linkedFile.content,
                  theme:           theme,
                  showLineNumbers: true,
                ),
              ),
            ),
          ),

          _PreviewCTA(
            indicator:  indicator,
            permission: permission,
            theme:      theme,
            hook:       hook,
            onUse:      onUse,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET: IndicatorEmptyState
//
//  FIX: tambah param onCreateNew (nullable).
//  "New Indicator" button sekarang wrapped Material+InkWell — bisa dipencet.
//  Hanya tampil kalau onCreateNew != null (artinya user punya permission canCreate).
// ─────────────────────────────────────────────────────────────────────────────

class IndicatorEmptyState extends StatelessWidget {
  const IndicatorEmptyState({
    super.key,
    required this.theme,
    this.query = '',
    // FIX: nullable — null = tidak punya permission, tidak tampilkan tombol
    this.onCreateNew,
  });

  final EditorThemeState theme;
  final String           query;

  /// FIX: callback yang sebenarnya. Kalau null, tombol tidak ditampilkan.
  final VoidCallback?    onCreateNew;

  @override
  Widget build(BuildContext context) {
    final syntax = theme.syntax;
    final chrome = theme.chrome;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              query.isEmpty
                  ? Icons.code_off_rounded
                  : Icons.search_off_rounded,
              size:  48,
              color: syntax.comment.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              query.isEmpty ? 'No Indicators Yet' : 'No Results',
              style: TextStyle(
                color:      syntax.plain.withOpacity(0.7),
                fontSize:   16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              query.isEmpty
                  ? 'Create your first indicator\nor wait for admin to publish shared ones.'
                  : 'No indicator matched "$query".\nTry a different keyword.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:    syntax.comment.withOpacity(0.55),
                fontSize: 13,
                height:   1.55,
              ),
            ),

            // FIX: tombol hanya muncul kalau query kosong DAN user punya permission
            if (query.isEmpty && onCreateNew != null) ...[
              const SizedBox(height: 24),

              // FIX: Material + InkWell menggantikan GestureDetector
              // supaya touch event tidak terblok oleh widget ancestor lain.
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onCreateNew!();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color:        chrome.cursorColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: chrome.cursorColor.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: chrome.cursorColor),
                        const SizedBox(width: 6),
                        Text(
                          'New Indicator',
                          style: TextStyle(
                            color:      chrome.cursorColor,
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Internal small widgets (tidak ada perubahan)
// ─────────────────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.color,
    required this.chrome,
  });
  final String             label;
  final Color              color;
  final EditorChromeColors chrome;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(5),
      border:       Border.all(color: color.withOpacity(0.30)),
    ),
    child: Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color:         color,
        fontSize:      10,
        fontWeight:    FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
  );
}

class _ReadOnlyTag extends StatelessWidget {
  final EditorChromeColors chrome;
  const _ReadOnlyTag({required this.chrome});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color:        chrome.consoleTextInfo.withOpacity(0.10),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: chrome.consoleTextInfo.withOpacity(0.3)),
    ),
    child: Text(
      'READ ONLY',
      style: TextStyle(
        color:         chrome.consoleTextInfo,
        fontSize:      9,
        fontWeight:    FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _AdminActionBar extends StatelessWidget {
  const _AdminActionBar({
    required this.canEdit,
    required this.canDelete,
    required this.chrome,
    required this.syntax,
    required this.onEdit,
    required this.onDelete,
  });
  final bool               canEdit, canDelete;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final VoidCallback?      onEdit, onDelete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: chrome.gutterBorder.withOpacity(0.5))),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        // FIX: Flexible agar button tidak paksa overflow saat ruang sempit
        if (canEdit && onEdit != null)
          Flexible(
            child: _ActionBtn(
              label: 'Edit',
              icon:  Icons.edit_rounded,
              color: syntax.builtinFunc,
              onTap: onEdit!,
            ),
          ),
        if (canEdit && canDelete) const SizedBox(width: 8),
        if (canDelete && onDelete != null)
          Flexible(
            child: _ActionBtn(
              label: 'Delete',
              icon:  Icons.delete_outline_rounded,
              color: chrome.consoleTextError,
              onTap: onDelete!,
            ),
          ),
      ],
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      // FIX: Row pakai min agar tidak paksa melebar, Text pakai ellipsis
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({
    required this.theme,
    required this.activeCategory,
    required this.activeOwnership,
    required this.onCategoryChanged,
    required this.onOwnershipChanged,
  });

  final EditorThemeState            theme;
  final IndicatorCategory?          activeCategory;
  final IndicatorOwnership?         activeOwnership;
  final void Function(IndicatorCategory?)  onCategoryChanged;
  final void Function(IndicatorOwnership?) onOwnershipChanged;

  @override
  Widget build(BuildContext context) {
    final chrome = theme.chrome;
    final syntax = theme.syntax;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _FilterPill(
            label:    'All',
            isActive: activeCategory == null && activeOwnership == null,
            color:    syntax.plain,
            chrome:   chrome,
            onTap: () {
              onCategoryChanged(null);
              onOwnershipChanged(null);
            },
          ),
          const SizedBox(width: 6),
          _FilterPill(
            label:    'Shared',
            isActive: activeOwnership == IndicatorOwnership.shared,
            color:    syntax.builtinConst,
            chrome:   chrome,
            onTap: () => onOwnershipChanged(
              activeOwnership == IndicatorOwnership.shared
                  ? null
                  : IndicatorOwnership.shared,
            ),
          ),
          const SizedBox(width: 6),
          _FilterPill(
            label:    'Private',
            isActive: activeOwnership == IndicatorOwnership.personal,
            color:    syntax.decorator,
            chrome:   chrome,
            onTap: () => onOwnershipChanged(
              activeOwnership == IndicatorOwnership.personal
                  ? null
                  : IndicatorOwnership.personal,
            ),
          ),
          const SizedBox(width: 6),
          ...IndicatorCategory.values.map((cat) {
            final catColor = IndicatorMeta(
              id: '', name: '', description: '',
              category: cat, ownership: IndicatorOwnership.shared,
              authorId: '', authorLabel: '', tags: [], previewCode: '',
              linkedFile: ScriptFile(
                id: '', name: '', content: '',
                createdAt: DateTime.now(), updatedAt: DateTime.now(),
              ),
              updatedAt: DateTime.now(),
            ).categoryColor(theme);

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterPill(
                label:    _catLabel(cat),
                isActive: activeCategory == cat,
                color:    catColor,
                chrome:   chrome,
                onTap: () => onCategoryChanged(
                  activeCategory == cat ? null : cat,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _catLabel(IndicatorCategory cat) {
    switch (cat) {
      case IndicatorCategory.momentum:   return 'Momentum';
      case IndicatorCategory.trend:      return 'Trend';
      case IndicatorCategory.volatility: return 'Volatility';
      case IndicatorCategory.volume:     return 'Volume';
      case IndicatorCategory.custom:     return 'Custom';
    }
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isActive,
    required this.color,
    required this.chrome,
    required this.onTap,
  });
  final String             label;
  final bool               isActive;
  final Color              color;
  final EditorChromeColors chrome;
  final VoidCallback       onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.15) : chrome.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? color.withOpacity(0.6) : chrome.gutterBorder,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      isActive ? color : color.withOpacity(0.55),
          fontSize:   11,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}

class _PreviewCTA extends StatelessWidget {
  const _PreviewCTA({
    required this.indicator,
    required this.permission,
    required this.theme,
    required this.hook,
    this.onUse,
  });

  final IndicatorMeta           indicator;
  final EditorPermission        permission;
  final EditorThemeState        theme;
  final IsolatedTradingViewHook hook;
  final VoidCallback?           onUse;

  @override
  Widget build(BuildContext context) {
    final chrome = theme.chrome;
    final syntax = theme.syntax;
    final cat    = indicator.categoryColor(theme);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color:  chrome.surface,
        border: Border(top: BorderSide(color: chrome.gutterBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  indicator.name,
                  style: TextStyle(
                    color: syntax.plain, fontSize: 13, fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  indicator.categoryLabel,
                  style: TextStyle(color: cat, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              hook.openFile(indicator.linkedFile);
              Navigator.pop(context);
              if (onUse != null) onUse!();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cat, cat.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: cat.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size:  16,
                    color: cat.computeLuminance() > 0.4 ? Colors.black87 : Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Use This',
                    style: TextStyle(
                      color:      cat.computeLuminance() > 0.4 ? Colors.black87 : Colors.white,
                      fontSize:   13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndicatorActionSheet extends StatelessWidget {
  const _IndicatorActionSheet({
    required this.indicator,
    required this.permission,
    required this.theme,
    required this.onSelect,
    this.onEdit,
    this.onDelete,
  });

  final IndicatorMeta    indicator;
  final EditorPermission permission;
  final EditorThemeState theme;
  final VoidCallback     onSelect;
  final VoidCallback?    onEdit;
  final VoidCallback?    onDelete;

  bool get _canEdit => permission.canEdit(
      ownerId: indicator.isShared
          ? EditorPermission.sharedOwnerId
          : permission.userId);

  bool get _canDelete => permission.canDelete(
      ownerId: indicator.isShared
          ? EditorPermission.sharedOwnerId
          : permission.userId);

  @override
  Widget build(BuildContext context) {
    final chrome = theme.chrome;
    final syntax = theme.syntax;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        chrome.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: chrome.gutterBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              indicator.name,
              style: TextStyle(
                color: syntax.plain, fontSize: 15, fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          _SheetAction(
            icon:   Icons.open_in_new_rounded,
            label:  'Open in Editor',
            color:  chrome.cursorColor,
            chrome: chrome,
            syntax: syntax,
            onTap: () { Navigator.pop(context); onSelect(); },
          ),
          if (_canEdit && onEdit != null)
            _SheetAction(
              icon:   Icons.edit_rounded,
              label:  'Edit Indicator',
              color:  syntax.builtinFunc,
              chrome: chrome,
              syntax: syntax,
              onTap: () { Navigator.pop(context); onEdit!(); },
            ),
          if (_canDelete && onDelete != null)
            _SheetAction(
              icon:   Icons.delete_outline_rounded,
              label:  'Delete Indicator',
              color:  chrome.consoleTextError,
              chrome: chrome,
              syntax: syntax,
              onTap: () { Navigator.pop(context); onDelete!(); },
            ),
          _SheetAction(
            icon:   Icons.close_rounded,
            label:  'Cancel',
            color:  syntax.comment,
            chrome: chrome,
            syntax: syntax,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.chrome,
    required this.syntax,
    required this.onTap,
  });
  final IconData           icon;
  final String             label;
  final Color              color;
  final EditorChromeColors chrome;
  final EditorSyntaxColors syntax;
  final VoidCallback       onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: chrome.gutterBorder.withOpacity(0.4))),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );
}