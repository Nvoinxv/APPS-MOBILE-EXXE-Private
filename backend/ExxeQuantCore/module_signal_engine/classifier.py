import numpy as np
from dataclasses import dataclass, field
from typing import List, Optional

from ExxeQuantCore.module_signal_engine.base_signal import BaseSignalResult
from ExxeQuantCore.module_lrc.quality_zones import SignalClass, ZoneLabel


# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

class SignalTier:
    """
    Probability tier labels for classified signals.

    Maps Pine Script visual output logic (plotshape color selection) to
    Python string constants used throughout the dispatch pipeline.

    Pine Script reference (Section 5, Plot A):
        plotshape(bright_Buy,  color=bright_buy_col)   -> BRIGHT
        plotshape(bright_Sell, color=bright_sell_col)  -> BRIGHT
        plotshape(dark_Buy,    color=dark_buy_col)     -> DARK
        plotshape(dark_Sell,   color=dark_sell_col)    -> DARK
    """
    BRIGHT = "bright"   # High probability — signal aligned with LRC zone
    DARK   = "dark"     # Low probability  — counter-zone, but still active
    NONE   = "none"     # No signal this bar


class Direction:
    """
    Trade direction constants. Mirrors Pine TradeSetup.direction values.

    Pine Script:
        direction = 1   -> Long
        direction = -1  -> Short
    """
    LONG  =  1
    SHORT = -1
    FLAT  =  0


class FilterMode:
    """
    Execution filter mode for the Classifier.

    Controls which signal tiers are passed through to alert_dispatcher.

    Pine Script reference (Section 4, Historical Simulation):
        "Executes BOTH Bright and Dark signals"
        -> FilterMode.ALL replicates this Pine behavior exactly.

    FilterMode.BRIGHT_ONLY:
        Only passes bright_Buy and bright_Sell signals through.
        Drops dark signals entirely. Higher quality, fewer signals.

    FilterMode.ALL:
        Passes both bright AND dark signals through.
        Replicates Pine default: base_Buy / base_Sell executed regardless.
        dark signals are tagged with lower confidence in the output.
    """
    ALL          = "all"           # bright + dark (Pine default)
    BRIGHT_ONLY  = "bright_only"   # high probability only


# ─────────────────────────────────────────────────────────────────────────────
# Per-bar signal container
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class ClassifiedSignal:
    """
    Single classified signal event for one bar.

    Produced by SignalClassifier.classify() for each bar where a signal fires.
    Contains everything needed by alert_dispatcher to emit an alert or
    simulate a trade.

    Attribute mapping to Pine Script:

        bar_index     -> bar_index
        direction     -> Direction.LONG (1) or Direction.SHORT (-1)
        tier          -> SignalTier.BRIGHT or SignalTier.DARK
        signal_class  -> SignalClass constant string (e.g. "bright_buy")

        close         -> close[bar_index]  (entry price reference)
        mid_bands     -> mid_bands[bar_index]
        upper_bands   -> upper_bands[bar_index]
        lower_bands   -> lower_bands[bar_index]

        is_discount   -> isInDiscountArea at this bar
        is_premium    -> isInPremiumArea at this bar
        zone_label    -> ZoneLabel string at this bar

        regime        -> candle_col_kalman at this bar
                         ("strong_up" / "strong_down" / "neutral")
        trend_up      -> trend_up boolean at this bar

        confidence    -> float [0.0 - 1.0]
                         Computed by _compute_confidence()
                         Not in Pine Script; added for Python dispatch logic.
    """
    bar_index:    int
    direction:    int            # Direction.LONG or Direction.SHORT
    tier:         str            # SignalTier.BRIGHT or SignalTier.DARK
    signal_class: str            # SignalClass constant

    close:        float
    mid_bands:    float
    upper_bands:  float
    lower_bands:  float

    is_discount:  bool
    is_premium:   bool
    zone_label:   str

    regime:       str            # candle_col_kalman value at this bar
    trend_up:     bool

    confidence:   float = field(default=0.0)

    # ── Derived helpers ───────────────────────────────────────────────────────

    @property
    def is_bright(self) -> bool:
        return self.tier == SignalTier.BRIGHT

    @property
    def is_dark(self) -> bool:
        return self.tier == SignalTier.DARK

    @property
    def is_long(self) -> bool:
        return self.direction == Direction.LONG

    @property
    def is_short(self) -> bool:
        return self.direction == Direction.SHORT

    @property
    def direction_str(self) -> str:
        return "LONG" if self.is_long else "SHORT"

    @property
    def band_position(self) -> Optional[float]:
        """
        Normalized position of close within the band [0.0 - 1.0].
        Replicates Pine's b_c_heatmap calculation:
            b_c_heatmap = (close - lower_bands) / (upper_bands - lower_bands)
            clamped to [0, 1]

        0.0 = at lower band (deep discount)
        0.5 = at mid
        1.0 = at upper band (deep premium)
        """
        band_range = self.upper_bands - self.lower_bands
        if band_range == 0 or np.isnan(band_range):
            return None
        raw = (self.close - self.lower_bands) / band_range
        return float(np.clip(raw, 0.0, 1.0))

    def __repr__(self) -> str:
        bp = self.band_position
        bp_str = f"{bp:.3f}" if bp is not None else "n/a"
        return (
            f"ClassifiedSignal("
            f"bar={self.bar_index}, "
            f"{self.direction_str}, "
            f"tier={self.tier.upper()}, "
            f"class={self.signal_class}, "
            f"conf={self.confidence:.3f}, "
            f"zone={self.zone_label}, "
            f"band_pos={bp_str}, "
            f"regime={self.regime}"
            f")"
        )


