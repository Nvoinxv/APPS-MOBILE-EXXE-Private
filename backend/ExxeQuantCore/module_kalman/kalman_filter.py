import numpy as np


class KalmanFilter:
    """
    Recursive Kalman Filter.

    Replicates the kalman_filter() function from Pine Script Module B exactly,
    including all variable initialization, update order, and state management.

    Pine Script source:
        kalman_filter(src, length, R=0.01, Q=0.1) =>
            var float estimate    = na
            var float error_est   = 1.0
            var float error_meas  = R * length
            var float kalman_gain = 0.0
            var float prediction  = na
            if na(estimate)
                estimate := src[1]
            prediction := estimate
            kalman_gain := error_est / (error_est + error_meas)
            estimate    := prediction + kalman_gain * (src - prediction)
            error_est   := (1 - kalman_gain) * error_est + Q / (length)
            estimate

    Variable mapping (Pine -> Python):
        estimate    -> self._estimate    (persistent across bars, initialized once)
        error_est   -> self._error_est   (persistent, starts at 1.0)
        error_meas  -> self._error_meas  (constant = R * length, never changes)
        kalman_gain -> local per bar     (recalculated each bar)
        prediction  -> local per bar     (= previous estimate)

    Initialization behavior:
        Pine: if na(estimate) => estimate := src[1]
        This means on the very first bar where estimate is still na,
        Pine reads src[1] which is the PREVIOUS bar's src value.
        In batch mode (Python), we simulate this by seeding with src[bar - 1]
        at the first valid bar.

    Parameters
    ----------
    length   : int   - horizon length; affects error_meas and Q decay rate
    R        : float - measurement noise coefficient (default 0.01)
    Q        : float - process noise coefficient (default 0.1)
    """

    def __init__(self, length: int, R: float = 0.01, Q: float = 0.1):
        if length < 1:
            raise ValueError("length must be at least 1.")

        self.length     = length
        self.R          = R
        self.Q          = Q

        # Pine: var float error_meas = R * length  (constant, computed once)
        self._error_meas: float = R * length

        # Pine: var float estimate = na  (uninitialized until first bar)
        self._estimate: float = None

        # Pine: var float error_est = 1.0
        self._error_est: float = 1.0

    def _reset(self) -> None:
        """
        Resets internal state.
        Used when calling compute() multiple times on different datasets.
        """
        self._estimate  = None
        self._error_est = 1.0

    def _step(self, src_current: float, src_previous: float) -> float:
        """
        Processes a single bar update following Pine Script execution order exactly.

        Pine execution order per bar:
            1. if na(estimate): estimate := src[1]
            2. prediction  := estimate
            3. kalman_gain := error_est / (error_est + error_meas)
            4. estimate    := prediction + kalman_gain * (src - prediction)
            5. error_est   := (1 - kalman_gain) * error_est + Q / length
            6. return estimate

        Parameters
        ----------
        src_current  : float - src[i], the current bar's price
        src_previous : float - src[i-1], the previous bar's price (for seed)

        Returns
        -------
        float - the updated estimate for this bar
        """
        # Step 1: Pine: if na(estimate) => estimate := src[1]
        # src[1] in Pine = one bar back = src_previous in Python batch mode
        if self._estimate is None:
            self._estimate = src_previous

        # Step 2: prediction := estimate  (snapshot before update)
        prediction = self._estimate

        # Step 3: kalman_gain := error_est / (error_est + error_meas)
        kalman_gain = self._error_est / (self._error_est + self._error_meas)

        # Step 4: estimate := prediction + kalman_gain * (src - prediction)
        self._estimate = prediction + kalman_gain * (src_current - prediction)

        # Step 5: error_est := (1 - kalman_gain) * error_est + Q / length
        self._error_est = (1.0 - kalman_gain) * self._error_est + self.Q / self.length

        # Step 6: return estimate
        return self._estimate

    def compute(self, src: np.ndarray) -> np.ndarray:
        """
        Runs the Kalman Filter over the entire src array.

        Parameters
        ----------
        src : np.ndarray - price source array (e.g. close)

        Returns
        -------
        np.ndarray - kalman estimate per bar
                     index 0 is nan (no previous bar to seed from)
                     index 1 onward has valid estimates
        """
        self._reset()

        n = len(src)
        result = np.full(n, np.nan)

        # Bar 0: no previous bar exists, Pine would have estimate = na here
        # The first _step() call happens at bar 1 where src[1] = src[0]
        for i in range(1, n):
            if np.isnan(src[i]) or np.isnan(src[i - 1]):
                continue
            result[i] = self._step(
                src_current=src[i],
                src_previous=src[i - 1]
            )

        return result


if __name__ == "__main__":
    np.random.seed(42)
    n = 30

    close = 100 + np.cumsum(np.random.randn(n) * 0.5)

    short_kalman = KalmanFilter(length=50, R=0.01, Q=0.1)
    long_kalman  = KalmanFilter(length=150, R=0.01, Q=0.1)

    short_est = short_kalman.compute(close)
    long_est  = long_kalman.compute(close)

    print("KalmanFilter - Core Math Output")
    print("-" * 65)
    print(f"{'Bar':>4} | {'Close':>8} | {'Short(50)':>10} | {'Long(150)':>10} | {'Spread':>8}")
    print("-" * 65)
    for i in range(1, n):
        s_str = f"{short_est[i]:.4f}" if not np.isnan(short_est[i]) else "nan"
        l_str = f"{long_est[i]:.4f}"  if not np.isnan(long_est[i])  else "nan"

        if not np.isnan(short_est[i]) and not np.isnan(long_est[i]):
            spread = short_est[i] - long_est[i]
            sp_str = f"{spread:+.4f}"
        else:
            sp_str = "nan"

        print(f"{i:>4} | {close[i]:>8.4f} | {s_str:>10} | {l_str:>10} | {sp_str:>8}")

    print()
    print("Internal state after full run:")
    print(f"  short_kalman._estimate  = {short_kalman._estimate:.6f}")
    print(f"  short_kalman._error_est = {short_kalman._error_est:.6f}")
    print(f"  short_kalman._error_meas= {short_kalman._error_meas:.6f}  (constant = R * length = 0.01 * 50)")
    print(f"  long_kalman._error_meas = {long_kalman._error_meas:.6f}  (constant = R * length = 0.01 * 150)")