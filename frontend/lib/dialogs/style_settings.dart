// =============================================================================
// style_settings_panel.dart
// Path: frontend/lib/dialogs/style_settings_panel.dart
//
// Full custom style panel — preset, color picker, opacity slider,
// background mode (solid/gradient/image+url), candle style, grid style.
//
// Dependencies:
//   color_picker.dart   → FullColorPicker  (RGB/HSV picker)
//   chart_style.dart    → ChartStyleState, ChartStylePreset, etc.
//   candle_normal.dart  → CandleBodyStyle
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../candle/candle_normal.dart';
import 'chart_style.dart';
import 'color_picker.dart'; // ← NEW

class StyleSettingsPanel {
  static void show(
    BuildContext context, {
    required ChartStyleState currentStyle,
    required void Function(ChartStyleState) onChanged,
  }) {
    showModalBottomSheet<void>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      barrierColor:       Colors.black.withOpacity(0.6),
      builder: (_) => _StylePanelSheet(initial: currentStyle, onChanged: onChanged),
    );
  }
}

// ===========================================================================
// Sheet widget
// ===========================================================================

class _StylePanelSheet extends StatefulWidget {
  final ChartStyleState                initial;
  final void Function(ChartStyleState) onChanged;
  const _StylePanelSheet({required this.initial, required this.onChanged});

  @override
  State<_StylePanelSheet> createState() => _StylePanelSheetState();
}

class _StylePanelSheetState extends State<_StylePanelSheet>
    with SingleTickerProviderStateMixin {

  late ChartStyleState _style;
  late TabController   _tab;

  static const _bg     = Color(0xFF0E1117);
  static const _border = Color(0xFF1E2333);
  static const _muted  = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _style = widget.initial;
    _tab   = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _update(ChartStyleState next) {
    setState(() => _style = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height:     screenH * 0.82,
      decoration: const BoxDecoration(
        color:        _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border:       Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _PresetsTab(style: _style, onUpdate: _update),
                _CandleTab(style: _style, onUpdate: _update),
                _BackgroundTab(style: _style, onUpdate: _update),
                _GridTab(style: _style, onUpdate: _update),
              ],
            ),
          ),
          _buildPreviewBar(),
        ],
      ),
    );
  }

  Widget _buildHandle() => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Container(
      width: 36, height: 4,
      decoration: BoxDecoration(
        color: _muted.withOpacity(0.4), borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
    child: Row(
      children: [
        const Text('CHART STYLE', style: TextStyle(
          color: Color(0xFFE8EAF0), fontSize: 13,
          fontWeight: FontWeight.w700, letterSpacing: 1.8,
        )),
        const Spacer(),
        TextButton(
          onPressed: () => _update(const ChartStyleState()),
          child: const Text('Reset', style: TextStyle(color: _muted, fontSize: 12)),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: _muted, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );

  Widget _buildTabBar() => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    decoration: BoxDecoration(
      color: _border, borderRadius: BorderRadius.circular(10),
    ),
    child: TabBar(
      controller:           _tab,
      indicator:            BoxDecoration(
        color: const Color(0xFF1E2740), borderRadius: BorderRadius.circular(8),
      ),
      indicatorSize:        TabBarIndicatorSize.tab,
      dividerColor:         Colors.transparent,
      labelColor:           const Color(0xFFE8EAF0),
      unselectedLabelColor: _muted,
      labelStyle:           const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      padding:              const EdgeInsets.all(3),
      tabs: const [
        Tab(text: 'Preset'), Tab(text: 'Candle'),
        Tab(text: 'Background'), Tab(text: 'Grid'),
      ],
    ),
  );

  Widget _buildPreviewBar() => Container(
    height:  64,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: _border)),
    ),
    child: Row(
      children: [
        _MiniCandlePreview(style: _style),
        const SizedBox(width: 16),
        Expanded(child: Text('Preview', style: TextStyle(color: _muted, fontSize: 11))),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _style.bullishColor, borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Apply', style: TextStyle(
              color: Colors.black, fontSize: 13, fontWeight: FontWeight.w700,
            )),
          ),
        ),
      ],
    ),
  );
}

