import numpy as np
from ExxeQuantCore.module_atr_volatilitas.atr_calculation import ATRCalculator
from ExxeQuantCore.module_atr_volatilitas.trailing_stop  import ATRTrailingStop
from ExxeQuantCore.module_atr_volatilitas.signal_trigger import SignalTrigger
from ExxeQuantCore.module_kalman.trend_state import TrendState
from ExxeQuantCore.module_lrc.quality_zones import QualityZones, SignalClass

class BaseSignalResult:
    __slots__ = (
        # Module A
        "trailing_stop", "atr_buy", "atr_sell",
        # Module B
        "short_kalman", "long_kalman", "trend_up",
        "candle_col_kalman", "is_strong_up", "is_strong_down",
        # A + B gate
        "base_buy", "base_sell",
        # Module C
        "mid_bands", "upper_bands", "lower_bands",
        "is_discount", "is_premium",
        "bright_buy", "bright_sell",
        "dark_buy", "dark_sell",
        "signal_class",
    )

    def __init__(
        self,
        trailing_stop:     np.ndarray,
        atr_buy:           np.ndarray,
        atr_sell:          np.ndarray,
        short_kalman:      np.ndarray,
        long_kalman:       np.ndarray,
        trend_up:          np.ndarray,
        candle_col_kalman: np.ndarray,
        is_strong_up:      np.ndarray,
        is_strong_down:    np.ndarray,
        base_buy:          np.ndarray,
        base_sell:         np.ndarray,
        mid_bands:         np.ndarray,
        upper_bands:       np.ndarray,
        lower_bands:       np.ndarray,
        is_discount:       np.ndarray,
        is_premium:        np.ndarray,
        bright_buy:        np.ndarray,
        bright_sell:       np.ndarray,
        dark_buy:          np.ndarray,
        dark_sell:         np.ndarray,
        signal_class:      np.ndarray,
    ):
        self.trailing_stop     = trailing_stop
        self.atr_buy           = atr_buy
        self.atr_sell          = atr_sell
        self.short_kalman      = short_kalman
        self.long_kalman       = long_kalman
        self.trend_up          = trend_up
        self.candle_col_kalman = candle_col_kalman
        self.is_strong_up      = is_strong_up
        self.is_strong_down    = is_strong_down
        self.base_buy          = base_buy
        self.base_sell         = base_sell
        self.mid_bands         = mid_bands
        self.upper_bands       = upper_bands
        self.lower_bands       = lower_bands
        self.is_discount       = is_discount
        self.is_premium        = is_premium
        self.bright_buy        = bright_buy
        self.bright_sell       = bright_sell
        self.dark_buy          = dark_buy
        self.dark_sell         = dark_sell
        self.signal_class      = signal_class

    def summary(self) -> dict:
        """Scalar stats for quick pipeline inspection."""
        valid = ~np.isnan(self.trailing_stop)
        return {
            "valid_bars":       int(np.sum(valid)),
            # Module A
            "atr_buy_count":    int(np.sum(self.atr_buy)),
            "atr_sell_count":   int(np.sum(self.atr_sell)),
            # Module B gate
            "strong_up_bars":   int(np.sum(self.is_strong_up)),
            "strong_dn_bars":   int(np.sum(self.is_strong_down)),
            # A + B
            "base_buy_count":   int(np.sum(self.base_buy)),
            "base_sell_count":  int(np.sum(self.base_sell)),
            # Module C final
            "bright_buy_count":  int(np.sum(self.bright_buy)),
            "bright_sell_count": int(np.sum(self.bright_sell)),
            "dark_buy_count":    int(np.sum(self.dark_buy)),
            "dark_sell_count":   int(np.sum(self.dark_sell)),
        }


