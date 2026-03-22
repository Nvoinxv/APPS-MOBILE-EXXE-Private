import numpy as np
from ExxeQuantCore.module_lrc.deviation_bands import DeviationBands

class ZoneLabel:
    """
    String constants for zone classification labels.

    Maps Pine Script zone conditions to readable Python strings.
    These are used as output values in QualityZones.classify().

    Pine source reference:
        isInDiscountArea = close <= mid_bands   -> ZoneLabel.DISCOUNT
        isInPremiumArea  = close >= mid_bands   -> ZoneLabel.PREMIUM
        (neither condition)                     -> ZoneLabel.MID
    """
    DISCOUNT = "discount"   # close <= mid_bands  -> favor BUY signals
    PREMIUM  = "premium"    # close >= mid_bands  -> favor SELL signals
    MID      = "mid"        # close == mid_bands  -> edge case, counted as both


class SignalClass:
    """
    String constants for final signal classification.

    Maps Pine Script bright/dark signal booleans to readable Python strings.

    Pine source reference:
        bright_Buy  = base_Buy  and isInDiscountArea  -> SignalClass.BRIGHT_BUY
        bright_Sell = base_Sell and isInPremiumArea   -> SignalClass.BRIGHT_SELL
        dark_Buy    = base_Buy  and not isInDiscountArea -> SignalClass.DARK_BUY
        dark_Sell   = base_Sell and not isInPremiumArea  -> SignalClass.DARK_SELL
    """
    BRIGHT_BUY  = "bright_buy"
    BRIGHT_SELL = "bright_sell"
    DARK_BUY    = "dark_buy"
    DARK_SELL   = "dark_sell"
    NONE        = "none"