// ===========================================================================
// Tab 1 — Preset
// ===========================================================================

class _PresetsTab extends StatelessWidget {
  final ChartStyleState               style;
  final void Function(ChartStyleState) onUpdate;
  const _PresetsTab({required this.style, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final presets = ChartStylePreset.all();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('THEME PRESETS'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics:    const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 8,
            crossAxisSpacing: 8, childAspectRatio: 1.3,
          ),
          itemCount: presets.length,
          itemBuilder: (_, i) {
            final p        = presets[i];
            final isActive = _matchesPreset(p.state);
            return GestureDetector(
              onTap: () => onUpdate(p.state),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color:        p.state.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? p.state.bullishColor : const Color(0xFF1E2333),
                    width: isActive ? 2.0 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [_dot(p.state.bullishColor), const SizedBox(width: 4), _dot(p.state.bearishColor)],
                    ),
                    const SizedBox(height: 6),
                    Text(p.name, style: TextStyle(
                      color:      p.state.textColor,
                      fontSize:   11,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    )),
                    if (isActive)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(Icons.check_circle_rounded, size: 12, color: p.state.bullishColor),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  bool _matchesPreset(ChartStyleState p) =>
      p.bullishColor == style.bullishColor &&
      p.bearishColor == style.bearishColor &&
      p.backgroundColor == style.backgroundColor;

  Widget _dot(Color c) => Container(
    width: 10, height: 10,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

// ===========================================================================
// Tab 2 — Candle
// ===========================================================================

class _CandleTab extends StatelessWidget {
  final ChartStyleState               style;
  final void Function(ChartStyleState) onUpdate;
  const _CandleTab({required this.style, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('BULLISH COLOR'),
        const SizedBox(height: 10),
        _FullColorRow(
          current:  style.bullishColor,
          onPicked: (c) => onUpdate(style.copyWith(bullishColor: c)),
        ),

        const SizedBox(height: 20),
        _SectionLabel('BEARISH COLOR'),
        const SizedBox(height: 10),
        _FullColorRow(
          current:  style.bearishColor,
          onPicked: (c) => onUpdate(style.copyWith(bearishColor: c)),
        ),

        const SizedBox(height: 20),
        _SectionLabel('CANDLE OPACITY'),
        _OpacitySlider(
          value:     style.candleOpacity,
          color:     style.bullishColor,
          onChanged: (v) => onUpdate(style.copyWith(candleOpacity: v)),
        ),

        const SizedBox(height: 20),
        _SectionLabel('BODY STYLE'),
        const SizedBox(height: 10),
        _SegmentedRow<CandleBodyStyle>(
          options: const [
            _SegmentOption(label: 'Filled', value: CandleBodyStyle.filled),
            _SegmentOption(label: 'Hollow', value: CandleBodyStyle.hollow),
          ],
          selected:    style.bodyStyle,
          accentColor: style.bullishColor,
          onSelected:  (v) => onUpdate(style.copyWith(bodyStyle: v)),
        ),

        const SizedBox(height: 20),
        _SectionLabel('WICK'),
        _SwitchRow(
          label:     'Show Wick',
          value:     style.showWick,
          color:     style.bullishColor,
          onChanged: (v) => onUpdate(style.copyWith(showWick: v)),
        ),
        if (style.showWick) ...[
          const SizedBox(height: 8),
          _OpacitySlider(
            label:     'Wick Opacity',
            value:     style.wickOpacity,
            color:     style.bullishColor,
            onChanged: (v) => onUpdate(style.copyWith(wickOpacity: v)),
          ),
        ],
      ],
    );
  }
}

// ===========================================================================
// Tab 3 — Background  ← UPDATED: full color picker + image/URL upload
// ===========================================================================

class _BackgroundTab extends StatefulWidget {
  final ChartStyleState               style;
  final void Function(ChartStyleState) onUpdate;
  const _BackgroundTab({required this.style, required this.onUpdate});

  @override
  State<_BackgroundTab> createState() => _BackgroundTabState();
}

class _BackgroundTabState extends State<_BackgroundTab> {
  final _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = widget.style.backgroundImagePath ?? '';
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Background Mode ────────────────────────────────────────────────
        _SectionLabel('BACKGROUND MODE'),
        const SizedBox(height: 10),
        _SegmentedRow<ChartBackgroundMode>(
          options: const [
            _SegmentOption(label: 'Solid',    value: ChartBackgroundMode.solidColor),
            _SegmentOption(label: 'Gradient', value: ChartBackgroundMode.gradient),
            _SegmentOption(label: 'Image',    value: ChartBackgroundMode.image),
          ],
          selected:    style.backgroundMode,
          accentColor: style.bullishColor,
          onSelected: (v) => widget.onUpdate(style.copyWith(backgroundMode: v)),
        ),
        const SizedBox(height: 20),

        // ── Solid Color ────────────────────────────────────────────────────
        if (style.backgroundMode == ChartBackgroundMode.solidColor) ...[
          _SectionLabel('BACKGROUND COLOR'),
          const SizedBox(height: 10),
          _FullColorRow(
            current:  style.backgroundColor,
            onPicked: (c) => widget.onUpdate(style.copyWith(backgroundColor: c)),
          ),
          const SizedBox(height: 20),
        ],

        // ── Gradient ───────────────────────────────────────────────────────
        if (style.backgroundMode == ChartBackgroundMode.gradient) ...[
          _SectionLabel('GRADIENT START'),
          const SizedBox(height: 10),
          _FullColorRow(
            current:  style.backgroundColor,
            onPicked: (c) => widget.onUpdate(style.copyWith(backgroundColor: c)),
          ),
          const SizedBox(height: 16),
          _SectionLabel('GRADIENT END'),
          const SizedBox(height: 10),
          _FullColorRow(
            current:  style.backgroundGradientEnd,
            onPicked: (c) => widget.onUpdate(style.copyWith(backgroundGradientEnd: c)),
          ),
          const SizedBox(height: 10),
          // Live gradient preview
          Container(
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [style.backgroundColor, style.backgroundGradientEnd],
                begin:  Alignment.centerLeft,
                end:    Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E2333)),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Image / URL ────────────────────────────────────────────────────
        if (style.backgroundMode == ChartBackgroundMode.image) ...[
          _SectionLabel('BACKGROUND IMAGE'),
          const SizedBox(height: 10),

          // Preview box
          if (style.backgroundImagePath != null &&
              style.backgroundImagePath!.isNotEmpty)
            _ImagePreview(path: style.backgroundImagePath!),

          const SizedBox(height: 10),

          // URL input
          _SectionLabel('IMAGE URL (from internet)'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  style:      const TextStyle(color: Color(0xFFE8EAF0), fontSize: 12),
                  decoration: InputDecoration(
                    hintText:  'https://example.com/bg.png',
                    hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                    filled:    true,
                    fillColor: const Color(0xFF161B27),
                    isDense:   true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    prefixIcon: const Icon(Icons.link_rounded,
                        color: Color(0xFF6B7280), size: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:   const BorderSide(color: Color(0xFF1E2333)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:   const BorderSide(color: Color(0xFF1E2333)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: style.bullishColor),
                    ),
                  ),
                  onSubmitted: (v) => widget.onUpdate(
                    style.copyWith(backgroundImagePath: v.trim()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final url = _urlCtrl.text.trim();
                  if (url.isNotEmpty) {
                    widget.onUpdate(style.copyWith(backgroundImagePath: url));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:        style.bullishColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: style.bullishColor),
                  ),
                  child: Icon(Icons.check_rounded,
                      color: style.bullishColor, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Paste URL gambar dari internet, atau path asset lokal',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 10),
          ),

          const SizedBox(height: 16),

          // Upload from device (asset path helper)
          _SectionLabel('LOCAL ASSET PATH'),
          const SizedBox(height: 6),
          _AssetPathInput(
            current:    style.backgroundImagePath,
            accentColor: style.bullishColor,
            onPicked:   (path) => widget.onUpdate(
              style.copyWith(backgroundImagePath: path),
            ),
          ),

          const SizedBox(height: 10),

          // Clear image button
          if (style.backgroundImagePath != null &&
              style.backgroundImagePath!.isNotEmpty)
            GestureDetector(
              onTap: () {
                _urlCtrl.clear();
                widget.onUpdate(style.copyWith(backgroundImagePath: null));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:        const Color(0xFF1E2333),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3A4055)),
                ),
                child: const Center(
                  child: Text('Clear Image',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                ),
              ),
            ),

          const SizedBox(height: 20),
        ],

        // ── Background Opacity (all modes) ─────────────────────────────────
        _SectionLabel('BACKGROUND OPACITY'),
        _OpacitySlider(
          value:     style.backgroundOpacity,
          color:     style.bullishColor,
          onChanged: (v) => widget.onUpdate(style.copyWith(backgroundOpacity: v)),
        ),

        const SizedBox(height: 20),

        // ── Text color ─────────────────────────────────────────────────────
        _SectionLabel('TEXT COLOR'),
        const SizedBox(height: 10),
        _FullColorRow(
          current:  style.textColor,
          onPicked: (c) => widget.onUpdate(style.copyWith(textColor: c)),
        ),
      ],
    );
  }
}

// ── Image preview widget ──────────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  final String path;
  const _ImagePreview({required this.path});

  bool get _isUrl => path.startsWith('http://') || path.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color:        const Color(0xFF161B27),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E2333)),
        ),
        child: _isUrl
            ? Image.network(
                path,
                fit:         BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded,
                      color: Color(0xFF6B7280), size: 28),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF00D09C),
                      ),
                    ),
                  );
                },
              )
            : Image.asset(
                path,
                fit:         BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.image_not_supported_rounded,
                      color: Color(0xFF6B7280), size: 28),
                ),
              ),
      ),
    );
  }
}

