// =============================================================================
// apps_colors_tradingview.dart
// Path: frontend/lib/style/apps_colors_tradingview.dart
//
// Color tokens untuk Python Text Editor (TradingView Admin Panel).
// Semua warna bisa dioverride via EditorThemeState — connect ke
// style_settings_panel.dart tab "Editor".
//
// Usage:
//   EditorThemeState theme = EditorThemeState(); // default dark
//   theme.syntaxColors.keyword  → Color
//   theme.editorColors.background → Color
// =============================================================================

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 1 — Raw color palette (tidak langsung dipakai widget)
//  Ini adalah konstanta dasar, mapping semantic di bawah.
// ─────────────────────────────────────────────────────────────────────────────

class _EditorPalette {
  _EditorPalette._();

  // Neutrals
  static const Color grey50  = Color(0xFFF8F9FC);
  static const Color grey100 = Color(0xFFEAECF2);
  static const Color grey200 = Color(0xFFC7CAD6);
  static const Color grey300 = Color(0xFF9EA3B5);
  static const Color grey400 = Color(0xFF6B7280);
  static const Color grey500 = Color(0xFF495162);
  static const Color grey600 = Color(0xFF353A4A);
  static const Color grey700 = Color(0xFF272B38);
  static const Color grey800 = Color(0xFF1E222D);
  static const Color grey900 = Color(0xFF161A25);
  static const Color grey950 = Color(0xFF0E1219);

  // Syntax palette
  static const Color orange      = Color(0xFFCC7832); // keywords
  static const Color cyan        = Color(0xFF56B6C2); // builtins
  static const Color blue        = Color(0xFF6897BB); // numbers
  static const Color lightBlue   = Color(0xFF68A8D8); // constants
  static const Color teal        = Color(0xFF4EC9B0); // class / typehint
  static const Color yellow      = Color(0xFFDCDCAA); // function def
  static const Color green       = Color(0xFF6A8759); // string
  static const Color yellowGreen = Color(0xFF9AAA50); // f-string
  static const Color olive       = Color(0xFFBBB529); // decorator
  static const Color silver      = Color(0xFFA9B7C6); // plain / operator
  static const Color mutedGrey   = Color(0xFF808080); // comment
  static const Color red         = Color(0xFFFF4D6D); // error underline
  static const Color amber       = Color(0xFFFFD600); // warning underline

  // Accent
  static const Color accentCyan  = Color(0xFF00BCD4);
  static const Color accentGreen = Color(0xFF00D09C);
  static const Color accentBlue  = Color(0xFF2962FF);
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 2 — Syntax color tokens
//  Mutable supaya bisa diubah via settings panel.
// ─────────────────────────────────────────────────────────────────────────────

class EditorSyntaxColors {
  Color keyword;
  Color builtinFunc;
  Color builtinConst;
  Color decorator;
  Color className;
  Color functionDef;
  Color string;
  Color fstring;
  Color comment;
  Color number;
  Color operator_;
  Color punctuation;
  Color selfParam;
  Color typehint;
  Color plain;
  Color errorUnderline;
  Color warningUnderline;

  EditorSyntaxColors({
    this.keyword        = _EditorPalette.orange,
    this.builtinFunc    = _EditorPalette.cyan,
    this.builtinConst   = _EditorPalette.lightBlue,
    this.decorator      = _EditorPalette.olive,
    this.className      = _EditorPalette.teal,
    this.functionDef    = _EditorPalette.yellow,
    this.string         = _EditorPalette.green,
    this.fstring        = _EditorPalette.yellowGreen,
    this.comment        = _EditorPalette.mutedGrey,
    this.number         = _EditorPalette.blue,
    this.operator_      = _EditorPalette.silver,
    this.punctuation    = _EditorPalette.silver,
    this.selfParam      = _EditorPalette.orange,
    this.typehint       = _EditorPalette.teal,
    this.plain          = _EditorPalette.silver,
    this.errorUnderline = _EditorPalette.red,
    this.warningUnderline = _EditorPalette.amber,
  });