class QualityZones:
    """
    Quality Zone Classifier (LRC Quality Filter).

    Replicates Calculation D Section 2 from Pine Script exactly:

        Pine Script source:
            isInDiscountArea = close <= mid_bands
            isInPremiumArea  = close >= mid_bands

            bright_Buy  = base_Buy  and isInDiscountArea
            bright_Sell = base_Sell and isInPremiumArea
            dark_Buy    = base_Buy  and not isInDiscountArea
            dark_Sell   = base_Sell and not isInPremiumArea

    What this module does:
        Takes mid_bands from DeviationBands and compares close price against
        it to classify each bar as either discount zone or premium zone.
        This zone label is then used to gate base signals into high-probability
        (bright) or low-probability (dark) categories.

    Zone definitions:

        DISCOUNT zone (close <= mid_bands):
            Price is at or below the regression midline.
            Statistically undervalued relative to trend.
            Buy signals here = BRIGHT (high confidence, aligned with LRC).
            Buy signals NOT here = DARK (counter-trend, low confidence).

        PREMIUM zone (close >= mid_bands):
            Price is at or above the regression midline.
            Statistically overvalued relative to trend.
            Sell signals here = BRIGHT (high confidence, aligned with LRC).
            Sell signals NOT here = DARK (counter-trend, low confidence).

    Note on Pine boundary behavior:
        Pine uses <= and >= which means price exactly AT mid_bands counts
        as BOTH discount AND premium simultaneously. In Python we replicate
        this exactly:
            isInDiscountArea = close <= mid  (True when close == mid)
            isInPremiumArea  = close >= mid  (True when close == mid)
        This is a rare edge case but must be preserved for 1:1 accuracy.

    Signal gate logic:

        bright_Buy  = base_Buy  AND isInDiscountArea
        bright_Sell = base_Sell AND isInPremiumArea
        dark_Buy    = base_Buy  AND NOT isInDiscountArea
        dark_Sell   = base_Sell AND NOT isInPremiumArea

    Parameters
    ----------
    window : int   - regression window for DeviationBands (default 150)
    devlen : float - band multiplier for DeviationBands (default 3.0)
                     Note: devlen does not affect zone boundaries directly.
                     Zones are determined by mid only, not upper/lower bands.
    """

    def __init__(self, window: int = 150, devlen: float = 3.0):
        self.window = window
        self.devlen = devlen
        self._bands = DeviationBands(window=window, devlen=devlen)

    def compute_zones(
        self,
        close: np.ndarray,
        high:  np.ndarray,
        low:   np.ndarray,
    ) -> dict:
        """
        Computes zone classification per bar.

        Replicates Pine Script:
            isInDiscountArea = close <= mid_bands
            isInPremiumArea  = close >= mid_bands

        Parameters
        ----------
        close : np.ndarray
        high  : np.ndarray
        low   : np.ndarray

        Returns
        -------
        dict with keys:
            mid              : np.ndarray (float)  - mid_bands per bar
            upper            : np.ndarray (float)  - upper_bands per bar
            lower            : np.ndarray (float)  - lower_bands per bar
            is_discount      : np.ndarray (bool)   - close <= mid_bands
            is_premium       : np.ndarray (bool)   - close >= mid_bands
            zone_label       : np.ndarray (object) - ZoneLabel string per bar
        """
        band_result = self._bands.compute(close, high, low)
        mid         = band_result["mid"]
        upper       = band_result["upper"]
        lower       = band_result["lower"]

        n            = len(close)
        is_discount  = np.zeros(n, dtype=bool)
        is_premium   = np.zeros(n, dtype=bool)
        zone_label   = np.full(n, ZoneLabel.MID, dtype=object)

        for i in range(n):
            m = mid[i]
            c = close[i]

            if np.isnan(m):
                zone_label[i] = ZoneLabel.MID
                continue

            # Pine: isInDiscountArea = close <= mid_bands
            is_discount[i] = c <= m

            # Pine: isInPremiumArea = close >= mid_bands
            is_premium[i]  = c >= m

            # Label assignment: Pine has no explicit zone label variable,
            # but the logic below reflects the mutually exclusive rendering
            if c < m:
                zone_label[i] = ZoneLabel.DISCOUNT
            elif c > m:
                zone_label[i] = ZoneLabel.PREMIUM
            else:
                # c == m: Pine counts this as BOTH discount AND premium
                # We label as MID to indicate the boundary edge case
                zone_label[i] = ZoneLabel.MID

        return {
            "mid":         mid,
            "upper":       upper,
            "lower":       lower,
            "is_discount": is_discount,
            "is_premium":  is_premium,
            "zone_label":  zone_label,
        }

    def classify_signals(
        self,
        close:     np.ndarray,
        high:      np.ndarray,
        low:       np.ndarray,
        base_buy:  np.ndarray,
        base_sell: np.ndarray,
    ) -> dict:
        """
        Applies quality zone filter to base signals and classifies them
        as bright (high probability) or dark (low probability).

        Replicates Pine Script Calculation D Section 2 + 3 exactly:

            isInDiscountArea = close <= mid_bands
            isInPremiumArea  = close >= mid_bands

            bright_Buy  = base_Buy  and isInDiscountArea
            bright_Sell = base_Sell and isInPremiumArea
            dark_Buy    = base_Buy  and not isInDiscountArea
            dark_Sell   = base_Sell and not isInPremiumArea

        Parameters
        ----------
        close     : np.ndarray - close price
        high      : np.ndarray - high price
        low       : np.ndarray - low price
        base_buy  : np.ndarray (bool) - raw buy triggers from Module A + B
        base_sell : np.ndarray (bool) - raw sell triggers from Module A + B

        Returns
        -------
        dict with keys:
            is_discount  : np.ndarray (bool)   - close <= mid
            is_premium   : np.ndarray (bool)   - close >= mid
            zone_label   : np.ndarray (object) - ZoneLabel per bar
            mid          : np.ndarray (float)  - mid_bands
            upper        : np.ndarray (float)  - upper_bands
            lower        : np.ndarray (float)  - lower_bands
            bright_buy   : np.ndarray (bool)   - base_buy  AND is_discount
            bright_sell  : np.ndarray (bool)   - base_sell AND is_premium
            dark_buy     : np.ndarray (bool)   - base_buy  AND NOT is_discount
            dark_sell    : np.ndarray (bool)   - base_sell AND NOT is_premium
            signal_class : np.ndarray (object) - SignalClass string per bar
        """
        zone_result = self.compute_zones(close, high, low)

        is_discount = zone_result["is_discount"]
        is_premium  = zone_result["is_premium"]

        # Pine: bright_Buy = base_Buy and isInDiscountArea
        bright_buy  = base_buy  & is_discount

        # Pine: bright_Sell = base_Sell and isInPremiumArea
        bright_sell = base_sell & is_premium

        # Pine: dark_Buy = base_Buy and not isInDiscountArea
        dark_buy    = base_buy  & ~is_discount

        # Pine: dark_Sell = base_Sell and not isInPremiumArea
        dark_sell   = base_sell & ~is_premium

        # Composite signal classification label per bar
        # Priority order: bright > dark > none (only one signal fires per bar)
        n            = len(close)
        signal_class = np.full(n, SignalClass.NONE, dtype=object)

        for i in range(n):
            if bright_buy[i]:
                signal_class[i] = SignalClass.BRIGHT_BUY
            elif bright_sell[i]:
                signal_class[i] = SignalClass.BRIGHT_SELL
            elif dark_buy[i]:
                signal_class[i] = SignalClass.DARK_BUY
            elif dark_sell[i]:
                signal_class[i] = SignalClass.DARK_SELL

        return {
            "is_discount":  is_discount,
            "is_premium":   is_premium,
            "zone_label":   zone_result["zone_label"],
            "mid":          zone_result["mid"],
            "upper":        zone_result["upper"],
            "lower":        zone_result["lower"],
            "bright_buy":   bright_buy,
            "bright_sell":  bright_sell,
            "dark_buy":     dark_buy,
            "dark_sell":    dark_sell,
            "signal_class": signal_class,
        }

    def get_bands(self) -> DeviationBands:
        """Returns the internal DeviationBands instance for inspection."""
        return self._bands