# ─────────────────────────────────────────────────────────────────────────────
# Classifier result container
# ─────────────────────────────────────────────────────────────────────────────

class ClassifierResult:
    """
    Full output of SignalClassifier.classify().

    Holds the original BaseSignalResult reference plus all classified
    signal events as ClassifiedSignal objects. Downstream modules
    (alert_dispatcher.py) consume this object directly.

    Attributes
    ----------
    base          : BaseSignalResult  - full pipeline arrays from base_signal
    signals       : list of ClassifiedSignal  - all fired signal events
    filter_mode   : str - FilterMode applied (determines which signals included)

    Convenience views:
        bright_signals  : only BRIGHT tier signals
        dark_signals    : only DARK tier signals
        long_signals    : all LONG direction signals
        short_signals   : all SHORT direction signals
    """

    def __init__(
        self,
        base:        BaseSignalResult,
        signals:     List[ClassifiedSignal],
        filter_mode: str,
    ):
        self.base        = base
        self.signals     = signals
        self.filter_mode = filter_mode

    # ── Filtered views ────────────────────────────────────────────────────────

    @property
    def bright_signals(self) -> List[ClassifiedSignal]:
        return [s for s in self.signals if s.is_bright]

    @property
    def dark_signals(self) -> List[ClassifiedSignal]:
        return [s for s in self.signals if s.is_dark]

    @property
    def long_signals(self) -> List[ClassifiedSignal]:
        return [s for s in self.signals if s.is_long]

    @property
    def short_signals(self) -> List[ClassifiedSignal]:
        return [s for s in self.signals if s.is_short]

    @property
    def bright_long(self) -> List[ClassifiedSignal]:
        return [s for s in self.signals if s.is_bright and s.is_long]

    @property
    def bright_short(self) -> List[ClassifiedSignal]:
        return [s for s in self.signals if s.is_bright and s.is_short]

    @property
    def dark_long(self) -> List[ClassifiedSignal]:
        return [s for s in self.signals if s.is_dark and s.is_long]

    @property
    def dark_short(self) -> List[ClassifiedSignal]:
        return [s for s in self.signals if s.is_dark and s.is_short]

    # ── Summary ───────────────────────────────────────────────────────────────

    def summary(self) -> dict:
        """
        Returns scalar stats matching Pine's visual output counts.

        Pine Script reference (Plot A):
            plotshape(bright_Buy)  -> len(bright_long)
            plotshape(bright_Sell) -> len(bright_short)
            plotshape(dark_Buy)    -> len(dark_long)
            plotshape(dark_Sell)   -> len(dark_short)
        """
        total      = len(self.signals)
        n_bright   = len(self.bright_signals)
        n_dark     = len(self.dark_signals)
        n_bl       = len(self.bright_long)
        n_bs       = len(self.bright_short)
        n_dl       = len(self.dark_long)
        n_ds       = len(self.dark_short)

        avg_conf_bright = (
            float(np.mean([s.confidence for s in self.bright_signals]))
            if self.bright_signals else 0.0
        )
        avg_conf_dark = (
            float(np.mean([s.confidence for s in self.dark_signals]))
            if self.dark_signals else 0.0
        )

        return {
            "filter_mode":      self.filter_mode,
            "total_signals":    total,
            "bright_total":     n_bright,
            "dark_total":       n_dark,
            "bright_long":      n_bl,
            "bright_short":     n_bs,
            "dark_long":        n_dl,
            "dark_short":       n_ds,
            "avg_conf_bright":  round(avg_conf_bright, 4),
            "avg_conf_dark":    round(avg_conf_dark, 4),
        }


