import numpy as np
from ExxeQuantCore.module_kalman.dual_horizon import DualHorizonKalman

class TrendState:
    """
    Kalman Trend State Classifier.

    Replicates the trend determination logic from Pine Script Calculation B
    exactly, including all three derived trend variables:

        Pine Script:
            trend_up          = short_kalman > long_kalman
            trend_col1        = short_kalman > short_kalman[2] ? upper_col : lower_col
            candle_col_kalman = trend_up and short_kalman > short_kalman[2]    ? upper_col
                              : not trend_up and short_kalman < short_kalman[2] ? lower_col
                              : color.gray

    Variable mapping to Python enums (replacing color constants):
        upper_col  -> TrendState.STRONG_UP   = "strong_up"
        lower_col  -> TrendState.STRONG_DOWN = "strong_down"
        color.gray -> TrendState.NEUTRAL      = "neutral"

    Why three separate trend variables:

        trend_up (bool):
            Pure structural trend. Long-only comparison.
            True when short Kalman is ABOVE long Kalman.
            Used as the primary trend gate in signal classification.
            Replicates: isStrongUp = candle_col_kalman == upper_col
                        isStrongDown = candle_col_kalman == lower_col

        trend_col1 (momentum):
            Short-term momentum check. Compares short Kalman vs its value
            TWO bars ago (short_kalman[2] in Pine = index i-2 in Python).
            Answers: is the fast Kalman currently accelerating up or down?

        candle_col_kalman (composite regime):
            Final 3-state regime label. Requires BOTH conditions to be true:
            - STRONG_UP   : trend_up AND fast Kalman rising (vs 2 bars ago)
            - STRONG_DOWN : not trend_up AND fast Kalman falling (vs 2 bars ago)
            - NEUTRAL     : trend and momentum are conflicting (mixed signal)

    Parameters
    ----------
    short_len : int   - fast Kalman horizon (default 50)
    long_len  : int   - slow Kalman horizon (default 150)
    R         : float - Kalman measurement noise (default 0.01)
    Q         : float - Kalman process noise (default 0.1)
    """

    STRONG_UP   = "strong_up"
    STRONG_DOWN = "strong_down"
    NEUTRAL     = "neutral"

    def __init__(
        self,
        short_len: int = 50,
        long_len: int = 150,
        R: float = 0.01,
        Q: float = 0.1
    ):
        self.short_len = short_len
        self.long_len  = long_len
        self._dual     = DualHorizonKalman(short_len=short_len, long_len=long_len, R=R, Q=Q)

    def _compute_trend_up(
        self,
        short_kalman: np.ndarray,
        long_kalman: np.ndarray
    ) -> np.ndarray:
        """
        Replicates: trend_up = short_kalman > long_kalman

        Returns boolean array. nan values produce False (safe default).
        """
        n = len(short_kalman)
        result = np.zeros(n, dtype=bool)

        for i in range(n):
            s = short_kalman[i]
            l = long_kalman[i]
            if np.isnan(s) or np.isnan(l):
                result[i] = False
            else:
                result[i] = s > l

        return result

    def _compute_trend_col1(self, short_kalman: np.ndarray) -> np.ndarray:
        """
        Replicates: trend_col1 = short_kalman > short_kalman[2] ? upper_col : lower_col

        Pine: short_kalman[2] = value 2 bars back = index i-2 in Python.
        Returns string array of TrendState.STRONG_UP or TrendState.STRONG_DOWN.
        First 2 bars are NEUTRAL (no previous-2 reference available).
        """
        n = len(short_kalman)
        result = np.full(n, self.NEUTRAL, dtype=object)

        for i in range(2, n):
            curr = short_kalman[i]
            prev2 = short_kalman[i - 2]

            if np.isnan(curr) or np.isnan(prev2):
                result[i] = self.NEUTRAL
            elif curr > prev2:
                result[i] = self.STRONG_UP
            else:
                result[i] = self.STRONG_DOWN

        return result

    def _compute_candle_col_kalman(
        self,
        trend_up: np.ndarray,
        short_kalman: np.ndarray
    ) -> np.ndarray:
        """
        Replicates the candle_col_kalman ternary logic from Pine Script:

            candle_col_kalman =
                trend_up and short_kalman > short_kalman[2]      ? upper_col
                : not trend_up and short_kalman < short_kalman[2] ? lower_col
                : color.gray

        Three outcomes per bar:
            STRONG_UP   : trend_up is True  AND short rising vs 2 bars ago
            STRONG_DOWN : trend_up is False AND short falling vs 2 bars ago
            NEUTRAL     : mixed signal (trend and momentum disagree)

        Returns string array.
        """
        n = len(short_kalman)
        result = np.full(n, self.NEUTRAL, dtype=object)

        for i in range(2, n):
            curr   = short_kalman[i]
            prev2  = short_kalman[i - 2]
            t_up   = trend_up[i]

            if np.isnan(curr) or np.isnan(prev2):
                result[i] = self.NEUTRAL
                continue

            # Pine: trend_up and short_kalman > short_kalman[2]
            if t_up and curr > prev2:
                result[i] = self.STRONG_UP

            # Pine: not trend_up and short_kalman < short_kalman[2]
            elif (not t_up) and curr < prev2:
                result[i] = self.STRONG_DOWN

            # Pine: color.gray  (conflicting regime)
            else:
                result[i] = self.NEUTRAL

        return result

    def compute(self, close: np.ndarray) -> dict:
        """
        Runs the full Calculation B pipeline from Pine Script.

        Parameters
        ----------
        close : np.ndarray - close price array

        Returns
        -------
        dict with keys:
            short_kalman      : np.ndarray (float)  - fast Kalman estimates
            long_kalman       : np.ndarray (float)  - slow Kalman estimates
            trend_up          : np.ndarray (bool)   - short > long
            trend_col1        : np.ndarray (object) - short momentum vs 2 bars ago
            candle_col_kalman : np.ndarray (object) - 3-state composite regime
        """
        kalman_result = self._dual.compute(close)
        short_kalman  = kalman_result["short_kalman"]
        long_kalman   = kalman_result["long_kalman"]

        trend_up          = self._compute_trend_up(short_kalman, long_kalman)
        trend_col1        = self._compute_trend_col1(short_kalman)
        candle_col_kalman = self._compute_candle_col_kalman(trend_up, short_kalman)

        return {
            "short_kalman":      short_kalman,
            "long_kalman":       long_kalman,
            "trend_up":          trend_up,
            "trend_col1":        trend_col1,
            "candle_col_kalman": candle_col_kalman,
        }

    def is_strong_up(self, candle_col_kalman: np.ndarray) -> np.ndarray:
        """
        Replicates: isStrongUp = candle_col_kalman == upper_col
        Used downstream in signal_engine to gate base_Buy.
        """
        return candle_col_kalman == self.STRONG_UP

    def is_strong_down(self, candle_col_kalman: np.ndarray) -> np.ndarray:
        """
        Replicates: isStrongDown = candle_col_kalman == lower_col
        Used downstream in signal_engine to gate base_Sell.
        """
        return candle_col_kalman == self.STRONG_DOWN


