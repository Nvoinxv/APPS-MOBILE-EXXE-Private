import numpy as np
from ExxeQuantCore.module_lrc.linear_regression import LinearRegression

class RMACalculator:
    """
    Wilder's Moving Average (RMA) for an arbitrary source array.

    Replicates Pine Script: ta.rma(source, period)

    Used inside DeviationBands to smooth the high-low range:
        Pine: ta.rma(high - low, window_bands)

    This is the same RMA algorithm used in ATRCalculator (Module A),
    extracted here as a standalone utility so DeviationBands has no
    cross-module dependency on module_a__volatility.

    Formula:
        alpha   = 1 / period
        seed    = mean(src[0 : period])     <- first valid value
        rma[i]  = alpha * src[i] + (1 - alpha) * rma[i-1]

    Parameters
    ----------
    period : int - smoothing period
    """

    def __init__(self, period: int):
        if period < 1:
            raise ValueError("RMA period must be at least 1.")
        self.period = period

    def compute(self, src: np.ndarray) -> np.ndarray:
        """
        Parameters
        ----------
        src : np.ndarray - input array to smooth

        Returns
        -------
        np.ndarray - RMA values, nan for the first (period - 1) bars
        """
        alpha  = 1.0 / self.period
        result = np.full(len(src), np.nan)

        seed_idx = self.period - 1
        if seed_idx >= len(src):
            return result

        seed_window = src[:self.period]
        valid       = seed_window[~np.isnan(seed_window)]
        if len(valid) == 0:
            return result

        result[seed_idx] = np.mean(valid)

        for i in range(seed_idx + 1, len(src)):
            if not np.isnan(src[i]) and not np.isnan(result[i - 1]):
                result[i] = alpha * src[i] + (1.0 - alpha) * result[i - 1]

        return result


class DeviationBands:
    """
    Statistical Deviation Bands (Quality Filter).

    Replicates Calculation C from Pine Script exactly:

        [y2_bands, y1_bands, dev_bands, slope_bands] = linear_regression(close, window_bands)

        mid_bands   = y2_bands + slope_bands
        upper_bands = mid_bands + ta.rma(high - low, window_bands) * devlen_b
        lower_bands = mid_bands - ta.rma(high - low, window_bands) * devlen_b

    Three-component breakdown:

        mid_bands (Equilibrium):
            = y2_bands + slope_bands
            = intercept + slope
            This is the regression line value projected one bar forward
            from the most recent bar. It represents the "fair value" center
            of the channel at the current bar.

        rma_hl (Volatility Envelope):
            = ta.rma(high - low, window)
            Wilder's smoothed average of the bar's high-low range.
            This measures recent price volatility (spread per bar).
            NOT related to ATR — this uses raw HL range, no close reference.

        upper_bands (Premium Zone boundary):
            = mid_bands + rma_hl * devlen_b
            Price above this = overextended / premium / sell zone.

        lower_bands (Discount Zone boundary):
            = mid_bands - rma_hl * devlen_b
            Price below this = undervalued / discount / buy zone.

        devlen_b (Standard Deviation Multiplier):
            Pine default = 3.0
            Controls band width. Higher = wider bands = fewer signals classified
            as premium/discount. Used as multiplier on rma_hl, NOT on dev_bands.

    Important distinction:
        Pine script computes dev_bands from linear_regression() but does NOT
        use it in the band width formula. The band width uses rma(high-low)
        instead. dev_bands is available but unused in Calculation C bands.
        This class faithfully exposes dev_bands anyway for completeness.

    Parameters
    ----------
    window  : int   - regression + RMA period (Pine: window_bands, default 150)
    devlen  : float - band width multiplier   (Pine: devlen_b, default 3.0)
    """

    def __init__(self, window: int = 150, devlen: float = 3.0):
        if window < 2:
            raise ValueError("window must be at least 2.")
        if devlen <= 0:
            raise ValueError("devlen must be positive.")

        self.window = window
        self.devlen = devlen

        # Pine: linear_regression(close, window_bands)
        self._regression = LinearRegression(window=window)

        # Pine: ta.rma(high - low, window_bands)
        self._rma = RMACalculator(period=window)

    def compute(
        self,
        close: np.ndarray,
        high:  np.ndarray,
        low:   np.ndarray,
    ) -> dict:
        """
        Computes mid, upper, and lower deviation bands per bar.

        Replicates Pine Script Calculation C exactly:
            mid_bands   = y2_bands + slope_bands
            upper_bands = mid_bands + ta.rma(high - low, window_bands) * devlen_b
            lower_bands = mid_bands - ta.rma(high - low, window_bands) * devlen_b

        Parameters
        ----------
        close : np.ndarray - close price array
        high  : np.ndarray - high price array
        low   : np.ndarray - low price array

        Returns
        -------
        dict with np.ndarray values per bar:
            mid        : equilibrium line (y2_bands + slope_bands)
            upper      : premium zone upper boundary
            lower      : discount zone lower boundary
            rma_hl     : ta.rma(high - low, window) - the volatility smoother
            intercept  : y2_bands from linear_regression (right end value)
            y1         : y1_bands from linear_regression (left end value)
            slope      : slope_bands from linear_regression
            dev        : dev_bands from linear_regression (RMS deviation, not used in bands)
        """
        # Step 1: Run OLS regression on close
        # Pine: [y2_bands, y1_bands, dev_bands, slope_bands] = linear_regression(close, window_bands)
        reg = self._regression.compute(close)

        intercept_arr = reg["intercept"]   # y2_bands in Pine
        y1_arr        = reg["y1"]          # y1_bands in Pine
        dev_arr       = reg["dev"]         # dev_bands in Pine (available, not used in bands)
        slope_arr     = reg["slope"]       # slope_bands in Pine

        # Step 2: Compute mid_bands = y2_bands + slope_bands
        # Pine: series float mid_bands = y2_bands + slope_bands
        mid_arr = intercept_arr + slope_arr

        # Step 3: Compute rma(high - low, window)
        # Pine: ta.rma(high - low, window_bands)
        hl_range   = high - low
        rma_hl_arr = self._rma.compute(hl_range)

        # Step 4: Compute upper and lower bands
        # Pine: upper_bands = mid_bands + ta.rma(high - low, window_bands) * devlen_b
        # Pine: lower_bands = mid_bands - ta.rma(high - low, window_bands) * devlen_b
        n          = len(close)
        upper_arr  = np.full(n, np.nan)
        lower_arr  = np.full(n, np.nan)

        for i in range(n):
            m   = mid_arr[i]
            rhl = rma_hl_arr[i]

            if np.isnan(m) or np.isnan(rhl):
                continue

            upper_arr[i] = m + rhl * self.devlen
            lower_arr[i] = m - rhl * self.devlen

        return {
            "mid":       mid_arr,
            "upper":     upper_arr,
            "lower":     lower_arr,
            "rma_hl":    rma_hl_arr,
            "intercept": intercept_arr,
            "y1":        y1_arr,
            "slope":     slope_arr,
            "dev":       dev_arr,
        }

    def get_regression(self) -> LinearRegression:
        """Returns the internal LinearRegression instance for inspection."""
        return self._regression

    def get_rma(self) -> RMACalculator:
        """Returns the internal RMACalculator instance for inspection."""
        return self._rma


