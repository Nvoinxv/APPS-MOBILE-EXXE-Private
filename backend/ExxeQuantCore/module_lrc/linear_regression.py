import numpy as np

class OLSResult:
    __slots__ = ("intercept", "y1", "dev", "slope")

    def __init__(
        self,
        intercept: float,
        y1: float,
        dev: float,
        slope: float
    ):
        self.intercept = intercept   # y2 in callers: value at most recent bar
        self.y1        = y1          # value at oldest bar in window
        self.dev       = dev         # RMS deviation from regression line
        self.slope     = slope       # rate of change per bar unit


class LinearRegression:
    """
    OLS (Ordinary Least Squares) Linear Regression over a rolling window.

    Replicates the linear_regression() function from Pine Script exactly,
    including the specific indexing convention where i=0 is the MOST RECENT
    bar and i=window-1 is the OLDEST bar (Pine's bar history convention).

    Pine Script source:
        linear_regression(src, window) =>
            sum_x   = 0.0
            sum_y   = 0.0
            sum_xy  = 0.0
            sum_x_sq = 0.0
            for i = 0 to window - 1 by 1
                sum_x    += i + 1
                sum_y    += src[i]
                sum_xy   += (i + 1) * src[i]
                sum_x_sq += math.pow(i + 1, 2)
            slope     = (window * sum_xy - sum_x * sum_y) /
                        (window * sum_x_sq - math.pow(sum_x, 2))
            intercept = (sum_y - slope * sum_x) / window
            y1        = intercept + slope * (window - 1)
            dev = 0.0
            for i = 0 to window - 1
                dev := dev + math.pow(src[i] - (slope * (window - i) + intercept), 2)
            dev := math.sqrt(dev / window)
            [intercept, y1, dev, slope]

    Critical Pine indexing convention:
        In Pine, src[0] = current bar (most recent).
        In Pine, src[i] = i bars ago.
        So the loop from i=0 to window-1 maps to:
            x-axis position = i + 1   (1 = most recent, window = oldest)

        For Python batch processing, at bar index `b` with window `w`:
            src[b - 0]         = src[b]       (i=0 in Pine, x=1)
            src[b - 1]         = src[b-1]     (i=1 in Pine, x=2)
            ...
            src[b - (w-1)]     = src[b-w+1]   (i=w-1 in Pine, x=w)

        The window slice in Python is: close[b-w+1 : b+1] reversed.

    Slope and intercept derivation:
        Using OLS formulas over x = [1, 2, ..., window]:
            slope     = (n * sum_xy - sum_x * sum_y) / (n * sum_x_sq - sum_x^2)
            intercept = (sum_y - slope * sum_x) / n

        Where x=1 is MOST RECENT bar and x=window is OLDEST bar.

        This gives intercept as the value at x=0, which by extrapolation is
        one bar AHEAD of the most recent bar. But Pine uses it as the value
        at the most recent bar's position (x=1), so:
            y_at_most_recent = intercept + slope * 1  ... actually in Pine
            the returned 'intercept' is used directly as y2 (most recent end).

        After careful analysis of Pine's formula:
            intercept = (sum_y - slope * sum_x) / window
            y1        = intercept + slope * (window - 1)

        The intercept here is NOT the standard OLS intercept (at x=0).
        It is a shifted intercept such that the line value at x=1 equals
        intercept + slope * 1. Pine's callers treat `intercept` as y2
        (value at the right/recent end of the channel).

    Deviation formula:
        Pine uses RMS (root mean square) deviation, NOT standard deviation:
            dev = sqrt(mean(squared residuals))
        Where residuals = src[i] - (slope * (window - i) + intercept)
        Note: (window - i) when i goes 0..window-1 gives window..1
        This is the x-value from the oldest to most recent bar.

    Parameters
    ----------
    window : int - number of bars in the rolling regression window
    """

    def __init__(self, window: int):
        if window < 2:
            raise ValueError("Regression window must be at least 2.")
        self.window = window

    def _compute_single(self, window_slice: np.ndarray) -> OLSResult:
        """
        Computes OLS regression for one bar given a window of prices.

        Parameters
        ----------
        window_slice : np.ndarray
            Price slice of length self.window.
            window_slice[0] = most recent bar  (Pine: src[0])
            window_slice[-1] = oldest bar      (Pine: src[window-1])

        Returns
        -------
        OLSResult
        """
        w = self.window

        sum_x    = 0.0
        sum_y    = 0.0
        sum_xy   = 0.0
        sum_x_sq = 0.0

        # Replicates Pine loop: for i = 0 to window - 1
        # Pine: src[i] -> Python: window_slice[i]
        # Pine: x = i + 1 (1=most recent, window=oldest)
        for i in range(w):
            x         = i + 1
            y         = window_slice[i]
            sum_x    += x
            sum_y    += y
            sum_xy   += x * y
            sum_x_sq += x * x

        # Pine: slope = (window * sum_xy - sum_x * sum_y) /
        #               (window * sum_x_sq - sum_x^2)
        denom = w * sum_x_sq - sum_x * sum_x
        if denom == 0.0:
            slope = 0.0
        else:
            slope = (w * sum_xy - sum_x * sum_y) / denom

        # Pine: intercept = (sum_y - slope * sum_x) / window
        intercept = (sum_y - slope * sum_x) / w

        # Pine: y1 = intercept + slope * (window - 1)
        y1 = intercept + slope * (w - 1)

        # Pine: dev = sqrt(mean(pow(src[i] - (slope * (window - i) + intercept), 2)))
        # Note: (window - i) when i=0..window-1 gives window..1
        # This is the x-value in REVERSE (oldest=window, most recent=1 going back)
        # Wait - let us re-read Pine carefully:
        #   dev += pow(src[i] - (slope * (window - i) + intercept), 2)
        # When i=0 (most recent): slope*(window - 0) + intercept = slope*window + intercept
        # When i=window-1 (oldest): slope*(window-(window-1)) + intercept = slope*1 + intercept
        # So (window - i) maps: most_recent -> window, oldest -> 1
        # This is the INVERTED x-axis vs the slope fitting.
        # The fitted value at x=1 (most recent) is: slope*1 + intercept
        # But Pine computes residual at i=0 as: src[0] - (slope*window + intercept)
        # This means Pine's deviation uses x = (window - i) for residuals,
        # which is x increasing from right (recent=window) to left (old=1).
        # This is consistent with Pine's x-axis convention in the OLS fitting.
        dev_sq_sum = 0.0
        for i in range(w):
            x_pos     = w - i
            fitted    = slope * x_pos + intercept
            residual  = window_slice[i] - fitted
            dev_sq_sum += residual * residual

        dev = np.sqrt(dev_sq_sum / w)

        return OLSResult(intercept=intercept, y1=y1, dev=dev, slope=slope)

    def compute(self, close: np.ndarray) -> dict:
        """
        Runs rolling OLS regression over the entire close array.

        For each bar b >= window-1, computes regression over:
            close[b], close[b-1], ..., close[b-window+1]
        which maps to Pine's src[0..window-1] at bar b.

        Parameters
        ----------
        close : np.ndarray - close price array

        Returns
        -------
        dict with np.ndarray values per bar, nan where window not yet full:
            intercept : value at most recent bar end (Pine: y2_bands)
            y1        : value at oldest bar end
            dev       : RMS deviation from regression line
            slope     : slope of fitted line
            mid       : mid band = intercept + slope  (Pine: y2_bands + slope_bands)
        """
        n = len(close)
        w = self.window

        intercept_arr = np.full(n, np.nan)
        y1_arr        = np.full(n, np.nan)
        dev_arr       = np.full(n, np.nan)
        slope_arr     = np.full(n, np.nan)
        mid_arr       = np.full(n, np.nan)

        for b in range(w - 1, n):
            # window_slice[0] = close[b]        = most recent (Pine src[0])
            # window_slice[-1] = close[b-w+1]   = oldest      (Pine src[w-1])
            window_slice = close[b - w + 1: b + 1][::-1]

            if np.any(np.isnan(window_slice)):
                continue

            result = self._compute_single(window_slice)

            intercept_arr[b] = result.intercept
            y1_arr[b]        = result.y1
            dev_arr[b]       = result.dev
            slope_arr[b]     = result.slope

            # Pine: mid_bands = y2_bands + slope_bands
            # y2_bands = intercept (the most-recent-bar value)
            mid_arr[b] = result.intercept + result.slope

        return {
            "intercept": intercept_arr,
            "y1":        y1_arr,
            "dev":       dev_arr,
            "slope":     slope_arr,
            "mid":       mid_arr,
        }