# ─────────────────────────────────────────────────────────────────────────────
# Main Classifier
# ─────────────────────────────────────────────────────────────────────────────

class SignalClassifier:
    """
    Signal Classifier — Module D, Step 2.

    Consumes a BaseSignalResult (output of BaseSignalEngine.run()) and
    converts the raw bright/dark boolean arrays into a structured list of
    ClassifiedSignal objects with full per-bar context and confidence scores.

    ── Role in the pipeline ────────────────────────────────────────────────

        BaseSignalEngine.run()
            → BaseSignalResult  (arrays of booleans + band values)
                         ↓
            SignalClassifier.classify()
            → ClassifierResult  (list of ClassifiedSignal objects)
                         ↓
            AlertDispatcher.dispatch()
            → alerts / trade events (alert_dispatcher.py)

    ── What this class does vs what base_signal already did ───────────────

        base_signal.py already computed:
            - bright_buy, bright_sell, dark_buy, dark_sell (bool arrays)
            - signal_class (string label per bar)
            - All band values and zone booleans

        classifier.py adds on top of that:
            1. Converts flat arrays into ClassifiedSignal objects
               (one object per fired signal bar)
            2. Computes confidence score per signal based on:
               - band_position (how deep in discount/premium zone)
               - regime strength (strong_up/strong_down vs neutral)
            3. Applies FilterMode:
               - FilterMode.ALL         -> includes both bright and dark
               - FilterMode.BRIGHT_ONLY -> drops dark signals
            4. Provides structured views: bright_signals, dark_signals, etc.

    ── Pine Script reference ────────────────────────────────────────────────

        Pine Calculation D, Section 2 + 3:
            isInDiscountArea = close <= mid_bands
            isInPremiumArea  = close >= mid_bands
            bright_Buy  = base_Buy  and isInDiscountArea
            bright_Sell = base_Sell and isInPremiumArea
            dark_Buy    = base_Buy  and not isInDiscountArea
            dark_Sell   = base_Sell and not isInPremiumArea

        Pine Plot A:
            plotshape(bright_Buy,  color=bright_buy_col)   -> BRIGHT LONG
            plotshape(bright_Sell, color=bright_sell_col)  -> BRIGHT SHORT
            plotshape(dark_Buy,    color=dark_buy_col)     -> DARK LONG
            plotshape(dark_Sell,   color=dark_sell_col)    -> DARK SHORT

        Pine Historical Simulation note:
            "Executes BOTH Bright and Dark signals"
            -> FilterMode.ALL is the default, replicating Pine exactly.

    Parameters
    ----------
    filter_mode : str
        FilterMode.ALL (default)         — pass bright + dark signals through
        FilterMode.BRIGHT_ONLY           — only pass bright signals through
    """

    def __init__(self, filter_mode: str = FilterMode.ALL):
        if filter_mode not in (FilterMode.ALL, FilterMode.BRIGHT_ONLY):
            raise ValueError(
                f"filter_mode must be FilterMode.ALL or FilterMode.BRIGHT_ONLY, "
                f"got: '{filter_mode}'"
            )
        self.filter_mode = filter_mode

    # ── Confidence scoring ────────────────────────────────────────────────────

    def _compute_confidence(
        self,
        tier:         str,
        direction:    int,
        band_pos:     Optional[float],
        regime:       str,
    ) -> float:
        """
        Computes a [0.0 - 1.0] confidence score for a signal.

        Not present in Pine Script. Added to give alert_dispatcher a
        quantitative measure of signal quality beyond BRIGHT / DARK.

        Scoring logic (two components, averaged):

        ── Component 1: Zone Depth Score (0.0 - 1.0) ─────────────────────
            Measures how far into the discount/premium zone price is.
            Deeper = higher confidence.

            For LONG signals (discount zone, band_pos <= 0.5):
                score = 1.0 - (band_pos / 0.5)
                band_pos = 0.0  → score = 1.0  (at lower band, deep discount)
                band_pos = 0.5  → score = 0.0  (at mid, boundary)

            For SHORT signals (premium zone, band_pos >= 0.5):
                score = (band_pos - 0.5) / 0.5
                band_pos = 1.0  → score = 1.0  (at upper band, deep premium)
                band_pos = 0.5  → score = 0.0  (at mid, boundary)

            For DARK signals (counter-zone):
                Score is inverted and scaled down (0.0 - 0.4 max)
                to reflect that dark signals have inherently lower confidence.

        ── Component 2: Regime Strength Score (0.0 or 1.0) ───────────────
            Kalman regime at the signal bar.

            "strong_up"   + LONG  → 1.0  (regime aligned with direction)
            "strong_down" + SHORT → 1.0  (regime aligned with direction)
            "neutral"             → 0.5  (mixed regime)
            Mismatched            → 0.0  (regime conflicts with direction)

        Final score = mean(zone_depth_score, regime_strength_score)
        Clipped to [0.0, 1.0].
        """

        # ── Component 2: regime score ─────────────────────────────────────
        from ExxeQuantCore.module_kalman.trend_state import TrendState
        if regime == TrendState.STRONG_UP and direction == Direction.LONG:
            regime_score = 1.0
        elif regime == TrendState.STRONG_DOWN and direction == Direction.SHORT:
            regime_score = 1.0
        elif regime == TrendState.NEUTRAL:
            regime_score = 0.5
        else:
            # Regime mismatched (shouldn't happen for base signals, but guard)
            regime_score = 0.0

        # ── Component 1: zone depth score ────────────────────────────────
        if band_pos is None:
            zone_score = 0.5  # no band data, neutral
        elif tier == SignalTier.BRIGHT:
            if direction == Direction.LONG:
                # LONG in discount: band_pos in [0, 0.5] ideally
                # deeper discount (lower band_pos) = higher score
                zone_score = float(np.clip(1.0 - (band_pos / 0.5), 0.0, 1.0))
            else:
                # SHORT in premium: band_pos in [0.5, 1.0] ideally
                # deeper premium (higher band_pos) = higher score
                zone_score = float(np.clip((band_pos - 0.5) / 0.5, 0.0, 1.0))
        else:
            # DARK signal: counter-zone, capped at 0.4 max confidence
            if direction == Direction.LONG:
                # LONG in premium zone (counter-zone): band_pos > 0.5
                # deeper into premium = worse for a long = lower confidence
                zone_score = float(np.clip((1.0 - band_pos) * 0.8, 0.0, 0.4))
            else:
                # SHORT in discount zone (counter-zone): band_pos < 0.5
                # deeper into discount = worse for a short = lower confidence
                zone_score = float(np.clip(band_pos * 0.8, 0.0, 0.4))

        # Final: average of two components
        confidence = (zone_score + regime_score) / 2.0
        return float(np.clip(confidence, 0.0, 1.0))

    # ── Signal extraction ─────────────────────────────────────────────────────

    def _extract_signal(
        self,
        bar_index:  int,
        result:     BaseSignalResult,
        direction:  int,
        tier:       str,
        sig_class:  str,
    ) -> ClassifiedSignal:
        """
        Builds a ClassifiedSignal object for a single bar.

        Pulls all per-bar context from BaseSignalResult arrays and
        computes confidence score.
        """
        # close is passed into classify() and stored temporarily on self._close
        close       = float(self._close[bar_index])
        mid         = float(result.mid_bands[bar_index])
        upper       = float(result.upper_bands[bar_index])
        lower       = float(result.lower_bands[bar_index])
        is_discount = bool(result.is_discount[bar_index])
        is_premium  = bool(result.is_premium[bar_index])
        regime      = str(result.candle_col_kalman[bar_index])
        trend_up    = bool(result.trend_up[bar_index])

        # Zone label
        if close < mid:
            zone_label = ZoneLabel.DISCOUNT
        elif close > mid:
            zone_label = ZoneLabel.PREMIUM
        else:
            zone_label = ZoneLabel.MID

        # Band position (Pine's b_c_heatmap, clamped [0, 1])
        band_range = upper - lower
        band_pos   = float(np.clip((close - lower) / band_range, 0.0, 1.0)) \
                     if band_range > 0 else None

        confidence = self._compute_confidence(tier, direction, band_pos, regime)

        return ClassifiedSignal(
            bar_index   = bar_index,
            direction   = direction,
            tier        = tier,
            signal_class= sig_class,
            close       = close,
            mid_bands   = mid,
            upper_bands = upper,
            lower_bands = lower,
            is_discount = is_discount,
            is_premium  = is_premium,
            zone_label  = zone_label,
            regime      = regime,
            trend_up    = trend_up,
            confidence  = confidence,
        )

    # ── Public API ────────────────────────────────────────────────────────────

    def classify(
        self,
        result: BaseSignalResult,
        close:  np.ndarray,
    ) -> ClassifierResult:
        """
        Classifies all signal bars from a BaseSignalResult into
        a structured list of ClassifiedSignal objects.

        ── Pine Script mapping ──────────────────────────────────────────────

            For each bar where a signal fires:

            bright_buy[i]  = True → ClassifiedSignal(direction=LONG,  tier=BRIGHT)
            bright_sell[i] = True → ClassifiedSignal(direction=SHORT, tier=BRIGHT)
            dark_buy[i]    = True → ClassifiedSignal(direction=LONG,  tier=DARK)
            dark_sell[i]   = True → ClassifiedSignal(direction=SHORT, tier=DARK)

            Priority (Pine only fires one signal per bar):
                bright_buy > bright_sell > dark_buy > dark_sell

            FilterMode.ALL          → all four types included
            FilterMode.BRIGHT_ONLY  → only bright_buy + bright_sell included

        Parameters
        ----------
        result : BaseSignalResult  - output of BaseSignalEngine.run()
        close  : np.ndarray        - close price array (same bars as result)

        Returns
        -------
        ClassifierResult  containing list[ClassifiedSignal] + summary stats
        """
        if len(close) != len(result.bright_buy):
            raise ValueError(
                f"close length {len(close)} does not match result length "
                f"{len(result.bright_buy)}"
            )

        # Temporarily store close for use in _extract_signal()
        self._close = close

        signals: List[ClassifiedSignal] = []
        n = len(close)

        for i in range(n):
            # ── Priority ordering replicates Pine's plotshape order ──────────
            # Pine plots bright first, then dark. No bar fires two signals.

            if result.bright_buy[i]:
                signals.append(self._extract_signal(
                    bar_index = i,
                    result    = result,
                    direction = Direction.LONG,
                    tier      = SignalTier.BRIGHT,
                    sig_class = SignalClass.BRIGHT_BUY,
                ))

            elif result.bright_sell[i]:
                signals.append(self._extract_signal(
                    bar_index = i,
                    result    = result,
                    direction = Direction.SHORT,
                    tier      = SignalTier.BRIGHT,
                    sig_class = SignalClass.BRIGHT_SELL,
                ))

            elif result.dark_buy[i] and self.filter_mode == FilterMode.ALL:
                # Pine: "Low Prob (Dark) — Counter LRC, but still executed"
                signals.append(self._extract_signal(
                    bar_index = i,
                    result    = result,
                    direction = Direction.LONG,
                    tier      = SignalTier.DARK,
                    sig_class = SignalClass.DARK_BUY,
                ))

            elif result.dark_sell[i] and self.filter_mode == FilterMode.ALL:
                signals.append(self._extract_signal(
                    bar_index = i,
                    result    = result,
                    direction = Direction.SHORT,
                    tier      = SignalTier.DARK,
                    sig_class = SignalClass.DARK_SELL,
                ))

        # Clean up temporary reference
        self._close = None

        return ClassifierResult(
            base        = result,
            signals     = signals,
            filter_mode = self.filter_mode,
        )