if __name__ == "__main__":
    np.random.seed(42)
    n = 50

    close = 100 + np.cumsum(np.random.randn(n) * 0.5)
    high  = close + np.abs(np.random.randn(n) * 0.3)
    low   = close - np.abs(np.random.randn(n) * 0.3)

    # Test with smaller window so we get valid values in 50 bars
    bands = DeviationBands(window=10, devlen=3.0)
    result = bands.compute(close, high, low)

    mid   = result["mid"]
    upper = result["upper"]
    lower = result["lower"]
    rma   = result["rma_hl"]
    slope = result["slope"]

    print("DeviationBands - Output (window=10, devlen=3.0)")
    print("-" * 85)
    print(f"{'Bar':>4} | {'Close':>8} | {'Lower':>9} | {'Mid':>9} | {'Upper':>9} | {'RMA(HL)':>8} | Zone")
    print("-" * 85)
    for i in range(n):
        c = close[i]

        if np.isnan(mid[i]):
            print(f"{i:>4} | {c:>8.4f} | {'nan':>9} | {'nan':>9} | {'nan':>9} | {'nan':>8} | warming up")
            continue

        # Replicate Pine zone logic (preview for quality_zones.py)
        if c <= mid[i]:
            zone = "DISCOUNT"
        elif c >= mid[i]:
            zone = "PREMIUM"
        else:
            zone = "MID"

        print(
            f"{i:>4} | {c:>8.4f} | "
            f"{lower[i]:>9.4f} | "
            f"{mid[i]:>9.4f} | "
            f"{upper[i]:>9.4f} | "
            f"{rma[i]:>8.4f} | "
            f"{zone}"
        )

    print()
    valid_mask = ~np.isnan(mid)
    discount_count = int(np.sum((close <= mid) & valid_mask))
    premium_count  = int(np.sum((close >  mid) & valid_mask))
    print(f"Valid bars   : {int(np.sum(valid_mask))}")
    print(f"Discount bars: {discount_count}  (close <= mid  -> isInDiscountArea)")
    print(f"Premium bars : {premium_count}  (close >  mid  -> isInPremiumArea)")
    print()
    print("Pine variable mapping:")
    print("  result['intercept'] = y2_bands  (right end of regression line)")
    print("  result['y1']        = y1_bands  (left end of regression line)")
    print("  result['slope']     = slope_bands")
    print("  result['dev']       = dev_bands  (RMS deviation, unused in bands)")
    print("  result['mid']       = mid_bands  = y2_bands + slope_bands")
    print("  result['rma_hl']    = ta.rma(high-low, window)")
    print("  result['upper']     = upper_bands = mid + rma_hl * devlen")
    print("  result['lower']     = lower_bands = mid - rma_hl * devlen")