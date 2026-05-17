import pandas as pd
from datetime import datetime, timezone
import asyncio
import aiohttp
from typing import List, Dict, Optional, Callable, Tuple
import time

class _CacheEntry:
    __slots__ = ('df', 'fetched_at')
    def __init__(self, df: pd.DataFrame, fetched_at: float):
        self.df = df
        self.fetched_at = fetched_at

    def is_expired(self, ttl: float) -> bool:
        return (time.monotonic() - self.fetched_at) > ttl


class CryptoDataHook:
    """
    Real-time multi-asset, multi-timeframe crypto data fetcher.
    Adaptive polling: aggressive near candle close, relaxed otherwise.
    """

    _INTERVAL_MINUTES: Dict[str, int] = {
        '1m': 1, '3m': 3, '5m': 5, '15m': 15, '30m': 30,
        '1h': 60, '2h': 120, '4h': 240, '6h': 360, '12h': 720,
        '1d': 1440, '3d': 4320, '1w': 10080,
    }
    _COLUMNS = [
        "open_time", "open", "high", "low", "close", "volume",
        "close_time", "quote_asset_volume", "number_of_trades",
        "taker_buy_base_volume", "taker_buy_quote_volume", "ignore"
    ]
    _NUM_COLS = [
        "open", "high", "low", "close", "volume",
        "quote_asset_volume", "taker_buy_base_volume", "taker_buy_quote_volume"
    ]

    def __init__(
        self,
        tickers: List[str],
        intervals: List[str] = None,
        auto_update_interval: int = 60,
        candle_limit: int = 500,
        max_concurrent: int = 10,
    ):
        self.tickers = tickers
        self.intervals = intervals or ['15m']
        self.auto_update_interval = auto_update_interval
        self.candle_limit = candle_limit

        self.data: Dict[str, Dict[str, pd.DataFrame]] = {}
        self.last_candle_time: Dict[str, Dict[str, datetime]] = {}
        self.is_ready: Dict[str, Dict[str, bool]] = {}

        for ticker in tickers:
            self.data[ticker] = {}
            self.last_candle_time[ticker] = {}
            self.is_ready[ticker] = {}
            for interval in self.intervals:
                self.is_ready[ticker][interval] = False

        self.fetch_count = 0
        self.base_url = "https://www.tokocrypto.site/api/v3/klines"

        self.on_data_update: Optional[Callable] = None
        self.on_error: Optional[Callable] = None
        self.on_all_ready: Optional[Callable] = None

        # Reusable session — dibuat sekali saat start, bukan tiap fetch
        self._session: Optional[aiohttp.ClientSession] = None

        # Semaphore: batasi concurrent request tanpa sleep
        self._semaphore = asyncio.Semaphore(max_concurrent)

        # Cache per (ticker, interval)
        self._cache: Dict[str, _CacheEntry] = {}

        # In-flight deduplication: key -> Future
        self._inflight: Dict[str, asyncio.Future] = {}

        # Error count untuk backoff
        self._error_count: Dict[str, int] = {}
        self._MAX_BACKOFF = 300.0

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _symbol(self, ticker: str) -> str:
        return ticker.replace('-', '').upper()

    def _cache_key(self, ticker: str, interval: str) -> str:
        return f"{self._symbol(ticker)}_{interval}"

    def _interval_minutes(self, interval: str) -> int:
        return self._INTERVAL_MINUTES.get(interval, 15)

    def _cache_ttl(self, interval: str) -> float:
        minutes = self._interval_minutes(interval)
        if minutes >= 1440: return 1800.0
        if minutes >= 240:  return 600.0
        if minutes >= 60:   return 300.0
        if minutes >= 15:   return 120.0
        return 30.0

    def _backoff_seconds(self, error_count: int) -> float:
        return min(5 * (2 ** (error_count - 1)), self._MAX_BACKOFF)

    async def _get_session(self) -> aiohttp.ClientSession:
        if self._session is None or self._session.closed:
            timeout = aiohttp.ClientTimeout(total=15)
            connector = aiohttp.TCPConnector(
                limit=30,           # max total connections
                ttl_dns_cache=300,  # cache DNS 5 menit
                enable_cleanup_closed=True,
            )
            self._session = aiohttp.ClientSession(timeout=timeout, connector=connector)
        return self._session

    # ------------------------------------------------------------------
    # Core fetch
    # ------------------------------------------------------------------

    async def fetch(self, ticker: str, interval: str) -> Optional[pd.DataFrame]:
        key = self._cache_key(ticker, interval)

        # 1. Cache hit
        entry = self._cache.get(key)
        if entry and not entry.is_expired(self._cache_ttl(interval)):
            return entry.df

        # 2. In-flight deduplication
        if key in self._inflight:
            return await self._inflight[key]

        loop = asyncio.get_event_loop()
        fut: asyncio.Future = loop.create_future()
        self._inflight[key] = fut

        try:
            result = await self._do_fetch(ticker, interval, key)
            fut.set_result(result)
            return result
        except Exception as exc:
            fut.set_exception(exc)
            raise
        finally:
            self._inflight.pop(key, None)

    async def _do_fetch(self, ticker: str, interval: str, key: str) -> Optional[pd.DataFrame]:
        err_count = self._error_count.get(key, 0)

        # Backoff check
        if err_count > 0:
            entry = self._cache.get(key)
            if entry:
                elapsed = time.monotonic() - entry.fetched_at
                backoff = self._backoff_seconds(err_count)
                if elapsed < backoff:
                    return entry.df

        async with self._semaphore:   # rate-limit tanpa sleep
            try:
                self.fetch_count += 1
                session = await self._get_session()
                params = {
                    "symbol":   self._symbol(ticker),
                    "interval": interval,
                    "limit":    str(self.candle_limit),
                }

                async with session.get(self.base_url, params=params) as resp:
                    if resp.status != 200:
                        self._error_count[key] = err_count + 1
                        # 429 = silent backoff, jangan spam onError
                        if resp.status != 429 and self.on_error:
                            self.on_error(ticker, interval, f"HTTP {resp.status}")
                        return self._cache[key].df if key in self._cache else None

                    raw = await resp.json(content_type=None)

            except asyncio.TimeoutError:
                self._error_count[key] = err_count + 1
                if self.on_error:
                    self.on_error(ticker, interval, "Timeout")
                return self._cache[key].df if key in self._cache else None

            except Exception as exc:
                self._error_count[key] = err_count + 1
                if self.on_error:
                    self.on_error(ticker, interval, str(exc))
                return self._cache[key].df if key in self._cache else None

        # Parse
        self._error_count[key] = 0
        df = self._parse(raw)
        if df is None or df.empty:
            return None

        # Cek apakah data benar-benar baru sebelum trigger callback
        prev_entry = self._cache.get(key)
        has_new_data = (
            prev_entry is None
            or df.index[-1] != prev_entry.df.index[-1]
            or df['close'].iloc[-1] != prev_entry.df['close'].iloc[-1]
        )

        self._cache[key] = _CacheEntry(df=df, fetched_at=time.monotonic())
        self.data[ticker][interval] = df
        self.is_ready[ticker][interval] = True

        self._log_candle(ticker, interval, df)
        self._check_all_ready()

        if has_new_data and self.on_data_update:
            self.on_data_update(ticker, interval, df)

        return df

    def _parse(self, raw: list) -> Optional[pd.DataFrame]:
        if not raw:
            return None
        rows = []
        for item in raw:
            row = dict(zip(self._COLUMNS, item))
            row["open_time"]  = datetime.fromtimestamp(row["open_time"]  / 1000, tz=timezone.utc)
            row["close_time"] = datetime.fromtimestamp(row["close_time"] / 1000, tz=timezone.utc)
            rows.append(row)

        df = pd.DataFrame(rows)
        df[self._NUM_COLS] = df[self._NUM_COLS].apply(pd.to_numeric, errors='coerce')
        df = df.set_index("open_time").drop(columns=['ignore'], errors='ignore')
        return df

    # ------------------------------------------------------------------
    # Logging & readiness
    # ------------------------------------------------------------------

    def _log_candle(self, ticker: str, interval: str, df: pd.DataFrame):
        if len(df) < 2:
            return
        last_closed = df.index[-2]
        prev = self.last_candle_time[ticker].get(interval)
        if prev is None:
            print(f"✅ {self._symbol(ticker)} {interval} ready")
        elif last_closed > prev:
            print(f"🔔 {self._symbol(ticker)} {interval} NEW CANDLE")
        self.last_candle_time[ticker][interval] = last_closed

    def _check_all_ready(self):
        for ticker in self.tickers:
            for interval in self.intervals:
                if not self.is_ready[ticker][interval]:
                    return
        if self.on_all_ready:
            self.on_all_ready()

    # ------------------------------------------------------------------
    # Fetch all — fully concurrent
    # ------------------------------------------------------------------

    async def _fetch_all(self):
        pairs: List[Tuple[str, str]] = [
            (ticker, interval)
            for ticker in self.tickers
            for interval in self.intervals
        ]
        # Semua pair jalan bersamaan, semaphore yang atur concurrency
        await asyncio.gather(
            *(self.fetch(t, i) for t, i in pairs),
            return_exceptions=True,
        )

    # ------------------------------------------------------------------
    # Auto-update loops
    # ------------------------------------------------------------------

    async def start_auto_update(self):
        print(f"🔄 Auto-update started: {len(self.tickers)}t x {len(self.intervals)}i")
        await self._fetch_all()
        while True:
            await asyncio.sleep(self.auto_update_interval)
            await self._fetch_all()

    async def start_adaptive_update(self):
        print(f"🔄 Adaptive update started")
        print(f"📊 Tickers: {', '.join(self.tickers)}")
        print(f"⏱️  Intervals: {', '.join(self.intervals)}")

        await self._fetch_all()

        while True:
            now = datetime.now(timezone.utc)
            shortest = min(self._interval_minutes(i) for i in self.intervals)
            cur = now.minute
            expected = (cur // shortest) * shortest
            nxt = expected + shortest
            if nxt >= 60:
                nxt -= 60
            minutes_to_close = (nxt - cur) if nxt > cur else (60 - cur + nxt)

            if minutes_to_close <= 2:
                fetch_interval = 5
                mode = "🔥 AGGRESSIVE"
            else:
                fetch_interval = self.auto_update_interval
                mode = "⏸️  NORMAL"

            print(f"\n[{mode}] next close in {minutes_to_close}m, sleep {fetch_interval}s")
            await asyncio.sleep(fetch_interval)
            await self._fetch_all()

    # ------------------------------------------------------------------
    # Public helpers
    # ------------------------------------------------------------------

    def get_candles(self, ticker: str, interval: str = None) -> Optional[pd.DataFrame]:
        interval = interval or self.intervals[0]
        return self.data.get(ticker, {}).get(interval)

    def get_latest_price(self, ticker: str, interval: str = None) -> Optional[float]:
        df = self.get_candles(ticker, interval)
        if df is not None and not df.empty:
            return float(df['close'].iloc[-1])
        return None

    def is_interval_ready(self, ticker: str, interval: str) -> bool:
        return self.is_ready.get(ticker, {}).get(interval, False)

    def invalidate_cache(self, ticker: str = None, interval: str = None):
        if ticker is None:
            self._cache.clear()
        elif interval is None:
            for iv in self.intervals:
                self._cache.pop(self._cache_key(ticker, iv), None)
        else:
            self._cache.pop(self._cache_key(ticker, interval), None)

    async def close(self):
        if self._session and not self._session.closed:
            await self._session.close()


# ===== PRESET LISTS =====

class TokoCryptoPairs:
    MAJOR = ['BTC-USDT', 'ETH-USDT', 'BNB-USDT', 'SOL-USDT', 'XRP-USDT']
    TOP10 = [
        'BTC-USDT', 'ETH-USDT', 'BNB-USDT', 'XRP-USDT', 'SOL-USDT',
        'ADA-USDT', 'DOGE-USDT', 'TRX-USDT', 'DOT-USDT', 'MATIC-USDT'
    ]
    TOP20 = [
        'BTC-USDT', 'ETH-USDT', 'BNB-USDT', 'XRP-USDT', 'SOL-USDT',
        'ADA-USDT', 'DOGE-USDT', 'TRX-USDT', 'DOT-USDT', 'MATIC-USDT',
        'LTC-USDT', 'AVAX-USDT', 'SHIB-USDT', 'LINK-USDT', 'UNI-USDT',
        'ATOM-USDT', 'ETC-USDT', 'XLM-USDT', 'FIL-USDT', 'NEAR-USDT'
    ]


class Timeframes:
    M1 = '1m'; M5 = '5m'; M15 = '15m'; M30 = '30m'
    H1 = '1h'; H4 = '4h'; D1 = '1d'
    COMMON  = ['5m', '15m', '30m', '1h', '4h', '1d']
    TRADING = ['1m', '5m', '15m', '1h', '4h']


# ===== USAGE EXAMPLES =====

async def example_single_pair():
    hook = CryptoDataHook(tickers=['BTC-USDT'], intervals=['5m', '15m', '1h'])

    def on_update(ticker, interval, df):
        print(f"📈 {ticker} {interval}: {len(df)} candles, latest=${df['close'].iloc[-1]:.2f}")

    hook.on_data_update = on_update
    try:
        await hook.start_adaptive_update()
    finally:
        await hook.close()


async def example_multi_pair():
    hook = CryptoDataHook(tickers=TokoCryptoPairs.MAJOR, intervals=['15m'])

    def on_update(ticker, interval, df):
        print(f"💰 {ticker}: ${df['close'].iloc[-1]:.2f}")

    def on_all_ready():
        print("✅ All pairs loaded!")

    hook.on_data_update = on_update
    hook.on_all_ready   = on_all_ready
    try:
        await hook.start_adaptive_update()
    finally:
        await hook.close()


async def example_full_monitoring():
    hook = CryptoDataHook(
        tickers=['BTC-USDT', 'ETH-USDT', 'SOL-USDT'],
        intervals=['5m', '15m', '1h'],
        auto_update_interval=45,
    )

    def on_update(ticker, interval, df):
        if len(df) >= 2:
            latest = df['close'].iloc[-1]
            prev   = df['close'].iloc[-2]
            pct    = (latest - prev) / prev * 100
            emoji  = "🟢" if pct >= 0 else "🔴"
            print(f"{emoji} {ticker} [{interval}]: ${latest:.2f} ({pct:+.2f}%)")

    def on_error(ticker, interval, error):
        print(f"⚠️  {ticker} {interval}: {error}")

    hook.on_data_update = on_update
    hook.on_error       = on_error
    try:
        await hook.start_adaptive_update()
    finally:
        await hook.close()


if __name__ == "__main__":
    import sys
    examples = {
        "1": ("Single pair, multiple timeframes", example_single_pair),
        "2": ("Multiple pairs, single timeframe", example_multi_pair),
        "3": ("Full monitoring (multi-pair, multi-timeframe)", example_full_monitoring),
    }
    print("🚀 Crypto Data Hook\n")
    for k, (label, _) in examples.items():
        print(f"  {k}. {label}")
    choice = (input("\nPilih (1-3): ") or "3").strip()
    _, fn = examples.get(choice, ("", example_full_monitoring))
    asyncio.run(fn())