// ── Asset path input ──────────────────────────────────────────────────────────

class _AssetPathInput extends StatefulWidget {
  final String?               current;
  final Color                 accentColor;
  final void Function(String) onPicked;
  const _AssetPathInput({
    required this.current,
    required this.accentColor,
    required this.onPicked,
  });

  @override
  State<_AssetPathInput> createState() => _AssetPathInputState();
}

class _AssetPathInputState extends State<_AssetPathInput> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final path = widget.current ?? '';
    final isUrl = path.startsWith('http');
    _ctrl = TextEditingController(text: isUrl ? '' : path);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            style:      const TextStyle(color: Color(0xFFE8EAF0), fontSize: 12),
            decoration: InputDecoration(
              hintText:  'assets/images/background.png',
              hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
              filled:    true,
              fillColor: const Color(0xFF161B27),
              isDense:   true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: const Icon(Icons.folder_open_rounded,
                  color: Color(0xFF6B7280), size: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   const BorderSide(color: Color(0xFF1E2333)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   const BorderSide(color: Color(0xFF1E2333)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   BorderSide(color: widget.accentColor),
              ),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) widget.onPicked(v.trim());
            },
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            final p = _ctrl.text.trim();
            if (p.isNotEmpty) widget.onPicked(p);
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        widget.accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.accentColor),
            ),
            child: Icon(Icons.check_rounded, color: widget.accentColor, size: 18),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Tab 4 — Grid