class BaseSignalEngine:

    def __init__(
        self,
        sensitivity: int   = 2,
        atr_period:  int   = 6,
        short_len:   int   = 50,
        long_len:    int   = 150,
        lrc_window:  int   = 150,
        lrc_devlen:  float = 3.0,
    ):
        self.sensitivity = sensitivity
        self.atr_period  = atr_period
        self.short_len   = short_len
        self.long_len    = long_len
        self.lrc_window  = lrc_window
        self.lrc_devlen  = lrc_devlen

        # ── Module A ─────────────────────────────────────────────────────────
        self._atr_calc      = ATRCalculator(period=atr_period)
        self._trailing_stop = ATRTrailingStop(sensitivity=sensitivity, atr_period=atr_period)
        self._signal        = SignalTrigger()

        # ── Module B ─────────────────────────────────────────────────────────
        self._trend_state = TrendState(short_len=short_len, long_len=long_len)

        # ── Module C ─────────────────────────────────────────────────────────
        self._quality_zones = QualityZones(window=lrc_window, devlen=lrc_devlen)

    # ── Internal pipeline steps ───────────────────────────────────────────────

    def _run_module_a(self, src: np.ndarray, high: np.ndarray, low: np.ndarray) -> dict:
        """
        Module A: ATR Trailing Stop + crossover signal generation.

        Pine:
            xATR  = ta.atr(c)
            nLoss = a * xATR
            xATRTrailingStop := ...ratchet logic...
            ema1  = ta.ema(src, 1)
            above = ta.crossover(ema1, xATRTrailingStop)
            below = ta.crossover(xATRTrailingStop, ema1)
            buy   = src > xATRTrailingStop and above
            sell  = src < xATRTrailingStop and below
        """
        trailing_stop = self._trailing_stop.compute(high, low, src)
        sig           = self._signal.compute(src, trailing_stop)
        return {
            "trailing_stop": trailing_stop,
            "buy":           sig["buy"],
            "sell":          sig["sell"],
        }

    def _run_module_b(self, close: np.ndarray) -> dict:
        """
        Module B: Kalman dual-horizon + trend classification.

        Pine:
            short_kalman = kalman_filter(close, short_len)
            long_kalman  = kalman_filter(close, long_len)
            candle_col_kalman = ...3-state ternary...
            isStrongUp   = candle_col_kalman == upper_col
            isStrongDown = candle_col_kalman == lower_col
        """
        ts             = self._trend_state.compute(close)
        ccol           = ts["candle_col_kalman"]
        is_strong_up   = self._trend_state.is_strong_up(ccol)
        is_strong_down = self._trend_state.is_strong_down(ccol)
        return {
            "short_kalman":      ts["short_kalman"],
            "long_kalman":       ts["long_kalman"],
            "trend_up":          ts["trend_up"],
            "candle_col_kalman": ccol,
            "is_strong_up":      is_strong_up,
            "is_strong_down":    is_strong_down,
        }

    def _gate_a_with_b(self, a: dict, b: dict) -> tuple:
        """
        A + B gate: applies Kalman regime confirmation to ATR raw signals.

        Pine Calculation D, Section 1:
            bool base_Buy  = buy and isStrongUp
            bool base_Sell = sell and isStrongDown

        Returns (base_buy, base_sell) bool arrays.
        """
        base_buy  = a["buy"]  & b["is_strong_up"]
        base_sell = a["sell"] & b["is_strong_down"]
        return base_buy, base_sell

    def _run_module_c(
        self,
        close:     np.ndarray,
        high:      np.ndarray,
        low:       np.ndarray,
        base_buy:  np.ndarray,
        base_sell: np.ndarray,
    ) -> dict:
        """
        Module C: LRC quality zone filter.

        Pine Calculation D, Section 2 + 3:
            isInDiscountArea = close <= mid_bands
            isInPremiumArea  = close >= mid_bands
            bright_Buy  = base_Buy  and isInDiscountArea
            bright_Sell = base_Sell and isInPremiumArea
            dark_Buy    = base_Buy  and not isInDiscountArea
            dark_Sell   = base_Sell and not isInPremiumArea
        """
        return self._quality_zones.classify_signals(
            close=close, high=high, low=low,
            base_buy=base_buy, base_sell=base_sell,
        )

    # ── Public API ────────────────────────────────────────────────────────────

    def run(
        self,
        src:   np.ndarray,
        high:  np.ndarray,
        low:   np.ndarray,
        close: np.ndarray,
    ) -> BaseSignalResult:
        """
        Runs the full A → B → C pipeline and returns a BaseSignalResult.

        Parameters
        ----------
        src   : np.ndarray - ATR source (close, or HA close if useHA=True)
        high  : np.ndarray - high prices
        low   : np.ndarray - low prices
        close : np.ndarray - close prices (Kalman always uses real close)

        Returns
        -------
        BaseSignalResult with ALL intermediate + final arrays populated
        """
        # ── Step 1: ATR signal generation ────────────────────────────────────
        a = self._run_module_a(src, high, low)

        # ── Step 2: Kalman trend classification ──────────────────────────────
        b = self._run_module_b(close)

        # ── Step 3: Kalman-gated base signals ────────────────────────────────
        base_buy, base_sell = self._gate_a_with_b(a, b)

        # ── Step 4: LRC quality zone filter ──────────────────────────────────
        c = self._run_module_c(close, high, low, base_buy, base_sell)

        return BaseSignalResult(
            # Module A
            trailing_stop     = a["trailing_stop"],
            atr_buy           = a["buy"],
            atr_sell          = a["sell"],
            # Module B
            short_kalman      = b["short_kalman"],
            long_kalman       = b["long_kalman"],
            trend_up          = b["trend_up"],
            candle_col_kalman = b["candle_col_kalman"],
            is_strong_up      = b["is_strong_up"],
            is_strong_down    = b["is_strong_down"],
            # A + B
            base_buy          = base_buy,
            base_sell         = base_sell,
            # Module C
            mid_bands         = c["mid"],
            upper_bands       = c["upper"],
            lower_bands       = c["lower"],
            is_discount       = c["is_discount"],
            is_premium        = c["is_premium"],
            bright_buy        = c["bright_buy"],
            bright_sell       = c["bright_sell"],
            dark_buy          = c["dark_buy"],
            dark_sell         = c["dark_sell"],
            signal_class      = c["signal_class"],
        )

    # ── Accessor helpers ──────────────────────────────────────────────────────

    def get_atr_calculator(self)  -> ATRCalculator:  return self._atr_calc
    def get_trailing_stop(self)   -> ATRTrailingStop: return self._trailing_stop
    def get_signal_trigger(self)  -> SignalTrigger:   return self._signal
    def get_trend_state(self)     -> TrendState:      return self._trend_state
    def get_quality_zones(self)   -> QualityZones:    return self._quality_zones


