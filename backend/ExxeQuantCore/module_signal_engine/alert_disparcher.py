import numpy as np
from dataclasses import dataclass, field
from typing import List, Optional, Callable
from enum import Enum

from ExxeQuantCore.module_signal_engine.classifier import (
    ClassifiedSignal,
    ClassifierResult,
    SignalTier,
    Direction,
)


# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

class AlertType:
    """
    Alert type labels replicating Pine alertcondition() names.

    Pine Script reference (Section 5, Plot A):
        alertcondition(base_Buy,  "EXXE PROTOCOL: Long Execution")
        alertcondition(base_Sell, "EXXE PROTOCOL: Short Execution")

    Python extends this with tier-specific alert types so consumers
    can subscribe to only bright or only dark events.
    """
    LONG_EXECUTION  = "EXXE PROTOCOL: Long Execution"    # base_Buy  (Pine exact)
    SHORT_EXECUTION = "EXXE PROTOCOL: Short Execution"   # base_Sell (Pine exact)

    BRIGHT_LONG     = "EXXE PROTOCOL: Long Execution [BRIGHT]"
    BRIGHT_SHORT    = "EXXE PROTOCOL: Short Execution [BRIGHT]"
    DARK_LONG       = "EXXE PROTOCOL: Long Execution [DARK]"
    DARK_SHORT      = "EXXE PROTOCOL: Short Execution [DARK]"


class TradeOutcome:
    """
    Trade result classification from the Historical Execution Simulator.

    Replicates Pine Script Section 4 exit logic:
        ✔ MAX TP  → trade closed at tp5
        ✔ TP1..4  → intermediate TPs hit (tracked but trade still open)
        ✖ SL      → stop loss triggered
        OPEN      → trade still active at end of data
    """
    MAX_TP  = "MAX_TP"    # Pine: "✔ MAX TP"
    SL      = "SL"        # Pine: "✖ SL"
    OPEN    = "OPEN"      # Trade still active (end of dataset)


# ─────────────────────────────────────────────────────────────────────────────
# Alert Event
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class AlertEvent:
    """
    Single alert emission event.

    Replicates Pine alertcondition() firing behavior:
        - Fires once per bar (on bar close, like Pine's barstate.isconfirmed)
        - Contains full signal context for downstream consumption
        - alert_type uses Pine's exact alertcondition names

    Pine Script reference:
        alertcondition(base_Buy,  "EXXE PROTOCOL: Long Execution",  "EXXE PROTOCOL: Long Execution")
        alertcondition(base_Sell, "EXXE PROTOCOL: Short Execution", "EXXE PROTOCOL: Short Execution")

    The `message` field replicates the alert message string Pine would emit.
    """
    bar_index:   int
    alert_type:  str           # AlertType constant
    direction:   int           # Direction.LONG or Direction.SHORT
    tier:        str           # SignalTier.BRIGHT or SignalTier.DARK
    signal_class: str          # SignalClass constant

    close:       float         # Entry price reference
    confidence:  float         # From ClassifiedSignal
    band_pos:    Optional[float]

    # Human-readable message (replicates Pine alert message string)
    message:     str = field(default="")

    def __post_init__(self):
        if not self.message:
            dir_str  = "Long" if self.direction == Direction.LONG else "Short"
            tier_str = "HIGH PROB" if self.tier == SignalTier.BRIGHT else "LOW PROB"
            self.message = (
                f"EXXE PROTOCOL: {dir_str} Execution | "
                f"Tier={tier_str} | "
                f"Class={self.signal_class.upper()} | "
                f"Price={self.close:.5f} | "
                f"Conf={self.confidence:.3f}"
            )

    @property
    def is_bright(self) -> bool:
        return self.tier == SignalTier.BRIGHT

    @property
    def direction_str(self) -> str:
        return "LONG" if self.direction == Direction.LONG else "SHORT"

    def __repr__(self) -> str:
        return (
            f"AlertEvent(bar={self.bar_index}, "
            f"{self.direction_str}, "
            f"{'★' if self.is_bright else '◆'} {self.tier.upper()}, "
            f"price={self.close:.4f}, "
            f"conf={self.confidence:.3f})"
        )