// ===========================================================================

class _GridTab extends StatelessWidget {
  final ChartStyleState               style;
  final void Function(ChartStyleState) onUpdate;
  const _GridTab({required this.style, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('GRID STYLE'),
        const SizedBox(height: 10),
        _SegmentedRow<GridStyle>(
          options: const [
            _SegmentOption(label: 'Lines', value: GridStyle.lines),
            _SegmentOption(label: 'Dots',  value: GridStyle.dots),
            _SegmentOption(label: 'None',  value: GridStyle.none),
          ],
          selected:    style.gridStyle,
          accentColor: style.bullishColor,
          onSelected: (v) => onUpdate(style.copyWith(gridStyle: v)),
        ),

        if (style.gridStyle != GridStyle.none) ...[
          const SizedBox(height: 20),
          _SectionLabel('GRID COLOR'),
          const SizedBox(height: 10),
          _FullColorRow(
            current:  style.gridColor,
            onPicked: (c) => onUpdate(style.copyWith(gridColor: c)),
          ),
          const SizedBox(height: 20),
          _SectionLabel('GRID OPACITY'),
          _OpacitySlider(
            value:     style.gridOpacity,
            color:     style.bullishColor,
            onChanged: (v) => onUpdate(style.copyWith(gridOpacity: v)),
          ),
        ],

        const SizedBox(height: 20),
        _SectionLabel('CROSSHAIR COLOR'),
        const SizedBox(height: 10),
        _FullColorRow(
          current:  style.crosshairColor,
          onPicked: (c) => onUpdate(style.copyWith(crosshairColor: c)),
        ),
      ],
    );
  }
}

