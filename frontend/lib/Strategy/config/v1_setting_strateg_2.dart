// strategy_v1_settings.dart
//
// Representasi parameter PineScript ALGORITHM TRADING FINAL [EXXE.LAB]
// yang dikirim ke engine backend via base_signal_hook.dart.
//
// Scope file ini:
//   §1  StrategyV1Settings   — immutable data class
//   §2  default preset       — nilai default sesuai PineScript
//   §3  StrategyV1Settings.copyWith — untuk update parsial
//
// ⚠️  File ini TIDAK mengandung:
//     - HTTP / hook logic  → lihat base_signal_hook.dart
//     - ChangeNotifier     → state management ditangani di layer atas
//     - Parameter visual   → warna, channel, future projection, dll
//       (G4/G5/G6 PineScript murni visual, tidak mempengaruhi sinyal)
// ─────────────────────────────────────────────────────────────────────────────

// ══════════════════════════════════════════════════
// §1  StrategyV1Settings
//     Immutable. Setiap field 1:1 dengan input PineScript.
// ══════════════════════════════════════════════════

class StrategyV1Settings {
  // ── G1: ATR Trailing Stop ─────────────────────────────────────────────
  // PineScript: a = input.int(2, "Key Value (sensitivity)")
  final int atrKeyValue;

  // PineScript: c = input.int(1, "ATR Period")
  final int atrPeriod;

  // PineScript: useHA = input.bool(false, "Use Heikin Ashi Source")
  final bool useHA;

  // ── G2: Kalman Filter ─────────────────────────────────────────────────
  // PineScript: short_len = input.int(50, "Kalman Short Length")
  final int kalmanShort;

  // PineScript: long_len = input.int(150, "Kalman Long Length")
  final int kalmanLong;

  // ── G3: LRC Bands (SOP Filter) ───────────────────────────────────────
  // PineScript: window_bands = input.int(150, "Length")
  final int windowBands;

  // PineScript: devlen_b = input.float(3.0, "Deviation Linear Regression Bands")
  final double devlenBands;

  // ── G7: Trade Plotter ────────────────────────────────────────────────
  // PineScript: sl_lookback = input.int(15, "SOP SL Lookback")
  final int slLookback;

  // PineScript: rr_ratio = input.float(2.0, "Take Profit RR Ratio")
  final double rrRatio;

  const StrategyV1Settings({
    required this.atrKeyValue,
    required this.atrPeriod,
    required this.useHA,
    required this.kalmanShort,
    required this.kalmanLong,
    required this.windowBands,
    required this.devlenBands,
    required this.slLookback,
    required this.rrRatio,
  });

  // ── copyWith ──────────────────────────────────────────────────────────

  StrategyV1Settings copyWith({
    int? atrKeyValue,
    int? atrPeriod,
    bool? useHA,
    int? kalmanShort,
    int? kalmanLong,
    int? windowBands,
    double? devlenBands,
    int? slLookback,
    double? rrRatio,
  }) {
    return StrategyV1Settings(
      atrKeyValue:  atrKeyValue  ?? this.atrKeyValue,
      atrPeriod:    atrPeriod    ?? this.atrPeriod,
      useHA:        useHA        ?? this.useHA,
      kalmanShort:  kalmanShort  ?? this.kalmanShort,
      kalmanLong:   kalmanLong   ?? this.kalmanLong,
      windowBands:  windowBands  ?? this.windowBands,
      devlenBands:  devlenBands  ?? this.devlenBands,
      slLookback:   slLookback   ?? this.slLookback,
      rrRatio:      rrRatio      ?? this.rrRatio,
    );
  }

  @override
  String toString() =>
      'StrategyV1Settings('
      'atrKeyValue=$atrKeyValue, '
      'atrPeriod=$atrPeriod, '
      'useHA=$useHA, '
      'kalmanShort=$kalmanShort, '
      'kalmanLong=$kalmanLong, '
      'windowBands=$windowBands, '
      'devlenBands=$devlenBands, '
      'slLookback=$slLookback, '
      'rrRatio=$rrRatio)';
}

// ══════════════════════════════════════════════════
// §2  Preset Default
//     Nilai 1:1 dengan default input PineScript.
// ══════════════════════════════════════════════════

const StrategyV1Settings kDefaultSettings = StrategyV1Settings(
  atrKeyValue:  2,      // a
  atrPeriod:    1,      // c
  useHA:        false,  // useHA
  kalmanShort:  50,     // short_len
  kalmanLong:   150,    // long_len
  windowBands:  150,    // window_bands
  devlenBands:  3.0,    // devlen_b
  slLookback:   15,     // sl_lookback
  rrRatio:      2.0,    // rr_ratio
);