# ─────────────────────────────────────────────────────────────────────────────
# Standalone test
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import sys
    import os
    # Allow running directly: python base_signal.py
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

    np.random.seed(42)
    n = 250

    close = 100 + np.cumsum(np.random.randn(n) * 0.5)
    high  = close + np.abs(np.random.randn(n) * 0.3)
    low   = close - np.abs(np.random.randn(n) * 0.3)
    src   = close  # useHA = False

    engine = BaseSignalEngine(
        sensitivity = 2,
        atr_period  = 6,
        short_len   = 50,
        long_len    = 150,
        lrc_window  = 50,   # smaller window for test visibility
        lrc_devlen  = 3.0,
    )

    result = engine.run(src=src, high=high, low=low, close=close)

    # ── Print only signal bars + every 50th for context ──────────────────────
    print("BaseSignalEngine — Full ATR + Kalman + LRC Pipeline")
    print("=" * 105)
    print(
        f"{'Bar':>4} | {'Close':>8} | {'Stop':>8} | "
        f"{'Regime':>11} | {'Zone':>8} | "
        f"{'base_B':>6} | {'base_S':>6} | Signal"
    )
    print("-" * 105)

    for i in range(n):
        has_signal = (
            result.bright_buy[i] or result.bright_sell[i] or
            result.dark_buy[i]   or result.dark_sell[i]   or
            result.atr_buy[i]    or result.atr_sell[i]
        )
        if not (has_signal or i % 50 == 0):
            continue

        stop_str   = f"{result.trailing_stop[i]:.3f}" if not np.isnan(result.trailing_stop[i]) else "nan"
        regime     = result.candle_col_kalman[i]
        zone_lbl   = "discount" if result.is_discount[i] else ("premium" if result.is_premium[i] else "mid")
        sc         = result.signal_class[i]

        tag = ""
        if sc == SignalClass.BRIGHT_BUY:    tag = "  ★ BRIGHT BUY"
        elif sc == SignalClass.BRIGHT_SELL: tag = "  ★ BRIGHT SELL"
        elif sc == SignalClass.DARK_BUY:    tag = "  ◆ dark buy"
        elif sc == SignalClass.DARK_SELL:   tag = "  ◆ dark sell"
        elif result.atr_buy[i]:             tag = "  (atr_buy → blocked by Kalman)"
        elif result.atr_sell[i]:            tag = "  (atr_sell → blocked by Kalman)"

        print(
            f"{i:>4} | {close[i]:>8.3f} | {stop_str:>8} | "
            f"{regime:>11} | {zone_lbl:>8} | "
            f"{str(result.base_buy[i]):>6} | {str(result.base_sell[i]):>6} | "
            f"{sc}{tag}"
        )

    print()
    print("=" * 65)
    print("FULL PIPELINE SUMMARY")
    print("=" * 65)
    s = result.summary()

    print(f"  Valid bars            : {s['valid_bars']}")
    print()
    print(f"  [A] ATR buy  pulses   : {s['atr_buy_count']:>4}  (raw crossover)")
    print(f"  [A] ATR sell pulses   : {s['atr_sell_count']:>4}  (raw crossunder)")
    print()
    print(f"  [B] Strong UP bars    : {s['strong_up_bars']:>4}  (Kalman regime = STRONG_UP)")
    print(f"  [B] Strong DOWN bars  : {s['strong_dn_bars']:>4}  (Kalman regime = STRONG_DOWN)")
    print()
    print(f"  [A+B] base_buy        : {s['base_buy_count']:>4}  (ATR buy  AND Kalman STRONG_UP)")
    print(f"  [A+B] base_sell       : {s['base_sell_count']:>4}  (ATR sell AND Kalman STRONG_DOWN)")
    print()
    print(f"  [C] bright_buy        : {s['bright_buy_count']:>4}  (base_buy  AND discount zone)")
    print(f"  [C] bright_sell       : {s['bright_sell_count']:>4}  (base_sell AND premium zone)")
    print(f"  [C] dark_buy          : {s['dark_buy_count']:>4}  (base_buy  AND premium zone)")
    print(f"  [C] dark_sell         : {s['dark_sell_count']:>4}  (base_sell AND discount zone)")

    print()
    if s['atr_buy_count'] > 0:
        r = s['base_buy_count'] / s['atr_buy_count'] * 100
        print(f"  Kalman buy  filter : {r:.1f}% of ATR buys survived")
    if s['base_buy_count'] > 0:
        r = s['bright_buy_count'] / s['base_buy_count'] * 100
        print(f"  LRC    buy  filter : {r:.1f}% of base buys became BRIGHT")
    if s['atr_sell_count'] > 0:
        r = s['base_sell_count'] / s['atr_sell_count'] * 100
        print(f"  Kalman sell filter : {r:.1f}% of ATR sells survived")
    if s['base_sell_count'] > 0:
        r = s['bright_sell_count'] / s['base_sell_count'] * 100
        print(f"  LRC    sell filter : {r:.1f}% of base sells became BRIGHT")