// ===========================================================================
// Shared UI components
// ===========================================================================

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
    color: Color(0xFF6B7280), fontSize: 9.5,
    fontWeight: FontWeight.w700, letterSpacing: 1.4,
  ));
}

// ── FullColorRow — swatch strip + open full picker ────────────────────────────

class _FullColorRow extends StatelessWidget {
  final Color               current;
  final void Function(Color) onPicked;

  const _FullColorRow({required this.current, required this.onPicked});

  // Quick swatch presets (rainbow range biar langsung pilih cepet)
  static const _quickPresets = [
    Color(0xFF00D09C), Color(0xFFFF4D6D), Color(0xFFFF0000),
    Color(0xFFFF6600), Color(0xFFFFCC00), Color(0xFF00FF00),
    Color(0xFF00CCFF), Color(0xFF0000FF), Color(0xFF9900FF),
    Color(0xFFFF00FF), Color(0xFFFFFFFF), Color(0xFF000000),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Quick swatch horizontal scroll
        Expanded(
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _quickPresets.map((c) {
                final isActive = current.value == c.value;
                return GestureDetector(
                  onTap: () => onPicked(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 30, height: 30,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? Colors.white : Colors.white.withOpacity(0.12),
                        width: isActive ? 2.5 : 1.0,
                      ),
                      boxShadow: isActive
                          ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)]
                          : null,
                    ),
                    child: isActive
                        ? Icon(Icons.check_rounded, size: 14,
                            color: c.computeLuminance() > 0.4
                                ? Colors.black : Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Open full picker button
        GestureDetector(
          onTap: () async {
            final picked = await FullColorPicker.show(
              context, initial: current,
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color:        current,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(color: current.withOpacity(0.4), blurRadius: 6),
              ],
            ),
            child: Icon(
              Icons.colorize_rounded, size: 16,
              color: current.computeLuminance() > 0.4 ? Colors.black : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Opacity Slider ────────────────────────────────────────────────────────────

class _OpacitySlider extends StatelessWidget {
  final String              label;
  final double              value;
  final Color               color;
  final void Function(double) onChanged;

  const _OpacitySlider({
    this.label = 'Opacity',
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 70,
        child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
      ),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor:   color,
            inactiveTrackColor: color.withOpacity(0.15),
            thumbColor:         color,
            overlayColor:       color.withOpacity(0.12),
            trackHeight:        3.0,
            thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
        ),
      ),
      SizedBox(
        width: 36,
        child: Text('${(value * 100).round()}%',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            textAlign: TextAlign.right),
      ),
    ],
  );
}

// ── Switch Row ────────────────────────────────────────────────────────────────

class _SwitchRow extends StatelessWidget {
  final String             label;
  final bool               value;
  final Color              color;
  final void Function(bool) onChanged;

  const _SwitchRow({
    required this.label, required this.value,
    required this.color,  required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label,
          style: const TextStyle(color: Color(0xFFB2B5BE), fontSize: 13))),
      Switch(
        value:              value,
        onChanged:          onChanged,
        activeColor:        color,
        inactiveThumbColor: const Color(0xFF6B7280),
        inactiveTrackColor: const Color(0xFF1E2333),
      ),
    ],
  );
}

// ── Segmented Row ─────────────────────────────────────────────────────────────

class _SegmentOption<T> {
  final String label;
  final T      value;
  const _SegmentOption({required this.label, required this.value});
}

class _SegmentedRow<T> extends StatelessWidget {
  final List<_SegmentOption<T>> options;
  final T                       selected;
  final Color                   accentColor;
  final void Function(T)         onSelected;

