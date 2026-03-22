import numpy as np


class ATRCalculator:
    """
    Calculates Average True Range (ATR) using RMA (Wilder's Moving Average).
    Replicates ta.atr() from Pine Script which internally uses RMA smoothing.

    Pine Script equivalent:
        xATR = ta.atr(c)

    RMA formula:
        alpha     = 1 / period
        rma[i]    = alpha * src[i] + (1 - alpha) * rma[i-1]
        seed      = sma(tr, period) on the first period bars

    Parameters
    ----------
    period : int
        Lookback period for ATR (Pine: variable 'c'). Default is 6.
    """

    def __init__(self, period: int = 6):
        if period < 1:
            raise ValueError("ATR period must be at least 1.")
        self.period = period

    def true_range(
        self,
        high: np.ndarray,
        low: np.ndarray,
        close: np.ndarray
    ) -> np.ndarray:
        """
        Computes True Range per bar.

        True Range = max of:
            1. high - low
            2. abs(high - prev_close)
            3. abs(low - prev_close)

        For the very first bar (no prev_close), TR = high - low.
        """
        prev_close = np.roll(close, 1)
        prev_close[0] = np.nan

        tr1 = high - low
        tr2 = np.abs(high - prev_close)
        tr3 = np.abs(low - prev_close)

        tr = np.where(
            np.isnan(prev_close),
            tr1,
            np.maximum(tr1, np.maximum(tr2, tr3))
        )
        return tr

    def rma(self, src: np.ndarray) -> np.ndarray:
        """
        Wilder's Moving Average (RMA).

        Pine Script ta.atr() uses RMA internally, NOT EMA.
        Seeded with SMA of the first 'period' values.

        Formula:
            alpha  = 1 / period
            rma[0] = mean(src[0:period])       <- seed
            rma[i] = alpha * src[i] + (1 - alpha) * rma[i-1]
        """
        alpha = 1.0 / self.period
        result = np.full(len(src), np.nan)

        seed_index = self.period - 1
        if seed_index >= len(src):
            return result

        seed_window = src[:self.period]
        valid_seed = seed_window[~np.isnan(seed_window)]
        if len(valid_seed) == 0:
            return result

        result[seed_index] = np.mean(valid_seed)

        for i in range(seed_index + 1, len(src)):
            if not np.isnan(src[i]) and not np.isnan(result[i - 1]):
                result[i] = alpha * src[i] + (1.0 - alpha) * result[i - 1]

        return result

    def compute(
        self,
        high: np.ndarray,
        low: np.ndarray,
        close: np.ndarray
    ) -> np.ndarray:
        tr  = self.true_range(high, low, close)
        atr = self.rma(tr)
        return atr


if __name__ == "__main__":
    np.random.seed(42)
    n = 50

    close = 100 + np.cumsum(np.random.randn(n) * 0.5)
    high  = close + np.abs(np.random.randn(n) * 0.3)
    low   = close - np.abs(np.random.randn(n) * 0.3)

    calc = ATRCalculator(period=6)
    tr   = calc.true_range(high, low, close)
    atr  = calc.compute(high, low, close)

    print("ATRCalculator - Standalone Output")
    print("-" * 45)
    print(f"{'Bar':>4} | {'Close':>8} | {'TR':>8} | {'ATR':>8}")
    print("-" * 45)
    for i in range(3, 20):
        tr_str  = f"{tr[i]:.4f}"  if not np.isnan(tr[i])  else "nan"
        atr_str = f"{atr[i]:.4f}" if not np.isnan(atr[i]) else "nan"
        print(f"{i:>4} | {close[i]:>8.4f} | {tr_str:>8} | {atr_str:>8}")