# ─────────────────────────────────────────────────────────────────────────────
# Trade Setup & Result
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class TradeSetup:
    """
    Full trade setup with SL and multi-TP levels.

    Replicates Pine Script type TradeSetup (Section 4):
        int   direction      -> direction (1=long, -1=short)
        float entry_price    -> close at signal bar
        float sl_price       -> global_lowest_low[1] or global_highest_high[1]
        float tp1_price      -> entry ± risk * 1
        float tp2_price      -> entry ± risk * 2
        float tp3_price      -> entry ± risk * 3
        float tp4_price      -> entry ± risk * 4
        float tp5_price      -> entry ± risk * 5
        bool  tp1_hit..tp4   -> partial TP tracking
        int   entry_bar      -> bar_index at entry
        bool  is_active      -> whether trade is still open

    Pine SL logic:
        Long  SL = ta.lowest(low,  sl_lookback)[1]  (previous bar's lookback low)
        Short SL = ta.highest(high, sl_lookback)[1] (previous bar's lookback high)

    Pine TP logic (5 levels, each 1R apart):
        Long:  tp_n = entry_price + risk * n  (n = 1..5)
        Short: tp_n = entry_price - risk * n  (n = 1..5)
        where risk = abs(entry_price - sl_price)
    """
    direction:    int
    signal:       ClassifiedSignal   # Source signal that triggered this trade

    entry_price:  float
    sl_price:     float
    risk:         float              # abs(entry - sl)

    tp1_price:    float
    tp2_price:    float
    tp3_price:    float
    tp4_price:    float
    tp5_price:    float

    entry_bar:    int
    is_active:    bool = True

    # TP hit tracking (Pine: bool tp1_hit..tp4_hit)
    tp1_hit:      bool = False
    tp2_hit:      bool = False
    tp3_hit:      bool = False
    tp4_hit:      bool = False

    # Outcome (set on close)
    outcome:      Optional[str]  = None   # TradeOutcome constant
    exit_bar:     Optional[int]  = None
    exit_price:   Optional[float] = None

    # RR at each TP hit (for reporting)
    highest_rr:   float = 0.0

    @property
    def direction_str(self) -> str:
        return "LONG" if self.direction == Direction.LONG else "SHORT"

    @property
    def tier(self) -> str:
        return self.signal.tier

    @property
    def is_winner(self) -> bool:
        """True if at least TP1 was hit before SL."""
        return self.tp1_hit

    @property
    def final_rr(self) -> float:
        """
        Highest R:R achieved during the trade.
        0.0 = SL hit without TP1. 5.0 = MAX TP hit.
        """
        return self.highest_rr

    def __repr__(self) -> str:
        outcome_str = self.outcome or "OPEN"
        return (
            f"TradeSetup("
            f"bar={self.entry_bar}, "
            f"{self.direction_str}, "
            f"{'★' if self.tier == SignalTier.BRIGHT else '◆'}{self.tier}, "
            f"entry={self.entry_price:.4f}, "
            f"sl={self.sl_price:.4f}, "
            f"risk={self.risk:.4f}, "
            f"outcome={outcome_str}, "
            f"rr={self.final_rr:.1f}R)"
        )


# ─────────────────────────────────────────────────────────────────────────────
# Dispatcher Result
# ─────────────────────────────────────────────────────────────────────────────