if __name__ == "__main__":
    np.random.seed(42)
    n = 40

    close = 100 + np.cumsum(np.random.randn(n) * 0.5)

    engine = TrendState(short_len=50, long_len=150)
    result = engine.compute(close)

    short_k  = result["short_kalman"]
    long_k   = result["long_kalman"]
    t_up     = result["trend_up"]
    t_col1   = result["trend_col1"]
    ccol     = result["candle_col_kalman"]

    is_sup  = engine.is_strong_up(ccol)
    is_sdn  = engine.is_strong_down(ccol)

    print("TrendState - Full Calculation B Output")
    print("-" * 90)
    print(f"{'Bar':>4} | {'Close':>8} | {'Short':>9} | {'Long':>9} | {'trend_up':>8} | {'col1':>11} | {'candle_col':>11}")
    print("-" * 90)
    for i in range(1, n):
        s    = short_k[i]
        l    = long_k[i]
        tu   = t_up[i]
        c1   = t_col1[i]
        cc   = ccol[i]

        s_str  = f"{s:.3f}" if not np.isnan(s) else "nan"
        l_str  = f"{l:.3f}" if not np.isnan(l) else "nan"

        print(f"{i:>4} | {close[i]:>8.3f} | {s_str:>9} | {l_str:>9} | {str(tu):>8} | {str(c1):>11} | {str(cc):>11}")

    print()
    sup_count  = np.sum(is_sup)
    sdn_count  = np.sum(is_sdn)
    neu_count  = np.sum(ccol == TrendState.NEUTRAL)

    print(f"Regime summary over {n} bars:")
    print(f"  STRONG_UP   (isStrongUp=True)  : {sup_count}")
    print(f"  STRONG_DOWN (isStrongDown=True) : {sdn_count}")
    print(f"  NEUTRAL                        : {neu_count}")