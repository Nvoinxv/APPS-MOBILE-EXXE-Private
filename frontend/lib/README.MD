modular/
├── README.md                           # Dokumentasi ini
│
├── screens/
│   └── crypto_trading_view_modular.dart  # Main screen (200 lines)
│
├── widgets/
│   ├── chart/
│   │   ├── interactive_candlestick_chart.dart  # Chart renderer
│   │   ├── price_header.dart                    # Price info header
│   │   ├── candle_info_panel.dart               # OHLCV panel
│   │   └── volume_section.dart                  # Volume bars
│   │
│   ├── controls/
│   │   ├── ticker_selector.dart        # Coin dropdown
│   │   ├── interval_selector.dart      # Timeframe selector
│   │   ├── chart_controls.dart         # Bottom controls
│   │   └── risk_ratio_button.dart      # R:R button
│   │
│   └── dialogs/
│       ├── style_settings_sheet.dart   # Theme picker
│       └── context_menus.dart          # Right-click menus
│
├── models/
│   ├── chart_state.dart                # State management
│   └── chart_theme.dart                # Theme presets
│
├── controllers/
│   └── chart_controller.dart           # Business logic (optional)
│
└── utils/
    ├── constants.dart                  # App constants
    └── helpers.dart                    # Helper functions