if __name__ == "__main__":
    np.random.seed(42)
    n = 30

    close = 100 + np.cumsum(np.random.randn(n) * 0.5)

    reg = LinearRegression(window=10)
    result = reg.compute(close)

    intercept = result["intercept"]
    y1        = result["y1"]
    dev       = result["dev"]
    slope     = result["slope"]
    mid       = result["mid"]

    print("LinearRegression - Output (window=10)")
    print("-" * 80)
    print(f"{'Bar':>4} | {'Close':>8} | {'Intercept':>10} | {'Y1':>10} | {'Dev':>7} | {'Slope':>8} | {'Mid':>10}")
    print("-" * 80)
    for i in range(n):
        c_str = f"{close[i]:.4f}"
        if np.isnan(intercept[i]):
            print(f"{i:>4} | {c_str:>8} | {'nan':>10} | {'nan':>10} | {'nan':>7} | {'nan':>8} | {'nan':>10}")
        else:
            print(
                f"{i:>4} | {c_str:>8} | "
                f"{intercept[i]:>10.4f} | "
                f"{y1[i]:>10.4f} | "
                f"{dev[i]:>7.4f} | "
                f"{slope[i]:>8.5f} | "
                f"{mid[i]:>10.4f}"
            )

    print()
    print("Pine variable mapping from caller side:")
    print("  y2_bands   = intercept  (right end / most recent bar value)")
    print("  y1_bands   = y1         (left end / oldest bar value)")
    print("  dev_bands  = dev        (RMS deviation)")
    print("  slope_bands = slope     (slope of line)")
    print("  mid_bands  = mid        = y2_bands + slope_bands")