  const _SegmentedRow({
    required this.options, required this.selected,
    required this.accentColor, required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: options.map((opt) {
      final isActive = opt.value == selected;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelected(opt.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin:  const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color:        isActive
                  ? accentColor.withOpacity(0.15)
                  : const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? accentColor : const Color(0xFF1E2333),
                width: isActive ? 1.5 : 1.0,
              ),
            ),
            child: Text(
              opt.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:      isActive ? accentColor : const Color(0xFF6B7280),
                fontSize:   12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

// ── Mini Candle Preview ───────────────────────────────────────────────────────

class _MiniCandlePreview extends StatelessWidget {
  final ChartStyleState style;
  const _MiniCandlePreview({required this.style});

  @override
  Widget build(BuildContext context) => Container(
    width:  120, height: 40,
    decoration: BoxDecoration(
      color:        style.backgroundColor,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFF1E2333)),
    ),
    child: CustomPaint(painter: _CandlePreviewPainter(style: style)),
  );
}

class _CandlePreviewPainter extends CustomPainter {
  final ChartStyleState style;
  const _CandlePreviewPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final bullPaint = Paint()
      ..color = style.bullishColor.withOpacity(style.candleOpacity)
      ..style = style.bodyStyle == CandleBodyStyle.filled
          ? PaintingStyle.fill
          : PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final bearPaint = Paint()
      ..color = style.bearishColor.withOpacity(style.candleOpacity)
      ..style = style.bodyStyle == CandleBodyStyle.filled
          ? PaintingStyle.fill
          : PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final wickPaint = Paint()..strokeWidth = 1.0;

    const data = [
      (0.55, 0.80, 0.50, 0.85, true),
      (0.50, 0.70, 0.45, 0.75, false),
      (0.45, 0.65, 0.40, 0.70, true),
      (0.30, 0.60, 0.25, 0.65, true),
      (0.35, 0.55, 0.30, 0.60, false),
    ];

    final cw   = size.width / data.length;
    final half = cw * 0.28;

    for (var i = 0; i < data.length; i++) {
      final (open, close, low, high, bull) = data[i];
      final cx     = cw * i + cw / 2;
      final openY  = size.height * open;
      final closeY = size.height * close;
      final lowY   = size.height * low;
      final highY  = size.height * high;
      final paint  = bull ? bullPaint : bearPaint;

      if (style.showWick) {
        wickPaint.color = (bull ? style.bullishColor : style.bearishColor)
            .withOpacity(style.wickOpacity);
        canvas.drawLine(Offset(cx, highY), Offset(cx, lowY), wickPaint);
      }

      final top = openY < closeY ? openY : closeY;
      final bh  = (openY - closeY).abs().clamp(1.5, size.height);
      canvas.drawRect(Rect.fromLTWH(cx - half, top, half * 2, bh), paint);
    }
  }

  @override
  bool shouldRepaint(_CandlePreviewPainter old) => old.style != style;
}