class DispatchResult:
    """
    Full output of AlertDispatcher.dispatch().

    Contains:
        alerts  : List[AlertEvent]  — all alert emissions (one per signal bar)
        trades  : List[TradeSetup]  — all simulated trades with outcomes

    Mirrors Pine Script Section 4 + 5 combined:
        - Section 4: Historical Execution Simulator  → trades
        - Section 5: alertcondition() + plotshape()  → alerts
    """

    def __init__(
        self,
        alerts: List[AlertEvent],
        trades: List[TradeSetup],
    ):
        self.alerts = alerts
        self.trades = trades

    # ── Alert views ───────────────────────────────────────────────────────────

    @property
    def bright_alerts(self) -> List[AlertEvent]:
        return [a for a in self.alerts if a.is_bright]

    @property
    def dark_alerts(self) -> List[AlertEvent]:
        return [a for a in self.alerts if not a.is_bright]

    # ── Trade views ───────────────────────────────────────────────────────────

    @property
    def closed_trades(self) -> List[TradeSetup]:
        return [t for t in self.trades if not t.is_active]

    @property
    def open_trades(self) -> List[TradeSetup]:
        return [t for t in self.trades if t.is_active]

    @property
    def winners(self) -> List[TradeSetup]:
        """Trades that hit at least TP1 (Pine: smart SL label hidden if TP1 hit)."""
        return [t for t in self.closed_trades if t.is_winner]

    @property
    def losers(self) -> List[TradeSetup]:
        return [t for t in self.closed_trades if not t.is_winner]

    @property
    def bright_trades(self) -> List[TradeSetup]:
        return [t for t in self.trades if t.tier == SignalTier.BRIGHT]

    @property
    def dark_trades(self) -> List[TradeSetup]:
        return [t for t in self.trades if t.tier == SignalTier.DARK]

    # ── Performance summary ───────────────────────────────────────────────────

    def summary(self) -> dict:
        """
        Returns scalar performance statistics.

        Replicates the logic behind Pine's Historical Execution Simulator
        visual output (trade boxes, TP/SL markers).

        Win rate denominator is closed trades only (excludes OPEN).
        """
        closed    = self.closed_trades
        n_closed  = len(closed)
        n_winners = len(self.winners)
        n_losers  = len(self.losers)
        n_open    = len(self.open_trades)

        win_rate  = (n_winners / n_closed * 100) if n_closed > 0 else 0.0

        # Avg RR of winners
        winner_rr = [t.final_rr for t in self.winners]
        avg_rr    = float(np.mean(winner_rr)) if winner_rr else 0.0

        # Expectancy: (winrate * avg_rr) - (lossrate * 1.0)
        loss_rate   = 1.0 - (win_rate / 100)
        expectancy  = (win_rate / 100 * avg_rr) - (loss_rate * 1.0)

        # Breakdown by tier
        bt = self.bright_trades
        dt = self.dark_trades
        bt_closed  = [t for t in bt if not t.is_active]
        dt_closed  = [t for t in dt if not t.is_active]
        bt_winners = [t for t in bt_closed if t.is_winner]
        dt_winners = [t for t in dt_closed if t.is_winner]

        bright_winrate = (len(bt_winners) / len(bt_closed) * 100) if bt_closed else 0.0
        dark_winrate   = (len(dt_winners) / len(dt_closed) * 100) if dt_closed else 0.0

        return {
            # Alerts
            "total_alerts":      len(self.alerts),
            "bright_alerts":     len(self.bright_alerts),
            "dark_alerts":       len(self.dark_alerts),

            # Trades
            "total_trades":      len(self.trades),
            "closed_trades":     n_closed,
            "open_trades":       n_open,
            "winners":           n_winners,
            "losers":            n_losers,
            "win_rate_pct":      round(win_rate, 2),
            "avg_winner_rr":     round(avg_rr, 2),
            "expectancy":        round(expectancy, 4),

            # By tier
            "bright_trades":     len(bt),
            "dark_trades":       len(dt),
            "bright_win_rate":   round(bright_winrate, 2),
            "dark_win_rate":     round(dark_winrate, 2),
        }


# ─────────────────────────────────────────────────────────────────────────────
# Main Dispatcher
# ─────────────────────────────────────────────────────────────────────────────