# ─────────────────────────────────────────────────────────────────────────────
# Standalone test
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import sys
    import os
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

    from ExxeQuantCore.module_signal_engine.base_signal import BaseSignalEngine

    np.random.seed(42)
    n = 300

    close = 100 + np.cumsum(np.random.randn(n) * 0.5)
    high  = close + np.abs(np.random.randn(n) * 0.3)
    low   = close - np.abs(np.random.randn(n) * 0.3)
    src   = close

    # ── Step 1: Run full A + B + C pipeline ──────────────────────────────────
    engine = BaseSignalEngine(
        sensitivity = 2,
        atr_period  = 6,
        short_len   = 50,
        long_len    = 150,
        lrc_window  = 50,
        lrc_devlen  = 3.0,
    )
    base_result = engine.run(src=src, high=high, low=low, close=close)

    # ── Step 2: Run Classifier (FilterMode.ALL — Pine default) ───────────────
    classifier_all = SignalClassifier(filter_mode=FilterMode.ALL)
    result_all     = classifier_all.classify(result=base_result, close=close)

    # ── Step 3: Run Classifier (BRIGHT_ONLY — stricter mode) ─────────────────
    classifier_bright = SignalClassifier(filter_mode=FilterMode.BRIGHT_ONLY)
    result_bright     = classifier_bright.classify(result=base_result, close=close)

    # ── Print all classified signals ──────────────────────────────────────────
    print("SignalClassifier — Classified Output (FilterMode.ALL)")
    print("=" * 100)
    print(
        f"{'Bar':>4} | {'Dir':>5} | {'Tier':>6} | {'Class':>11} | "
        f"{'Conf':>5} | {'BandPos':>7} | {'Zone':>8} | {'Regime':>11} | Close"
    )
    print("-" * 100)

    for s in result_all.signals:
        bp = s.band_position
        bp_str = f"{bp:.3f}" if bp is not None else "  n/a"
        tier_tag  = "★" if s.is_bright else "◆"
        print(
            f"{s.bar_index:>4} | {s.direction_str:>5} | "
            f"{tier_tag} {s.tier:>5} | {s.signal_class:>11} | "
            f"{s.confidence:>5.3f} | {bp_str:>7} | {s.zone_label:>8} | "
            f"{s.regime:>11} | {s.close:.4f}"
        )

    # ── Summary comparison: ALL vs BRIGHT_ONLY ────────────────────────────────
    print()
    print("=" * 65)
    print("CLASSIFIER SUMMARY")
    print("=" * 65)

    for label, res in [("FilterMode.ALL (Pine default)", result_all),
                        ("FilterMode.BRIGHT_ONLY",        result_bright)]:
        s = res.summary()
        print(f"\n  [{label}]")
        print(f"    Total signals    : {s['total_signals']}")
        print(f"    Bright LONG      : {s['bright_long']}   (plotshape bright_Buy)")
        print(f"    Bright SHORT     : {s['bright_short']}   (plotshape bright_Sell)")
        print(f"    Dark   LONG      : {s['dark_long']}   (plotshape dark_Buy)")
        print(f"    Dark   SHORT     : {s['dark_short']}   (plotshape dark_Sell)")
        print(f"    Avg conf BRIGHT  : {s['avg_conf_bright']:.4f}")
        print(f"    Avg conf DARK    : {s['avg_conf_dark']:.4f}")

    # ── Show each ClassifiedSignal repr ──────────────────────────────────────
    print()
    print("=" * 65)
    print("ClassifiedSignal objects (ALL mode):")
    print("=" * 65)
    for s in result_all.signals:
        print(f"  {repr(s)}")

    # ── Pine variable mapping reminder ────────────────────────────────────────
    print()
    print("Pine plotshape → ClassifiedSignal mapping:")
    print("  plotshape(bright_Buy)  → tier=BRIGHT, direction=LONG")
    print("  plotshape(bright_Sell) → tier=BRIGHT, direction=SHORT")
    print("  plotshape(dark_Buy)    → tier=DARK,   direction=LONG")
    print("  plotshape(dark_Sell)   → tier=DARK,   direction=SHORT")
    print()
    print("Next step → alert_dispatcher.py")
    print("  Receives ClassifierResult and emits alerts / trade events.")