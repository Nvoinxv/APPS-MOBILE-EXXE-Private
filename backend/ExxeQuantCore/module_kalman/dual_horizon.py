import numpy as np
from ExxeQuantCore.module_kalman.kalman_filter import KalmanFilter

class DualHorizonKalman:
    """
    Dual Horizon Kalman Estimator.

    Replicates Calculation B from Pine Script exactly:

        short_kalman = kalman_filter(close, short_len)
        long_kalman  = kalman_filter(close, long_len)

    Two independent KalmanFilter instances are maintained with separate
    internal states. They share the same src (close) and the same default
    R=0.01, Q=0.1 parameters as defined in the Pine Script function signature.

    The key behavioral difference between short and long horizon:
        error_meas = R * length
        short: error_meas = 0.01 * 50  = 0.5   (responds faster to price)
        long : error_meas = 0.01 * 150 = 1.5   (responds slower, smoother)

    A larger error_meas means the filter trusts the measurement less,
    resulting in a smoother but more lagged estimate. This is why the
    long Kalman acts as a slow trend baseline and the short Kalman
    reacts quicker to recent price movement.

    Parameters
    ----------
    short_len : int   - length for the fast Kalman (Pine default: 50)
    long_len  : int   - length for the slow Kalman (Pine default: 150)
    R         : float - measurement noise (Pine default: 0.01)
    Q         : float - process noise (Pine default: 0.1)
    """

    def __init__(
        self,
        short_len: int = 50,
        long_len: int = 150,
        R: float = 0.01,
        Q: float = 0.1
    ):
        if short_len < 1:
            raise ValueError("short_len must be at least 1.")
        if long_len < 1:
            raise ValueError("long_len must be at least 1.")
        if short_len >= long_len:
            raise ValueError("short_len must be less than long_len.")

        self.short_len = short_len
        self.long_len  = long_len
        self.R         = R
        self.Q         = Q

        # Two independent filter instances with separate states
        # Replicates: short_kalman = kalman_filter(close, short_len)
        self._short_filter = KalmanFilter(length=short_len, R=R, Q=Q)

        # Replicates: long_kalman = kalman_filter(close, long_len)
        self._long_filter  = KalmanFilter(length=long_len, R=R, Q=Q)

    def compute(self, close: np.ndarray) -> dict:
        """
        Runs both Kalman filters over the close price array.

        Replicates Pine Script:
            short_kalman = kalman_filter(close, short_len)
            long_kalman  = kalman_filter(close, long_len)

        Parameters
        ----------
        close : np.ndarray - close price array

        Returns
        -------
        dict with keys:
            short_kalman : np.ndarray - fast horizon estimates per bar
            long_kalman  : np.ndarray - slow horizon estimates per bar
        """
        short_kalman = self._short_filter.compute(close)
        long_kalman  = self._long_filter.compute(close)

        return {
            "short_kalman": short_kalman,
            "long_kalman":  long_kalman,
        }

    def get_short_filter(self) -> KalmanFilter:
        """Returns the internal short KalmanFilter instance for inspection."""
        return self._short_filter

    def get_long_filter(self) -> KalmanFilter:
        """Returns the internal long KalmanFilter instance for inspection."""
        return self._long_filter


if __name__ == "__main__":
    np.random.seed(42)
    n = 40

    close = 100 + np.cumsum(np.random.randn(n) * 0.5)

    dual = DualHorizonKalman(short_len=50, long_len=150)
    result = dual.compute(close)

    short_k = result["short_kalman"]
    long_k  = result["long_kalman"]

    print("DualHorizonKalman - Output")
    print("-" * 75)
    print(f"short error_meas = {dual.get_short_filter()._error_meas:.4f}  (R * short_len = 0.01 * 50)")
    print(f"long  error_meas = {dual.get_long_filter()._error_meas:.4f}  (R * long_len  = 0.01 * 150)")
    print()
    print(f"{'Bar':>4} | {'Close':>8} | {'Short(50)':>10} | {'Long(150)':>10} | {'Spread':>9} | Regime")
    print("-" * 75)
    for i in range(1, n):
        s = short_k[i]
        l = long_k[i]

        s_str = f"{s:.4f}" if not np.isnan(s) else "nan"
        l_str = f"{l:.4f}" if not np.isnan(l) else "nan"

        if not np.isnan(s) and not np.isnan(l):
            spread  = s - l
            sp_str  = f"{spread:+.4f}"
            regime  = "up" if s > l else "down"
        else:
            sp_str = "nan"
            regime = "-"

        print(f"{i:>4} | {close[i]:>8.4f} | {s_str:>10} | {l_str:>10} | {sp_str:>9} | {regime}")

    print()
    short_above_long = np.sum(
        (~np.isnan(short_k)) & (~np.isnan(long_k)) & (short_k > long_k)
    )
    short_below_long = np.sum(
        (~np.isnan(short_k)) & (~np.isnan(long_k)) & (short_k <= long_k)
    )
    print(f"Bars short > long  (trend_up=True)  : {short_above_long}")
    print(f"Bars short <= long (trend_up=False) : {short_below_long}")