  EditorSyntaxColors copyWith({
    Color? keyword, Color? builtinFunc, Color? builtinConst,
    Color? decorator, Color? className, Color? functionDef,
    Color? string, Color? fstring, Color? comment, Color? number,
    Color? operator_, Color? punctuation, Color? selfParam,
    Color? typehint, Color? plain, Color? errorUnderline,
    Color? warningUnderline,
  }) => EditorSyntaxColors(
    keyword:           keyword        ?? this.keyword,
    builtinFunc:       builtinFunc    ?? this.builtinFunc,
    builtinConst:      builtinConst   ?? this.builtinConst,
    decorator:         decorator      ?? this.decorator,
    className:         className      ?? this.className,
    functionDef:       functionDef    ?? this.functionDef,
    string:            string         ?? this.string,
    fstring:           fstring        ?? this.fstring,
    comment:           comment        ?? this.comment,
    number:            number         ?? this.number,
    operator_:         operator_      ?? this.operator_,
    punctuation:       punctuation    ?? this.punctuation,
    selfParam:         selfParam      ?? this.selfParam,
    typehint:          typehint       ?? this.typehint,
    plain:             plain          ?? this.plain,
    errorUnderline:    errorUnderline ?? this.errorUnderline,
    warningUnderline:  warningUnderline ?? this.warningUnderline,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 3 — Editor chrome colors (background, gutter, selection, dll)
// ─────────────────────────────────────────────────────────────────────────────

class EditorChromeColors {
  Color background;
  Color surface;
  Color sidebarBackground; // ← file explorer sidebar
  Color inputBackground;   // ← search bar & dialog inputs
  Color gutterBackground;
  Color gutterBorder;
  Color lineNumberDefault;
  Color lineNumberActive;
  Color activeLineHighlight;
  Color selectionColor;
  Color cursorColor;
  Color matchHighlight;
  Color scrollbarThumb;
  Color scrollbarTrack;
  Color tabActive;
  Color tabInactive;
  Color tabBorder;
  Color toolbarBackground;
  Color toolbarBorder;
  Color consoleBackground;
  Color consoleBorder;
  Color consoleTextDefault;
  Color consoleTextError;
  Color consoleTextSuccess;
  Color consoleTextInfo;
  Color consoleTextWarning;

  EditorChromeColors({
    this.background         = _EditorPalette.grey950,
    this.surface            = _EditorPalette.grey800,
    this.sidebarBackground  = _EditorPalette.grey900,  // sedikit lebih gelap dari editor
    this.inputBackground    = _EditorPalette.grey800,  // sama dengan surface
    this.gutterBackground   = _EditorPalette.grey900,
    this.gutterBorder       = _EditorPalette.grey700,
    this.lineNumberDefault  = _EditorPalette.grey500,
    this.lineNumberActive   = _EditorPalette.grey200,
    this.activeLineHighlight= const Color(0x1A2962FF),
    this.selectionColor     = const Color(0x4D2962FF),
    this.cursorColor        = _EditorPalette.accentCyan,
    this.matchHighlight     = const Color(0x40FFCC00),
    this.scrollbarThumb     = _EditorPalette.grey600,
    this.scrollbarTrack     = _EditorPalette.grey900,
    this.tabActive          = _EditorPalette.grey800,
    this.tabInactive        = _EditorPalette.grey900,
    this.tabBorder          = _EditorPalette.grey700,
    this.toolbarBackground  = _EditorPalette.grey900,
    this.toolbarBorder      = _EditorPalette.grey700,
    this.consoleBackground  = const Color(0xFF0A0D14),
    this.consoleBorder      = _EditorPalette.grey700,
    this.consoleTextDefault = _EditorPalette.silver,
    this.consoleTextError   = _EditorPalette.red,
    this.consoleTextSuccess = _EditorPalette.accentGreen,
    this.consoleTextInfo    = _EditorPalette.lightBlue,
    this.consoleTextWarning = _EditorPalette.amber,
  });

  EditorChromeColors copyWith({
    Color? background, Color? surface,
    Color? sidebarBackground, Color? inputBackground,
    Color? gutterBackground, Color? gutterBorder,
    Color? lineNumberDefault, Color? lineNumberActive,
    Color? activeLineHighlight, Color? selectionColor, Color? cursorColor,
    Color? matchHighlight, Color? scrollbarThumb, Color? scrollbarTrack,
    Color? tabActive, Color? tabInactive, Color? tabBorder,
    Color? toolbarBackground, Color? toolbarBorder,
    Color? consoleBackground, Color? consoleBorder,
    Color? consoleTextDefault, Color? consoleTextError,
    Color? consoleTextSuccess, Color? consoleTextInfo,
    Color? consoleTextWarning,
  }) => EditorChromeColors(
    background:          background          ?? this.background,
    surface:             surface             ?? this.surface,
    sidebarBackground:   sidebarBackground   ?? this.sidebarBackground,
    inputBackground:     inputBackground     ?? this.inputBackground,
    gutterBackground:    gutterBackground    ?? this.gutterBackground,
    gutterBorder:        gutterBorder        ?? this.gutterBorder,
    lineNumberDefault:   lineNumberDefault   ?? this.lineNumberDefault,
    lineNumberActive:    lineNumberActive    ?? this.lineNumberActive,
    activeLineHighlight: activeLineHighlight ?? this.activeLineHighlight,
    selectionColor:      selectionColor      ?? this.selectionColor,
    cursorColor:         cursorColor         ?? this.cursorColor,
    matchHighlight:      matchHighlight      ?? this.matchHighlight,
    scrollbarThumb:      scrollbarThumb      ?? this.scrollbarThumb,
    scrollbarTrack:      scrollbarTrack      ?? this.scrollbarTrack,
    tabActive:           tabActive           ?? this.tabActive,
    tabInactive:         tabInactive         ?? this.tabInactive,
    tabBorder:           tabBorder           ?? this.tabBorder,
    toolbarBackground:   toolbarBackground   ?? this.toolbarBackground,
    toolbarBorder:       toolbarBorder       ?? this.toolbarBorder,
    consoleBackground:   consoleBackground   ?? this.consoleBackground,
    consoleBorder:       consoleBorder       ?? this.consoleBorder,
    consoleTextDefault:  consoleTextDefault  ?? this.consoleTextDefault,
    consoleTextError:    consoleTextError    ?? this.consoleTextError,
    consoleTextSuccess:  consoleTextSuccess  ?? this.consoleTextSuccess,
    consoleTextInfo:     consoleTextInfo     ?? this.consoleTextInfo,
    consoleTextWarning:  consoleTextWarning  ?? this.consoleTextWarning,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 4 — Typography tokens
// ─────────────────────────────────────────────────────────────────────────────

class EditorTypography {
  String fontFamily;
  double fontSize;
  double lineHeight;
  double letterSpacing;

  EditorTypography({
    this.fontFamily    = 'monospace',
    this.fontSize      = 13.0,
    this.lineHeight    = 1.6,
    this.letterSpacing = 0.3,
  });

  EditorTypography copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
  }) => EditorTypography(
    fontFamily:    fontFamily    ?? this.fontFamily,
    fontSize:      fontSize      ?? this.fontSize,
    lineHeight:    lineHeight    ?? this.lineHeight,
    letterSpacing: letterSpacing ?? this.letterSpacing,
  );

  TextStyle get baseStyle => TextStyle(
    fontFamily:    fontFamily,
    fontSize:      fontSize,
    height:        lineHeight,
    letterSpacing: letterSpacing,
    color:         _EditorPalette.silver,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 5 — Preset themes
// ─────────────────────────────────────────────────────────────────────────────

enum EditorThemePreset {
  tradingViewDark,
  vscodeDark,
  draculaDark,
  monokaiPro,
  githubDark,
  light,
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 6 — EditorThemeState  (main class yang di-pass ke settings panel)
// ─────────────────────────────────────────────────────────────────────────────

class EditorThemeState {
  final EditorSyntaxColors syntax;
  final EditorChromeColors chrome;
  final EditorTypography   typography;
  final EditorThemePreset  activePreset;

  // Background image / gradient (mirror ChartStyleState supaya konsisten)
  final Color?  backgroundGradientEnd;
  final String? backgroundImagePath;
  final double  backgroundOpacity;

  const EditorThemeState._({
    required this.syntax,
    required this.chrome,
    required this.typography,
    required this.activePreset,
    this.backgroundGradientEnd,
    this.backgroundImagePath,
    this.backgroundOpacity = 1.0,
  });

  // ── Default constructor (TradingView Dark) ────────────────────────────────
  factory EditorThemeState() => EditorThemeState._(
    syntax:      EditorSyntaxColors(),
    chrome:      EditorChromeColors(),
    typography:  EditorTypography(),
    activePreset: EditorThemePreset.tradingViewDark,
    backgroundOpacity: 1.0,
  );

  // ── Preset factory ────────────────────────────────────────────────────────
  factory EditorThemeState.fromPreset(EditorThemePreset preset) {
    switch (preset) {
      case EditorThemePreset.tradingViewDark:
        return EditorThemeState(); // default sudah TradingView

      case EditorThemePreset.vscodeDark:
        return EditorThemeState._(
          activePreset: preset,
          typography:   EditorTypography(),
          chrome: EditorChromeColors(
            background:       const Color(0xFF1E1E1E),
            gutterBackground: const Color(0xFF1E1E1E),
            surface:          const Color(0xFF252526),
            activeLineHighlight: const Color(0x1AFFFFFF),
          ),
          syntax: EditorSyntaxColors(
            keyword:     const Color(0xFF569CD6),
            builtinFunc: const Color(0xFFDCDCAA),
            className:   const Color(0xFF4EC9B0),
            functionDef: const Color(0xFFDCDCAA),
            string:      const Color(0xFFCE9178),
            fstring:     const Color(0xFFCE9178),
            comment:     const Color(0xFF6A9955),
            number:      const Color(0xFFB5CEA8),
            decorator:   const Color(0xFFDCDCAA),
            plain:       const Color(0xFFD4D4D4),
          ),
        );

      case EditorThemePreset.draculaDark:
        return EditorThemeState._(
          activePreset: preset,
          typography:   EditorTypography(),
          chrome: EditorChromeColors(
            background:       const Color(0xFF282A36),
            gutterBackground: const Color(0xFF21222C),
            surface:          const Color(0xFF343746),
            cursorColor:      const Color(0xFFF8F8F2),
          ),
          syntax: EditorSyntaxColors(
            keyword:     const Color(0xFFFF79C6),
            builtinFunc: const Color(0xFF8BE9FD),
            className:   const Color(0xFF50FA7B),
            functionDef: const Color(0xFF50FA7B),
            string:      const Color(0xFFF1FA8C),
            fstring:     const Color(0xFFF1FA8C),
            comment:     const Color(0xFF6272A4),
            number:      const Color(0xFFBD93F9),
            decorator:   const Color(0xFFFFB86C),
            selfParam:   const Color(0xFFFFB86C),
            plain:       const Color(0xFFF8F8F2),
          ),
        );

      case EditorThemePreset.monokaiPro:
        return EditorThemeState._(
          activePreset: preset,
          typography:   EditorTypography(),
          chrome: EditorChromeColors(
            background:       const Color(0xFF2D2A2E),
            gutterBackground: const Color(0xFF221F22),
            surface:          const Color(0xFF363537),
            cursorColor:      const Color(0xFFFCFCFA),
          ),
          syntax: EditorSyntaxColors(
            keyword:     const Color(0xFFFF6188),
            builtinFunc: const Color(0xFF78DCE8),
            className:   const Color(0xFFA9DC76),
            functionDef: const Color(0xFFA9DC76),
            string:      const Color(0xFFFFD866),
            fstring:     const Color(0xFFFFD866),
            comment:     const Color(0xFF727072),
            number:      const Color(0xFFAB9DF2),
            decorator:   const Color(0xFFFC9867),
            selfParam:   const Color(0xFFFC9867),
            plain:       const Color(0xFFFCFCFA),
          ),
        );

      case EditorThemePreset.githubDark:
        return EditorThemeState._(
          activePreset: preset,
          typography:   EditorTypography(),
          chrome: EditorChromeColors(
            background:       const Color(0xFF0D1117),
            gutterBackground: const Color(0xFF010409),
            surface:          const Color(0xFF161B22),
            cursorColor:      const Color(0xFFC9D1D9),
            activeLineHighlight: const Color(0x1A58A6FF),
          ),
          syntax: EditorSyntaxColors(
            keyword:     const Color(0xFFFF7B72),
            builtinFunc: const Color(0xFFD2A8FF),
            className:   const Color(0xFFF0883E),
            functionDef: const Color(0xFFD2A8FF),
            string:      const Color(0xFFA5D6FF),
            fstring:     const Color(0xFFA5D6FF),
            comment:     const Color(0xFF8B949E),
            number:      const Color(0xFF79C0FF),
            decorator:   const Color(0xFFF0883E),
            plain:       const Color(0xFFC9D1D9),
          ),
        );

      case EditorThemePreset.light:
        return EditorThemeState._(
          activePreset: preset,
          typography:   EditorTypography(),
          chrome: EditorChromeColors(
            background:         const Color(0xFFFFFFFF),
            gutterBackground:   const Color(0xFFF3F4F6),
            gutterBorder:       const Color(0xFFE5E7EB),
            surface:            const Color(0xFFF9FAFB),
            lineNumberDefault:  const Color(0xFF9CA3AF),
            lineNumberActive:   const Color(0xFF374151),
            activeLineHighlight: const Color(0x0A2962FF),
            selectionColor:     const Color(0x402962FF),
            cursorColor:        const Color(0xFF0D6EFD),
            scrollbarThumb:     const Color(0xFFD1D5DB),
            tabActive:          const Color(0xFFFFFFFF),
            tabInactive:        const Color(0xFFF3F4F6),
            tabBorder:          const Color(0xFFE5E7EB),
            toolbarBackground:  const Color(0xFFF3F4F6),
            toolbarBorder:      const Color(0xFFE5E7EB),
            consoleBackground:  const Color(0xFFFAFAFA),
            consoleBorder:      const Color(0xFFE5E7EB),
            consoleTextDefault: const Color(0xFF374151),
          ),
          syntax: EditorSyntaxColors(
            keyword:     const Color(0xFF0000FF),
            builtinFunc: const Color(0xFF795E26),
            className:   const Color(0xFF267F99),
            functionDef: const Color(0xFF795E26),
            string:      const Color(0xFFA31515),
            fstring:     const Color(0xFFA31515),
            comment:     const Color(0xFF008000),
            number:      const Color(0xFF098658),
            decorator:   const Color(0xFF795E26),
            selfParam:   const Color(0xFF001080),
            plain:       const Color(0xFF000000),
            operator_:   const Color(0xFF000000),
            punctuation: const Color(0xFF000000),
          ),
        );
    }
  }

  // ── copyWith ──────────────────────────────────────────────────────────────
  EditorThemeState copyWith({
    EditorSyntaxColors? syntax,
    EditorChromeColors? chrome,
    EditorTypography?   typography,
    EditorThemePreset?  activePreset,
    Color?              backgroundGradientEnd,
    String?             backgroundImagePath,
    double?             backgroundOpacity,
  }) => EditorThemeState._(
    syntax:                syntax             ?? this.syntax,
    chrome:                chrome             ?? this.chrome,
    typography:            typography         ?? this.typography,
    activePreset:          activePreset       ?? this.activePreset,
    backgroundGradientEnd: backgroundGradientEnd ?? this.backgroundGradientEnd,
    backgroundImagePath:   backgroundImagePath   ?? this.backgroundImagePath,
    backgroundOpacity:     backgroundOpacity     ?? this.backgroundOpacity,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 7 — Preset metadata (untuk display di settings panel)
// ─────────────────────────────────────────────────────────────────────────────

class EditorThemePresetMeta {
  final String             name;
  final EditorThemePreset  preset;
  final EditorThemeState   state;
  final Color              previewBg;
  final Color              previewKeyword;
  final Color              previewString;

  const EditorThemePresetMeta({
    required this.name,
    required this.preset,
    required this.state,
    required this.previewBg,
    required this.previewKeyword,
    required this.previewString,
  });

  static List<EditorThemePresetMeta> all() => [
    EditorThemePresetMeta(
      name: 'TradingView', preset: EditorThemePreset.tradingViewDark,
      state: EditorThemeState.fromPreset(EditorThemePreset.tradingViewDark),
      previewBg: _EditorPalette.grey950,
      previewKeyword: _EditorPalette.orange,
      previewString: _EditorPalette.green,
    ),
    EditorThemePresetMeta(
      name: 'VS Code', preset: EditorThemePreset.vscodeDark,
      state: EditorThemeState.fromPreset(EditorThemePreset.vscodeDark),
      previewBg: const Color(0xFF1E1E1E),
      previewKeyword: const Color(0xFF569CD6),
      previewString: const Color(0xFFCE9178),
    ),
    EditorThemePresetMeta(
      name: 'Dracula', preset: EditorThemePreset.draculaDark,
      state: EditorThemeState.fromPreset(EditorThemePreset.draculaDark),
      previewBg: const Color(0xFF282A36),
      previewKeyword: const Color(0xFFFF79C6),
      previewString: const Color(0xFFF1FA8C),
    ),
    EditorThemePresetMeta(
      name: 'Monokai', preset: EditorThemePreset.monokaiPro,
      state: EditorThemeState.fromPreset(EditorThemePreset.monokaiPro),
      previewBg: const Color(0xFF2D2A2E),
      previewKeyword: const Color(0xFFFF6188),
      previewString: const Color(0xFFFFD866),
    ),
    EditorThemePresetMeta(
      name: 'GitHub', preset: EditorThemePreset.githubDark,
      state: EditorThemeState.fromPreset(EditorThemePreset.githubDark),
      previewBg: const Color(0xFF0D1117),
      previewKeyword: const Color(0xFFFF7B72),
      previewString: const Color(0xFFA5D6FF),
    ),
    EditorThemePresetMeta(
      name: 'Light', preset: EditorThemePreset.light,
      state: EditorThemeState.fromPreset(EditorThemePreset.light),
      previewBg: const Color(0xFFFFFFFF),
      previewKeyword: const Color(0xFF0000FF),
      previewString: const Color(0xFFA31515),
    ),
  ];
}