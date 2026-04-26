// =============================================================================
// color_picker.dart
// Path: frontend/lib/dialogs/color_picker.dart
//
// Full RGB / HSV color picker — standalone widget.
//
// Cara pakai:
//   final picked = await FullColorPicker.show(context, initial: currentColor);
//   if (picked != null) setState(() => myColor = picked);
// =============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Public entry point ────────────────────────────────────────────────────────

class FullColorPicker {
  /// Tampilkan color picker sebagai modal bottom sheet.
  /// Return null jika user cancel.
  static Future<Color?> show(
    BuildContext context, {
    required Color initial,
  }) {
    return showModalBottomSheet<Color>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      barrierColor:       Colors.black.withOpacity(0.6),
      builder: (_) => _ColorPickerSheet(initial: initial),
    );
  }
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _ColorPickerSheet extends StatefulWidget {
  final Color initial;
  const _ColorPickerSheet({required this.initial});

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet>
    with SingleTickerProviderStateMixin {

  static const _bg     = Color(0xFF0E1117);
  static const _border = Color(0xFF1E2333);
  static const _muted  = Color(0xFF6B7280);
  static const _text   = Color(0xFFE8EAF0);

  late TabController _tab;

  // HSV state — source of truth
  late double _hue;   // 0–360
  late double _sat;   // 0–1
  late double _val;   // 0–1
  late double _alpha; // 0–1

  // RGB derived (kept in sync)
  late int _r, _g, _b;

  // Hex text controller
  late TextEditingController _hexCtrl;
  bool _hexError = false;

  @override
  void initState() {
    super.initState();
    _tab   = TabController(length: 2, vsync: this);
    _alpha = widget.initial.opacity;
    _fromColor(widget.initial);
    _hexCtrl = TextEditingController(text: _toHex(_currentColorOpaque));
  }

  @override
  void dispose() {
    _tab.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  // ── Conversions ──────────────────────────────────────────────────────────────

  void _fromColor(Color c) {
    final hsv = HSVColor.fromColor(c);
    _hue  = hsv.hue;
    _sat  = hsv.saturation;
    _val  = hsv.value;
    _alpha = c.opacity;
    _syncRGB();
  }

  void _syncRGB() {
    final c = _currentColorOpaque;
    _r = c.red;
    _g = c.green;
    _b = c.blue;
  }

  Color get _currentColorOpaque =>
      HSVColor.fromAHSV(1.0, _hue, _sat, _val).toColor();

  Color get _currentColor =>
      HSVColor.fromAHSV(_alpha, _hue, _sat, _val).toColor();

  String _toHex(Color c) {
    final r = c.red.toRadixString(16).padLeft(2, '0');
    final g = c.green.toRadixString(16).padLeft(2, '0');
    final b = c.blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  void _setHue(double h)   { setState(() { _hue = h.clamp(0, 360); _syncRGB(); _refreshHex(); }); }
  void _setSat(double s)   { setState(() { _sat = s.clamp(0, 1);   _syncRGB(); _refreshHex(); }); }
  void _setVal(double v)   { setState(() { _val = v.clamp(0, 1);   _syncRGB(); _refreshHex(); }); }
  void _setAlpha(double a) { setState(() { _alpha = a.clamp(0, 1); _refreshHex(); }); }

  void _setR(int v) {
    _r = v.clamp(0, 255);
    final hsv = HSVColor.fromColor(Color.fromRGBO(_r, _g, _b, 1));
    setState(() {
      _hue = hsv.hue; _sat = hsv.saturation; _val = hsv.value;
      _refreshHex();
    });
  }

  void _setG(int v) {
    _g = v.clamp(0, 255);
    final hsv = HSVColor.fromColor(Color.fromRGBO(_r, _g, _b, 1));
    setState(() {
      _hue = hsv.hue; _sat = hsv.saturation; _val = hsv.value;
      _refreshHex();
    });
  }

  void _setB(int v) {
    _b = v.clamp(0, 255);
    final hsv = HSVColor.fromColor(Color.fromRGBO(_r, _g, _b, 1));
    setState(() {
      _hue = hsv.hue; _sat = hsv.saturation; _val = hsv.value;
      _refreshHex();
    });
  }

  void _refreshHex() {
    _hexCtrl.text = _toHex(_currentColorOpaque);
    _hexError = false;
  }

  void _parseHexInput(String raw) {
    final s = raw.replaceAll('#', '').trim();
    if (s.length == 6) {
      final v = int.tryParse('FF$s', radix: 16);
      if (v != null) {
        _fromColor(Color(v));
        setState(() { _hexError = false; });
        return;
      }
    }
    setState(() { _hexError = s.isNotEmpty; });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height:     screenH * 0.78,
      decoration: const BoxDecoration(
        color:        _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border:       Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          _handle(),
          _header(),
          _previewStrip(),
          _tabBar(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics:    const NeverScrollableScrollPhysics(),
              children:   [_hsvTab(), _rgbTab()],
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _handle() => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Container(
      width: 36, height: 4,
      decoration: BoxDecoration(
        color: _muted.withOpacity(0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
    child: Row(
      children: [
        const Text('COLOR PICKER', style: TextStyle(
          color: _text, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.8,
        )),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: _muted, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );

  Widget _previewStrip() {
    final c = _currentColor;
    final hexStr = _toHex(_currentColorOpaque);
    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 8, 16, 12),
      height:  48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _CheckerPainter())),
            Positioned.fill(child: Container(color: c)),
            Positioned(
              right: 12, top: 0, bottom: 0,
              child: Center(
                child: Text(
                  hexStr,
                  style: TextStyle(
                    color: c.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBar() => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
      labelColor:           _text,
      unselectedLabelColor: _muted,
      labelStyle:           const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      padding:              const EdgeInsets.all(3),
      tabs: const [Tab(text: 'HSV / Wheel'), Tab(text: 'RGB Sliders')],
    ),
  );

  // ── HSV Tab ──────────────────────────────────────────────────────────────────

  Widget _hsvTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: SizedBox(
            width:  240,
            height: 240,
            child: _ColorWheel(
              hue:        _hue,
              saturation: _sat,
              value:      _val,
              onChanged: (h, s, v) {
                setState(() {
                  _hue = h; _sat = s; _val = v;
                  _syncRGB(); _refreshHex();
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        _label('BRIGHTNESS'),
        _GradientSlider(
          value: _val,
          gradient: LinearGradient(colors: [
            Colors.black,
            HSVColor.fromAHSV(1, _hue, _sat, 1).toColor(),
          ]),
          onChanged: _setVal,
          thumbColor: _currentColorOpaque,
        ),
        const SizedBox(height: 14),

        _label('OPACITY'),
        _AlphaSlider(
          alpha:     _alpha,
          baseColor: _currentColorOpaque,
          onChanged: _setAlpha,
        ),
        const SizedBox(height: 14),

        _label('HEX'),
        const SizedBox(height: 6),
        _hexField(),

        const SizedBox(height: 14),
        _label('QUICK COLORS'),
        const SizedBox(height: 8),
        _rainbowSwatches(),
      ],
    );
  }

  // ── RGB Tab ──────────────────────────────────────────────────────────────────

  Widget _rgbTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _label('RED'),
        _GradientSlider(
          value: _r / 255,
          gradient: LinearGradient(colors: [
            Color.fromRGBO(0, _g, _b, 1),
            Color.fromRGBO(255, _g, _b, 1),
          ]),
          onChanged: (v) => _setR((v * 255).round()),
          thumbColor: Color.fromRGBO(_r, 0, 0, 1),
        ),
        _rgbValueField(_r, _setR),
        const SizedBox(height: 16),

        _label('GREEN'),
        _GradientSlider(
          value: _g / 255,
          gradient: LinearGradient(colors: [
            Color.fromRGBO(_r, 0, _b, 1),
            Color.fromRGBO(_r, 255, _b, 1),
          ]),
          onChanged: (v) => _setG((v * 255).round()),
          thumbColor: Color.fromRGBO(0, _g, 0, 1),
        ),
        _rgbValueField(_g, _setG),
        const SizedBox(height: 16),

        _label('BLUE'),
        _GradientSlider(
          value: _b / 255,
          gradient: LinearGradient(colors: [
            Color.fromRGBO(_r, _g, 0, 1),
            Color.fromRGBO(_r, _g, 255, 1),
          ]),
          onChanged: (v) => _setB((v * 255).round()),
          thumbColor: Color.fromRGBO(0, 0, _b, 1),
        ),
        _rgbValueField(_b, _setB),
        const SizedBox(height: 16),

        _label('OPACITY'),
        _AlphaSlider(
          alpha:     _alpha,
          baseColor: _currentColorOpaque,
          onChanged: _setAlpha,
        ),
        const SizedBox(height: 14),

        _label('HEX'),
        const SizedBox(height: 6),
        _hexField(),

        const SizedBox(height: 14),
        _label('QUICK COLORS'),
        const SizedBox(height: 8),
        _rainbowSwatches(),
      ],
    );
  }

  // ── Shared UI ────────────────────────────────────────────────────────────────

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(t, style: const TextStyle(
      color: _muted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.4,
    )),
  );

  Widget _hexField() => Row(
    children: [
      const Icon(Icons.tag, color: _muted, size: 14),
      const SizedBox(width: 4),
      SizedBox(
        width: 110,
        child: TextField(
          controller:   _hexCtrl,
          style:        const TextStyle(color: _text, fontSize: 13),
          maxLength:    7,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
              const SizedBox.shrink(),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
          ],
          decoration: InputDecoration(
            isDense:   true,
            filled:    true,
            fillColor: const Color(0xFF161B27),
            errorText: _hexError ? '' : null,
            errorStyle: const TextStyle(height: 0),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:   const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:   const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:   BorderSide(color: _currentColorOpaque),
            ),
          ),
          onChanged: _parseHexInput,
        ),
      ),
    ],
  );

  Widget _rgbValueField(int value, void Function(int) onSet) => Align(
    alignment: Alignment.centerRight,
    child: SizedBox(
      width: 56,
      child: TextField(
        key:       ValueKey(value),
        controller: TextEditingController(text: value.toString()),
        style:     const TextStyle(color: _text, fontSize: 12),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _RangeFormatter(0, 255),
        ],
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
            const SizedBox.shrink(),
        maxLength: 3,
        decoration: InputDecoration(
          isDense:        true,
          filled:         true,
          fillColor:      const Color(0xFF161B27),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide:   const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide:   const BorderSide(color: _border),
          ),
        ),
        onChanged: (v) {
          final i = int.tryParse(v);
          if (i != null) onSet(i);
        },
      ),
    ),
  );

  Widget _rainbowSwatches() {
    const swatches = [
      // Rainbow
      Color(0xFFFF0000), Color(0xFFFF6600), Color(0xFFFFCC00),
      Color(0xFF00FF00), Color(0xFF00CCFF), Color(0xFF0000FF),
      Color(0xFF9900FF), Color(0xFFFF00FF),
      // Neon
      Color(0xFF00FF88), Color(0xFF00FFD1), Color(0xFF00D09C),
      Color(0xFFFF4D6D), Color(0xFFFF0066), Color(0xFFFFC837),
      Color(0xFF06FFA5), Color(0xFFFF6B35),
      // Neutral
      Color(0xFFFFFFFF), Color(0xFFCCCCCC), Color(0xFF888888),
      Color(0xFF444444), Color(0xFF222222), Color(0xFF000000),
      Color(0xFF1E222D), Color(0xFF0A0E17),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: swatches.map((c) {
        final isSelected = _currentColorOpaque.value == c.value;
        return GestureDetector(
          onTap: () {
            _fromColor(c);
            setState(() {});
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.12),
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: c.withOpacity(0.6), blurRadius: 8)]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check_rounded, size: 14,
                    color: c.computeLuminance() > 0.4 ? Colors.black : Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _bottomBar() => Container(
    height:  72,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: _border)),
    ),
    child: Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color:        _currentColor,
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(color: _border),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'α ${(_alpha * 100).round()}%',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2333), borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Cancel', style: TextStyle(color: _muted, fontSize: 13)),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(_currentColor),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _currentColorOpaque, borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Apply',
              style: TextStyle(
                color:      _currentColorOpaque.computeLuminance() > 0.4
                    ? Colors.black : Colors.white,
                fontSize:   13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Color Wheel ───────────────────────────────────────────────────────────────

class _ColorWheel extends StatefulWidget {
  final double hue, saturation, value;
  final void Function(double h, double s, double v) onChanged;
  const _ColorWheel({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ColorWheel> createState() => _ColorWheelState();
}

class _ColorWheelState extends State<_ColorWheel> {
  void _handleDrag(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;

    final hue = (math.atan2(dy, dx) * 180 / math.pi + 360) % 360;
    final sat = (math.sqrt(dx * dx + dy * dy) / radius).clamp(0.0, 1.0);

    widget.onChanged(hue, sat, widget.value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart:  (d) => _handleDrag(d.localPosition, context.size!),
      onPanUpdate: (d) => _handleDrag(d.localPosition, context.size!),
      onTapDown:   (d) => _handleDrag(d.localPosition, context.size!),
      child: CustomPaint(
        painter: _ColorWheelPainter(
          hue: widget.hue, saturation: widget.saturation, value: widget.value,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final double hue, saturation, value;
  const _ColorWheelPainter({
    required this.hue, required this.saturation, required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    // Hue sweep
    canvas.drawCircle(center, radius, Paint()
      ..shader = SweepGradient(
        colors: const [
          Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
          Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
        ],
        stops: const [0, 1/6, 2/6, 3/6, 4/6, 5/6, 1],
      ).createShader(rect));

    // White radial (saturation)
    canvas.drawCircle(center, radius, Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.white.withOpacity(0)],
      ).createShader(rect));

    // Black overlay (value/brightness)
    canvas.drawCircle(center, radius,
        Paint()..color = Colors.black.withOpacity(1 - value));

    // Border
    canvas.drawCircle(center, radius, Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Thumb
    final angle = hue * math.pi / 180;
    final thumbR = radius * saturation;
    final thumbPos = Offset(
      center.dx + thumbR * math.cos(angle),
      center.dy + thumbR * math.sin(angle),
    );
    final thumbColor = HSVColor.fromAHSV(1, hue, saturation, value).toColor();

    canvas.drawCircle(thumbPos, 10, Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(thumbPos, 10, Paint()..color = thumbColor);
    canvas.drawCircle(thumbPos, 10, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(_ColorWheelPainter old) =>
      old.hue != hue || old.saturation != saturation || old.value != value;
}

// ── Gradient Slider ───────────────────────────────────────────────────────────

class _GradientSlider extends StatelessWidget {
  final double              value;
  final LinearGradient      gradient;
  final Color               thumbColor;
  final void Function(double) onChanged;

  const _GradientSlider({
    required this.value,
    required this.gradient,
    required this.thumbColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight:        12,
        thumbShape:         _GradientThumb(color: thumbColor),
        overlayShape:       const RoundSliderOverlayShape(overlayRadius: 14),
        overlayColor:       thumbColor.withOpacity(0.2),
        trackShape:         _GradientTrack(gradient: gradient),
        activeTrackColor:   Colors.transparent,
        inactiveTrackColor: Colors.transparent,
      ),
      child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
    );
  }
}

class _GradientThumb extends SliderComponentShape {
  final Color color;
  const _GradientThumb({required this.color});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(22, 22);

  @override
  void paint(
    PaintingContext context, Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 11, Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(center, 10, Paint()..color = color);
    canvas.drawCircle(center, 10, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
  }
}

class _GradientTrack extends SliderTrackShape with BaseSliderTrackShape {
  final LinearGradient gradient;
  const _GradientTrack({required this.gradient});

  @override
  void paint(
    PaintingContext context, Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox, offset: offset,
      sliderTheme: sliderTheme, isEnabled: isEnabled, isDiscrete: isDiscrete,
    );
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(6)),
      Paint()..shader = gradient.createShader(trackRect),
    );
  }
}

// ── Alpha Slider ──────────────────────────────────────────────────────────────

class _AlphaSlider extends StatelessWidget {
  final double              alpha;
  final Color               baseColor;
  final void Function(double) onChanged;

  const _AlphaSlider({
    required this.alpha, required this.baseColor, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CustomPaint(painter: _CheckerPainter()),
            ),
          ),
          _GradientSlider(
            value:      alpha,
            gradient:   LinearGradient(colors: [
              baseColor.withOpacity(0), baseColor,
            ]),
            thumbColor: baseColor,
            onChanged:  onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Checkerboard ──────────────────────────────────────────────────────────────

class _CheckerPainter extends CustomPainter {
  static const double _size = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()..color = const Color(0xFF888888);
    final p2 = Paint()..color = const Color(0xFFCCCCCC);
    final cols = (size.width  / _size).ceil();
    final rows = (size.height / _size).ceil();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawRect(
          Rect.fromLTWH(c * _size, r * _size, _size, _size),
          (r + c).isEven ? p1 : p2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => false;
}

// ── Range Formatter ───────────────────────────────────────────────────────────

class _RangeFormatter extends TextInputFormatter {
  final int min, max;
  const _RangeFormatter(this.min, this.max);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    if (next.text.isEmpty) return next;
    final v = int.tryParse(next.text);
    if (v == null) return old;
    if (v < min) return next.copyWith(text: min.toString());
    if (v > max) return next.copyWith(text: max.toString());
    return next;
  }
}