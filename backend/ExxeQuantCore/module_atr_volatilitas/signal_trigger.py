import numpy as np
from ExxeQuantCore.module_atr_volatilitas.trailing_stop import ATRTrailingStop

class EMA:
    """
    Exponential Moving Average.
    Replicates ta.ema() from Pine Script.

    Pine Script uses a standard EMA formula:
        alpha = 2 / (length + 1)
        ema[i] = alpha * src[i] + (1 - alpha) * ema[i-1]

    Special case: ta.ema(src, 1) => alpha = 1.0 => output == src itself.
    This is used in Pine Script Module A as the crossover baseline.
    """

    def __init__(self, period: int):
        if period < 1:
            raise ValueError("EMA period must be at least 1.")
        self.period = period
        self.alpha = 2.0 / (period + 1)

    def compute(self, src: np.ndarray) -> np.ndarray:
        result = np.full(len(src), np.nan)

        first_valid = np.where(~np.isnan(src))[0]
        if len(first_valid) == 0:
            return result

        start = first_valid[0]
        result[start] = src[start]

        for i in range(start + 1, len(src)):
            if np.isnan(src[i]):
                result[i] = result[i - 1]
            else:
                result[i] = self.alpha * src[i] + (1.0 - self.alpha) * result[i - 1]

        return result


class CrossoverDetector:
    """
    Detects crossover and crossunder events between two series.

    Pine Script definitions:
        ta.crossover(a, b)  => a crosses ABOVE b
                               a[i] > b[i] and a[i-1] <= b[i-1]

        ta.crossover(b, a)  => b crosses ABOVE a
                               which is a crossing BELOW b (crossunder)
                               b[i] > a[i] and b[i-1] <= a[i-1]
    """

    def crossover(
        self,
        series_a: np.ndarray,
        series_b: np.ndarray
    ) -> np.ndarray:
        """
        Returns boolean array where True means series_a crossed ABOVE series_b.
        Replicates: ta.crossover(series_a, series_b)
        """
        n = len(series_a)
        result = np.zeros(n, dtype=bool)

        for i in range(1, n):
            a_curr = series_a[i]
            a_prev = series_a[i - 1]
            b_curr = series_b[i]
            b_prev = series_b[i - 1]

            if np.isnan(a_curr) or np.isnan(a_prev) or np.isnan(b_curr) or np.isnan(b_prev):
                result[i] = False
                continue

            result[i] = (a_curr > b_curr) and (a_prev <= b_prev)

        return result

    def crossunder(
        self,
        series_a: np.ndarray,
        series_b: np.ndarray
    ) -> np.ndarray:
        """
        Returns boolean array where True means series_a crossed BELOW series_b.
        Replicates: ta.crossover(series_b, series_a)
        Pine uses crossover(xATRTrailingStop, ema1) for 'below' signal.
        """
        return self.crossover(series_b, series_a)


class SignalTrigger:
    """
    Generates raw buy and sell signals from price vs ATR Trailing Stop.

    Replicates Pine Script Module A signal logic exactly:

        ema1  = ta.ema(src, 1)
        above = ta.crossover(ema1, xATRTrailingStop)
        below = ta.crossover(xATRTrailingStop, ema1)
        buy   = src > xATRTrailingStop and above
        sell  = src < xATRTrailingStop and below

    Notes:
        - ta.ema(src, 1) with alpha=1.0 means ema1 == src at every bar.
          The crossover still checks the previous bar, so it is NOT trivially
          true every bar. It only fires when src was <= stop before and is
          now > stop (or vice versa).
        - 'above' fires only once at the crossover bar, not sustained.
        - 'below' fires only once at the crossunder bar, not sustained.
        - buy and sell are therefore one-bar pulse signals, not states.
    """

    def __init__(self):
        self.ema = EMA(period=1)
        self.crossover_detector = CrossoverDetector()

    def compute(
        self,
        src: np.ndarray,
        trailing_stop: np.ndarray
    ) -> dict:
        """
        Parameters
        ----------
        src           : price source array (close or ha_close)
        trailing_stop : output of ATRTrailingStop.compute()

        Returns
        -------
        dict with keys:
            ema1    : ema(1) of src, equivalent to src itself
            above   : bool array, True when ema1 crosses above trailing_stop
            below   : bool array, True when trailing_stop crosses above ema1
            buy     : bool array, True when buy condition met
            sell    : bool array, True when sell condition met
        """
        ema1 = self.ema.compute(src)

        above = self.crossover_detector.crossover(ema1, trailing_stop)
        below = self.crossover_detector.crossunder(ema1, trailing_stop)

        buy  = (src > trailing_stop) & above
        sell = (src < trailing_stop) & below

        return {
            "ema1": ema1,
            "above": above,
            "below": below,
            "buy": buy,
            "sell": sell,
        }


class RawSignalOutput:
    """
    Combines ATRTrailingStop result with SignalTrigger.
    This is the final output of Module A before any Kalman or LRC filtering.

    Mirrors the following Pine Script variables after Calculation A:
        buy  -> raw buy pulse
        sell -> raw sell pulse
        xATRTrailingStop -> trailing stop level per bar
    """

    def __init__(self):
        self.trigger = SignalTrigger()

    def run(
        self,
        src: np.ndarray,
        trailing_stop: np.ndarray
    ) -> dict:
        signal_result = self.trigger.compute(src, trailing_stop)

        return {
            "trailing_stop": trailing_stop,
            "ema1": signal_result["ema1"],
            "above": signal_result["above"],
            "below": signal_result["below"],
            "buy": signal_result["buy"],
            "sell": signal_result["sell"],
        }


if __name__ == "__main__":

    np.random.seed(42)
    n = 120

    close = 100 + np.cumsum(np.random.randn(n) * 0.5)
    high  = close + np.abs(np.random.randn(n) * 0.3)
    low   = close - np.abs(np.random.randn(n) * 0.3)

    atr_trailing = ATRTrailingStop(sensitivity=2, atr_period=6)
    trailing_stop = atr_trailing.compute(high, low, close)

    output = RawSignalOutput()
    result = output.run(close, trailing_stop)

    buy_bars  = np.where(result["buy"])[0]
    sell_bars = np.where(result["sell"])[0]

    print("SignalTrigger - Raw Module A Output")
    print("-" * 55)
    print(f"Total bars processed  : {n}")
    print(f"Buy signal bars       : {len(buy_bars)}  -> {buy_bars[:8]}")
    print(f"Sell signal bars      : {len(sell_bars)} -> {sell_bars[:8]}")
    print()
    print(f"{'Bar':>4} | {'Close':>8} | {'TrailingStop':>12} | {'EMA1':>8} | {'Above':>5} | {'Below':>5} | Signal")
    print("-" * 65)
    for i in range(5, 30):
        sig    = "BUY" if result["buy"][i] else ("SELL" if result["sell"][i] else "-")
        ts     = result["trailing_stop"][i]
        e1     = result["ema1"][i]
        above  = result["above"][i]
        below  = result["below"][i]
        ts_str = f"{ts:.3f}" if not np.isnan(ts) else "nan"
        e1_str = f"{e1:.3f}" if not np.isnan(e1) else "nan"
        print(f"{i:>4} | {close[i]:>8.3f} | {ts_str:>12} | {e1_str:>8} | {str(above):>5} | {str(below):>5} | {sig}")