class AlertDispatcher:
    """
    Alert Dispatcher — Module D, Final Step.

    Consumes a ClassifierResult and produces two outputs:

        1. Alert Events  — replicates Pine alertcondition() behavior
        2. Trade Setups  — replicates Pine Historical Execution Simulator

    ── Pine Script reference ────────────────────────────────────────────────

        Section 5 (Alert):
            alertcondition(base_Buy,  "EXXE PROTOCOL: Long Execution")
            alertcondition(base_Sell, "EXXE PROTOCOL: Short Execution")

        Section 4 (Trade Simulator):
            var int trade_direction = 0
            if trade_direction == 0:
                if base_Buy:
                    entry_price = close
                    sl_price    = global_lowest_low[1]    # ta.lowest(low, sl_lookback)[1]
                    risk        = entry_price - sl_price
                    tp1..tp5    = entry_price + risk * 1..5
                    trade_direction = 1
                elif base_Sell:
                    entry_price = close
                    sl_price    = global_highest_high[1]  # ta.highest(high, sl_lookback)[1]
                    risk        = sl_price - entry_price
                    tp1..tp5    = entry_price - risk * 1..5
                    trade_direction = -1

            Trade management per bar (long):
                if high >= tp1_price: tp1_hit = True
                if high >= tp5_price: close trade, outcome = MAX_TP
                if low  <= sl_price:  close trade, outcome = SL
                    (SL label only shown if tp1 NOT hit)  <- "Smart SL Label"

            Trade management per bar (short):
                if low  <= tp1_price: tp1_hit = True
                if low  <= tp5_price: close trade, outcome = MAX_TP
                if high >= sl_price:  close trade, outcome = SL

    ── One trade at a time rule ──────────────────────────────────────────────

        Pine maintains trade_direction = 0 when flat.
        New trades only trigger if trade_direction == 0.
        This means overlapping signals are skipped — first signal wins.

    ── Alert callback system ─────────────────────────────────────────────────

        AlertDispatcher supports optional callback functions that fire
        when alerts are emitted. This is the Python equivalent of Pine's
        alertcondition() which triggers webhooks/notifications.

        Usage:
            def my_handler(event: AlertEvent):
                print(f"ALERT: {event.message}")

            dispatcher = AlertDispatcher(sl_lookback=15)
            dispatcher.register_callback(my_handler)

    Parameters
    ----------
    sl_lookback : int
        Lookback period for SL calculation (Pine: sl_lookback, default 15).
        Pine: global_lowest_low  = ta.lowest(low,  sl_lookback)
              global_highest_high = ta.highest(high, sl_lookback)
    """

    def __init__(self, sl_lookback: int = 15):
        if sl_lookback < 1:
            raise ValueError("sl_lookback must be at least 1.")
        self.sl_lookback = sl_lookback
        self._callbacks: List[Callable[[AlertEvent], None]] = []

    # ── Callback registration ────────────────────────────────────────────────

    def register_callback(self, fn: Callable[[AlertEvent], None]) -> None:
        """
        Registers a callback function to fire when an alert is dispatched.

        Replicates Pine alertcondition() webhook / notification trigger.
        Callback receives a fully populated AlertEvent object.

        Parameters
        ----------
        fn : Callable[[AlertEvent], None]
        """
        self._callbacks.append(fn)

    def _fire_callbacks(self, event: AlertEvent) -> None:
        for fn in self._callbacks:
            fn(event)

    # ── SL price calculation ─────────────────────────────────────────────────

    def _compute_sl_prices(
        self,
        high: np.ndarray,
        low:  np.ndarray,
    ) -> tuple:
        """
        Computes rolling SL reference arrays for all bars.

        Pine Script:
            global_lowest_low    = ta.lowest(low,  sl_lookback)
            global_highest_high  = ta.highest(high, sl_lookback)

        In Pine, the trade uses [1] shift — "previous bar's lookback value"
        so the SL is set using the lookback from the bar BEFORE entry.
        This is replicated here: sl at bar i = lookback value at bar i-1.

        Returns
        -------
        tuple: (long_sl_prices, short_sl_prices) — np.ndarray per bar
        """
        n            = len(low)
        long_sl      = np.full(n, np.nan)   # ta.lowest(low,  sl_lookback)[1]
        short_sl     = np.full(n, np.nan)   # ta.highest(high, sl_lookback)[1]

        for i in range(self.sl_lookback, n):
            # Pine: global_lowest_low[1] = ta.lowest computed at bar i-1
            window_low  = low[max(0, i - self.sl_lookback): i]
            window_high = high[max(0, i - self.sl_lookback): i]

            if len(window_low) > 0:
                long_sl[i]  = float(np.nanmin(window_low))
            if len(window_high) > 0:
                short_sl[i] = float(np.nanmax(window_high))

        return long_sl, short_sl

    # ── Alert emission ────────────────────────────────────────────────────────

    def _emit_alert(self, signal: ClassifiedSignal) -> AlertEvent:
        """
        Creates and emits an AlertEvent for a classified signal.

        Replicates Pine alertcondition() behavior.
        Fires callback chain if any handlers are registered.

        Pine:
            alertcondition(base_Buy,  "EXXE PROTOCOL: Long Execution")
            alertcondition(base_Sell, "EXXE PROTOCOL: Short Execution")

        Python extends with tier-specific alert type strings.
        """
        # Base alert type matches Pine's exact alertcondition name
        if signal.direction == Direction.LONG:
            base_type = AlertType.LONG_EXECUTION
            tier_type = AlertType.BRIGHT_LONG if signal.is_bright else AlertType.DARK_LONG
        else:
            base_type = AlertType.SHORT_EXECUTION
            tier_type = AlertType.BRIGHT_SHORT if signal.is_bright else AlertType.DARK_SHORT

        event = AlertEvent(
            bar_index    = signal.bar_index,
            alert_type   = tier_type,
            direction    = signal.direction,
            tier         = signal.tier,
            signal_class = signal.signal_class,
            close        = signal.close,
            confidence   = signal.confidence,
            band_pos     = signal.band_position,
        )

        self._fire_callbacks(event)
        return event

    # ── Trade management ──────────────────────────────────────────────────────

    def _open_trade(
        self,
        signal:    ClassifiedSignal,
        long_sl:   np.ndarray,
        short_sl:  np.ndarray,
    ) -> Optional[TradeSetup]:
        """
        Opens a new trade if SL price is valid.

        Replicates Pine Section 4 trade entry logic:

            Long:
                entry_price = close
                sl_price    = global_lowest_low[1]
                risk        = entry_price - sl_price
                tp1..tp5    = entry_price + risk * n

            Short:
                entry_price = close
                sl_price    = global_highest_high[1]
                risk        = sl_price - entry_price
                tp1..tp5    = entry_price - risk * n

        Returns None if risk <= 0 (invalid SL, skip trade).
        """
        i     = signal.bar_index
        entry = signal.close

        if signal.direction == Direction.LONG:
            sl = float(long_sl[i])
            if np.isnan(sl) or sl >= entry:
                return None   # invalid SL
            risk = entry - sl
            tp1  = entry + risk * 1
            tp2  = entry + risk * 2
            tp3  = entry + risk * 3
            tp4  = entry + risk * 4
            tp5  = entry + risk * 5
        else:
            sl = float(short_sl[i])
            if np.isnan(sl) or sl <= entry:
                return None   # invalid SL
            risk = sl - entry
            tp1  = entry - risk * 1
            tp2  = entry - risk * 2
            tp3  = entry - risk * 3
            tp4  = entry - risk * 4
            tp5  = entry - risk * 5

        return TradeSetup(
            direction   = signal.direction,
            signal      = signal,
            entry_price = entry,
            sl_price    = sl,
            risk        = risk,
            tp1_price   = tp1,
            tp2_price   = tp2,
            tp3_price   = tp3,
            tp4_price   = tp4,
            tp5_price   = tp5,
            entry_bar   = i,
        )

    def _manage_trade(
        self,
        trade: TradeSetup,
        bar:   int,
        high:  float,
        low:   float,
    ) -> bool:
        """
        Manages an active trade for a single bar.

        Replicates Pine Section 4 per-bar management loop.

        Returns True if trade is now closed (stop or max TP hit).

        Pine Long management:
            if not tp1_hit and high >= tp1_price: tp1_hit = True
            if not tp2_hit and high >= tp2_price: tp2_hit = True
            if not tp3_hit and high >= tp3_price: tp3_hit = True
            if not tp4_hit and high >= tp4_price: tp4_hit = True
            if high >= tp5_price: close, outcome = MAX_TP
            if low  <= sl_price:  close, outcome = SL
                (Pine: Smart SL Label only shown if tp1 NOT hit)

        Pine Short management:
            if not tp1_hit and low  <= tp1_price: tp1_hit = True
            ...
            if low  <= tp5_price: close, outcome = MAX_TP
            if high >= sl_price:  close, outcome = SL
        """
        if trade.direction == Direction.LONG:
            # ── TP tracking (Pine: individual hit tracking) ───────────────
            if not trade.tp1_hit and high >= trade.tp1_price:
                trade.tp1_hit    = True
                trade.highest_rr = max(trade.highest_rr, 1.0)

            if not trade.tp2_hit and high >= trade.tp2_price:
                trade.tp2_hit    = True
                trade.highest_rr = max(trade.highest_rr, 2.0)

            if not trade.tp3_hit and high >= trade.tp3_price:
                trade.tp3_hit    = True
                trade.highest_rr = max(trade.highest_rr, 3.0)

            if not trade.tp4_hit and high >= trade.tp4_price:
                trade.tp4_hit    = True
                trade.highest_rr = max(trade.highest_rr, 4.0)

            # ── Trade close conditions ─────────────────────────────────────
            if high >= trade.tp5_price:
                trade.is_active  = False
                trade.outcome    = TradeOutcome.MAX_TP
                trade.exit_bar   = bar
                trade.exit_price = trade.tp5_price
                trade.highest_rr = 5.0
                return True

            if low <= trade.sl_price:
                trade.is_active  = False
                trade.outcome    = TradeOutcome.SL
                trade.exit_bar   = bar
                trade.exit_price = trade.sl_price
                # Pine "Smart SL Label": SL label only shown if tp1 NOT hit
                # We track this via trade.tp1_hit on the TradeSetup
                return True

        else:  # SHORT
            # ── TP tracking ───────────────────────────────────────────────
            if not trade.tp1_hit and low <= trade.tp1_price:
                trade.tp1_hit    = True
                trade.highest_rr = max(trade.highest_rr, 1.0)

            if not trade.tp2_hit and low <= trade.tp2_price:
                trade.tp2_hit    = True
                trade.highest_rr = max(trade.highest_rr, 2.0)

            if not trade.tp3_hit and low <= trade.tp3_price:
                trade.tp3_hit    = True
                trade.highest_rr = max(trade.highest_rr, 3.0)

            if not trade.tp4_hit and low <= trade.tp4_price:
                trade.tp4_hit    = True
                trade.highest_rr = max(trade.highest_rr, 4.0)

            # ── Trade close conditions ─────────────────────────────────────
            if low <= trade.tp5_price:
                trade.is_active  = False
                trade.outcome    = TradeOutcome.MAX_TP
                trade.exit_bar   = bar
                trade.exit_price = trade.tp5_price
                trade.highest_rr = 5.0
                return True

            if high >= trade.sl_price:
                trade.is_active  = False
                trade.outcome    = TradeOutcome.SL
                trade.exit_bar   = bar
                trade.exit_price = trade.sl_price
                return True

        return False  # trade still active

    # ── Public API ────────────────────────────────────────────────────────────

    def dispatch(
        self,
        classifier_result: ClassifierResult,
        high:              np.ndarray,
        low:               np.ndarray,
    ) -> DispatchResult:
        """
        Runs the full alert + trade simulation pipeline.

        ── Step 1: Compute SL reference arrays ─────────────────────────────
            Replicates Pine:
                global_lowest_low   = ta.lowest(low,  sl_lookback)
                global_highest_high = ta.highest(high, sl_lookback)

        ── Step 2: Walk all bars chronologically ────────────────────────────
            For each bar:
                a) If an active trade exists: manage it (check TP/SL)
                b) If no active trade AND a signal fires at this bar:
                   - Emit AlertEvent
                   - Open TradeSetup
            Replicates Pine's one-trade-at-a-time constraint:
                "if (trade_direction == 0): open new trade"

        ── Step 3: Mark remaining open trades ──────────────────────────────
            Any trade still active at end of dataset → TradeOutcome.OPEN

        Parameters
        ----------
        classifier_result : ClassifierResult  - output of SignalClassifier.classify()
        high              : np.ndarray        - high prices (same length as base data)
        low               : np.ndarray        - low prices

        Returns
        -------
        DispatchResult containing alerts + trades + performance summary
        """
        n = len(high)

        # ── Step 1: SL reference arrays ──────────────────────────────────────
        long_sl, short_sl = self._compute_sl_prices(high, low)

        # ── Build signal lookup: bar_index → ClassifiedSignal ────────────────
        # One signal per bar max (classifier enforces this)
        signal_map = {s.bar_index: s for s in classifier_result.signals}

        # ── Step 2: Walk bars ─────────────────────────────────────────────────
        alerts:          List[AlertEvent] = []
        trades:          List[TradeSetup] = []
        active_trade:    Optional[TradeSetup] = None

        for bar in range(n):
            h = float(high[bar])
            l = float(low[bar])

            # ── 2a: Manage active trade ───────────────────────────────────────
            if active_trade is not None:
                closed = self._manage_trade(active_trade, bar, h, l)
                if closed:
                    active_trade = None

            # ── 2b: Check for new signal (only if flat) ───────────────────────
            if active_trade is None and bar in signal_map:
                signal = signal_map[bar]

                # Emit alert (replicates alertcondition())
                alert = self._emit_alert(signal)
                alerts.append(alert)

                # Open trade (replicates Pine Section 4 entry logic)
                trade = self._open_trade(signal, long_sl, short_sl)
                if trade is not None:
                    trades.append(trade)
                    active_trade = trade

        # ── Step 3: Mark remaining open trades ───────────────────────────────
        for t in trades:
            if t.is_active:
                t.outcome = TradeOutcome.OPEN

        return DispatchResult(alerts=alerts, trades=trades)


