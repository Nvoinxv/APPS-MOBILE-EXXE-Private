import numpy as np
from ExxeQuantCore.module_atr_volatilitas.atr_calculation import ATRCalculator

class ATRTrailingStop:
    """
    Adaptive ATR Trailing Stop.

    Replicates xATRTrailingStop logic from Pine Script Module A exactly.

    Pine Script source:
        nLoss = a * xATR
        xATRTrailingStop :=
            if src > nz(xATRTrailingStop[1]) and src[1] > nz(xATRTrailingStop[1])
                math.max(nz(xATRTrailingStop[1]), src - nLoss)
            else if src < nz(xATRTrailingStop[1]) and src[1] < nz(xATRTrailingStop[1])
                math.min(nz(xATRTrailingStop[1]), src + nLoss)
            else
                src > nz(xATRTrailingStop[1]) ? src - nLoss : src + nLoss

    Three-branch logic breakdown:
        Branch 1 - Bullish continuation:
            Current src AND previous src are both ABOVE the previous stop.
            Stop ratchets UP: take the max of previous stop vs (src - nLoss).
            This prevents the stop from ever moving down in an uptrend.

        Branch 2 - Bearish continuation:
            Current src AND previous src are both BELOW the previous stop.
            Stop ratchets DOWN: take the min of previous stop vs (src + nLoss).
            This prevents the stop from ever moving up in a downtrend.

        Branch 3 - Regime flip (crossover just happened):
            Price has just crossed the stop from either direction.
            Reset the stop to a fresh level relative to current price.
            If src > prev_stop -> new uptrend starts -> stop = src - nLoss
            If src <= prev_stop -> new downtrend starts -> stop = src + nLoss

    Parameters
    ----------
    sensitivity : int
        Multiplier applied to ATR to define the stop distance (Pine: variable 'a').
        Default is 2 as per Pine Script default.
    atr_period : int
        Lookback period for ATR calculation (Pine: variable 'c').
        Default is 6 as per Pine Script default.
    """

    def __init__(self, sensitivity: int = 2, atr_period: int = 6):
        if sensitivity < 1:
            raise ValueError("Sensitivity must be at least 1.")
        if atr_period < 1:
            raise ValueError("ATR period must be at least 1.")

        self.sensitivity = sensitivity
        self.atr_period = atr_period
        self._atr_calculator = ATRCalculator(period=atr_period)

    def _compute_n_loss(
        self,
        high: np.ndarray,
        low: np.ndarray,
        close: np.ndarray
    ) -> np.ndarray:
        """
        Computes nLoss = sensitivity * ATR per bar.
        Replicates: nLoss = a * xATR
        """
        atr = self._atr_calculator.compute(high, low, close)
        n_loss = self.sensitivity * atr
        return n_loss

    def _resolve_initial_stop(self, src_value: float, n_loss_value: float) -> float:
        """
        On the very first valid bar, Pine Script uses nz(xATRTrailingStop[1]) = 0.
        Since src is always > 0 for price data, branch 3 activates:
            src > 0 -> stop = src - nLoss
        This method makes that initialization explicit.
        """
        return src_value - n_loss_value

    def compute(
        self,
        high: np.ndarray,
        low: np.ndarray,
        close: np.ndarray,
        src: np.ndarray = None
    ) -> np.ndarray:
        """
        Computes the ATR Trailing Stop for each bar.

        Parameters
        ----------
        high  : np.ndarray  - bar high prices
        low   : np.ndarray  - bar low prices
        close : np.ndarray  - bar close prices (used for ATR)
        src   : np.ndarray  - price source for stop logic (close or ha_close).
                              If None, defaults to close.
                              Replicates: src = useHA ? haClose : close

        Returns
        -------
        np.ndarray - trailing stop level per bar, nan where ATR not yet available
        """
        if src is None:
            src = close

        n_loss = self._compute_n_loss(high, low, close)
        n = len(src)
        trailing_stop = np.full(n, np.nan)

        for i in range(1, n):
            curr_src   = src[i]
            prev_src   = src[i - 1]
            curr_nloss = n_loss[i]

            if np.isnan(curr_nloss):
                continue

            # nz(xATRTrailingStop[1]) -> if previous stop is nan, treat as 0
            prev_stop = trailing_stop[i - 1] if not np.isnan(trailing_stop[i - 1]) else 0.0

            # Branch 1: Bullish continuation
            # src > prev_stop AND prev_src > prev_stop
            if curr_src > prev_stop and prev_src > prev_stop:
                trailing_stop[i] = max(prev_stop, curr_src - curr_nloss)

            # Branch 2: Bearish continuation
            # src < prev_stop AND prev_src < prev_stop
            elif curr_src < prev_stop and prev_src < prev_stop:
                trailing_stop[i] = min(prev_stop, curr_src + curr_nloss)

            # Branch 3: Regime flip
            # Price just crossed the stop - reset to fresh level
            else:
                if curr_src > prev_stop:
                    trailing_stop[i] = curr_src - curr_nloss
                else:
                    trailing_stop[i] = curr_src + curr_nloss

        return trailing_stop

    def get_n_loss(
        self,
        high: np.ndarray,
        low: np.ndarray,
        close: np.ndarray
    ) -> np.ndarray:
        """
        Exposes the raw nLoss array (sensitivity * ATR).
        Useful for external inspection or debugging without recomputing ATR.
        """
        return self._compute_n_loss(high, low, close)


if __name__ == "__main__":
    np.random.seed(42)
    n = 80

    close = 100 + np.cumsum(np.random.randn(n) * 0.5)
    high  = close + np.abs(np.random.randn(n) * 0.3)
    low   = close - np.abs(np.random.randn(n) * 0.3)

    engine = ATRTrailingStop(sensitivity=2, atr_period=6)

    trailing_stop = engine.compute(high, low, close)
    n_loss        = engine.get_n_loss(high, low, close)

    print("ATRTrailingStop - Standalone Output")
    print("-" * 60)
    print(f"Total bars     : {n}")
    print(f"Valid stops    : {np.sum(~np.isnan(trailing_stop))}")
    print(f"NaN stops      : {np.sum(np.isnan(trailing_stop))}")
    print()
    print(f"{'Bar':>4} | {'Close':>8} | {'nLoss':>7} | {'TrailingStop':>12} | {'Regime'}")
    print("-" * 60)
    for i in range(4, 25):
        ts  = trailing_stop[i]
        nl  = n_loss[i]
        ts_str = f"{ts:.4f}" if not np.isnan(ts) else "nan"
        nl_str = f"{nl:.4f}" if not np.isnan(nl) else "nan"

        if np.isnan(ts):
            regime = "warming up"
        elif close[i] > ts:
            regime = "bullish"
        else:
            regime = "bearish"

        print(f"{i:>4} | {close[i]:>8.4f} | {nl_str:>7} | {ts_str:>12} | {regime}")