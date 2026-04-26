// =============================================================================
// cloneable_overlay.dart
// Interface generik — semua overlay type wajib implement ini
//
// Path: frontend/lib/controller/cloneable_overlay.dart
// =============================================================================

/// Interface yang harus di-implement oleh setiap model overlay
/// supaya bisa di-copy, clone, dan reverse secara generik.
///
/// Contoh implementasi:
///   class RiskRatioOverlay implements CloneableOverlay<RiskRatioOverlay> { ... }
///   class FibonacciOverlay  implements CloneableOverlay<FibonacciOverlay>  { ... }
abstract class CloneableOverlay<T> {
  /// ID unik overlay — dipakai untuk hit-testing & identifikasi
  String get overlayId;

  /// Deep copy dari overlay ini (untuk clipboard internal)
  T copyWith();

  /// Buat duplikat dengan offset posisi kecil (TradingView clone style)
  ///
  /// [candleOffset] — geser horizontal dalam unit candle index (default: 8)
  /// [priceOffset]  — geser vertikal dalam unit harga (default: 0)
  T cloneWithOffset({
    required double candleOffset,
    required double priceOffset,
  });

  /// Flip: Buy ↔ Sell + mirror SL/TP terhadap Entry price
  T reverse();
}