# ─────────────────────────────────────────────────────────────────────────────
# Standalone test
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import sys
    import os
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

    from ExxeQuantCore.module_signal_engine.base_signal   import BaseSignalEngine
    from ExxeQuantCore.module_signal_engine.classifier    import SignalClassifier, FilterMode

    np.random.seed(42)
    n = 300

    close = 100 + np.cumsum(np.random.randn(n) * 0.5)
    high  = close + np.abs(np.random.randn(n) * 0.3)
    low   = close - np.abs(np.random.randn(n) * 0.3)
    src   = close

    # ── Step 1: Base pipeline ─────────────────────────────────────────────────
    engine = BaseSignalEngine(
        sensitivity = 2,
        atr_period  = 6,
        short_len   = 50,
        long_len    = 150,
        lrc_window  = 50,
        lrc_devlen  = 3.0,
    )
    base_result = engine.run(src=src, high=high, low=low, close=close)

    # ── Step 2: Classify ──────────────────────────────────────────────────────
    classifier  = SignalClassifier(filter_mode=FilterMode.ALL)
    clf_result  = classifier.classify(result=base_result, close=close)

    # ── Step 3: Dispatch (with example callback) ──────────────────────────────
    print("AlertDispatcher — Full Dispatch Pipeline")
    print("=" * 80)

    # Register an example callback — replicates Pine alertcondition() handler
    def on_alert(event: AlertEvent) -> None:
        tier_sym = "★" if event.is_bright else "◆"
        print(f"  [ALERT FIRED] bar={event.bar_index:>3} | "
              f"{tier_sym} {event.tier:>6} | "
              f"{event.direction_str:>5} | "
              f"price={event.close:.4f} | "
              f"conf={event.confidence:.3f}")

    dispatcher  = AlertDispatcher(sl_lookback=15)
    dispatcher.register_callback(on_alert)

    print("\nCallback fires (replicates Pine alertcondition):")
    print("-" * 80)
    result = dispatcher.dispatch(classifier_result=clf_result, high=high, low=low)

    # ── Print all trades ──────────────────────────────────────────────────────
    print()
    print("=" * 80)
    print("TRADE SIMULATION (Pine Historical Execution Simulator)")
    print("=" * 80)
    print(
        f"{'Bar':>4} | {'Dir':>5} | {'Tier':>6} | {'Entry':>9} | "
        f"{'SL':>9} | {'Risk':>7} | {'TP1':>9} | {'TP5':>9} | "
        f"{'Outcome':>7} | {'RR':>4} | SmartSL?"
    )
    print("-" * 80)

    for t in result.trades:
        # Pine "Smart SL Label": ✖ SL marker is HIDDEN if tp1 was already hit
        smart_sl = "shown" if (t.outcome == TradeOutcome.SL and not t.tp1_hit) else \
                   ("hidden" if t.outcome == TradeOutcome.SL else "n/a")
        tier_sym = "★" if t.tier == SignalTier.BRIGHT else "◆"
        outcome  = t.outcome or "OPEN"

        print(
            f"{t.entry_bar:>4} | {t.direction_str:>5} | "
            f"{tier_sym} {t.tier:>5} | "
            f"{t.entry_price:>9.4f} | {t.sl_price:>9.4f} | "
            f"{t.risk:>7.4f} | {t.tp1_price:>9.4f} | {t.tp5_price:>9.4f} | "
            f"{outcome:>7} | {t.final_rr:>4.1f} | {smart_sl}"
        )

    # ── Performance summary ───────────────────────────────────────────────────
    print()
    print("=" * 60)
    print("PERFORMANCE SUMMARY")
    print("=" * 60)
    s = result.summary()

    print(f"\n  [Alerts — Pine alertcondition()]")
    print(f"    Total fired  : {s['total_alerts']}")
    print(f"    Bright alerts: {s['bright_alerts']}  (EXXE PROTOCOL: Long/Short [BRIGHT])")
    print(f"    Dark alerts  : {s['dark_alerts']}  (EXXE PROTOCOL: Long/Short [DARK])")

    print(f"\n  [Trade Simulator]")
    print(f"    Total trades : {s['total_trades']}")
    print(f"    Closed       : {s['closed_trades']}")
    print(f"    Open (EOD)   : {s['open_trades']}")
    print(f"    Winners (≥TP1) : {s['winners']}")
    print(f"    Losers  (<TP1) : {s['losers']}")
    print(f"    Win Rate       : {s['win_rate_pct']:.1f}%")
    print(f"    Avg Winner RR  : {s['avg_winner_rr']:.2f}R")
    print(f"    Expectancy     : {s['expectancy']:.4f}R per trade")

    print(f"\n  [By Tier]")
    print(f"    Bright trades  : {s['bright_trades']}")
    print(f"    Bright win rate: {s['bright_win_rate']:.1f}%")
    print(f"    Dark trades    : {s['dark_trades']}")
    print(f"    Dark win rate  : {s['dark_win_rate']:.1f}%")

    # ── Pine mapping reminder ─────────────────────────────────────────────────
    print()
    print("=" * 60)
    print("Pine Script → Python mapping")
    print("=" * 60)
    print("  alertcondition(base_Buy)    → AlertEvent(LONG_EXECUTION)")
    print("  alertcondition(base_Sell)   → AlertEvent(SHORT_EXECUTION)")
    print("  TradeSetup.sl_price         → ta.lowest(low, sl_lookback)[1]")
    print("  TradeSetup.tp1..5           → entry ± risk * 1..5")
    print("  Smart SL label (hidden)     → trade.tp1_hit = True before SL")
    print("  trade_direction = 0         → active_trade = None (flat)")
    print("  trade_direction = 1 / -1    → active_trade: TradeSetup (long/short)")