if __name__ == "__main__":
    np.random.seed(42)
    n = 50

    close = 100 + np.cumsum(np.random.randn(n) * 0.5)
    high  = close + np.abs(np.random.randn(n) * 0.3)
    low   = close - np.abs(np.random.randn(n) * 0.3)

    # Simulate base_buy / base_sell from Module A + B
    # In real usage these come from RawSignalOutput + TrendState
    # Here we inject synthetic pulses for testing
    base_buy  = np.zeros(n, dtype=bool)
    base_sell = np.zeros(n, dtype=bool)
    base_buy[[12, 25, 38]]  = True
    base_sell[[17, 30, 44]] = True

    qz = QualityZones(window=10, devlen=3.0)

    # Test 1: Zone-only output
    zone_result = qz.compute_zones(close, high, low)

    print("QualityZones - Zone Classification (window=10)")
    print("-" * 70)
    print(f"{'Bar':>4} | {'Close':>8} | {'Mid':>9} | {'Discount':>8} | {'Premium':>7} | Zone")
    print("-" * 70)
    for i in range(n):
        c     = close[i]
        m     = zone_result["mid"][i]
        isd   = zone_result["is_discount"][i]
        isp   = zone_result["is_premium"][i]
        zlbl  = zone_result["zone_label"][i]

        m_str = f"{m:.4f}" if not np.isnan(m) else "nan"
        print(f"{i:>4} | {c:>8.4f} | {m_str:>9} | {str(isd):>8} | {str(isp):>7} | {zlbl}")

    print()

    # Test 2: Full signal classification
    sig_result = qz.classify_signals(close, high, low, base_buy, base_sell)

    print("QualityZones - Signal Classification")
    print("-" * 75)
    print(f"{'Bar':>4} | {'Close':>8} | {'Zone':>8} | {'BaseBuy':>7} | {'BaseSell':>8} | Signal Class")
    print("-" * 75)
    for i in range(n):
        c      = close[i]
        zlbl   = sig_result["zone_label"][i]
        bb     = base_buy[i]
        bs     = base_sell[i]
        sc     = sig_result["signal_class"][i]

        if sc != SignalClass.NONE or bb or bs:
            tag = f"  <<< {sc.upper()}" if sc != SignalClass.NONE else ""
            print(f"{i:>4} | {c:>8.4f} | {zlbl:>8} | {str(bb):>7} | {str(bs):>8} | {sc}{tag}")

    print()
    bright_buy_total  = int(np.sum(sig_result["bright_buy"]))
    bright_sell_total = int(np.sum(sig_result["bright_sell"]))
    dark_buy_total    = int(np.sum(sig_result["dark_buy"]))
    dark_sell_total   = int(np.sum(sig_result["dark_sell"]))

    print("Signal summary:")
    print(f"  bright_buy  : {bright_buy_total}  (base_buy  AND is_discount)")
    print(f"  bright_sell : {bright_sell_total}  (base_sell AND is_premium)")
    print(f"  dark_buy    : {dark_buy_total}  (base_buy  AND NOT is_discount)")
    print(f"  dark_sell   : {dark_sell_total}  (base_sell AND NOT is_premium)")
    print()
    print("Pine variable mapping:")
    print("  is_discount  -> isInDiscountArea = close <= mid_bands")
    print("  is_premium   -> isInPremiumArea  = close >= mid_bands")
    print("  bright_buy   -> bright_Buy  = base_Buy  and isInDiscountArea")
    print("  bright_sell  -> bright_Sell = base_Sell and isInPremiumArea")
    print("  dark_buy     -> dark_Buy    = base_Buy  and not isInDiscountArea")
    print("  dark_sell    -> dark_Sell   = base_Sell and not isInPremiumArea")