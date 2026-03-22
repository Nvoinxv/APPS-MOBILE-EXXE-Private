import pandas as pd
from datetime import datetime, timezone
import asyncio
import aiohttp
from typing import List, Dict, Optional, Callable

class CryptoDataHook:
    """
    Real-time multi-asset, multi-timeframe crypto data fetcher
    Adaptive polling: aggressive near candle close, relaxed otherwise
    """
    
    def __init__(
        self, 
        tickers: List[str], 
        intervals: List[str] = None,
        auto_update_interval: int = 60
    ):
        """
        Args:
            tickers: List of trading pairs e.g. ['BTC-USDT', 'ETH-USDT']
            intervals: List of timeframes e.g. ['5m', '15m', '1h']
            auto_update_interval: Base polling interval in seconds
        """
        self.tickers = tickers
        self.intervals = intervals or ['15m']
        self.auto_update_interval = auto_update_interval
        
        # Data structure: ticker -> interval -> DataFrame
        self.data: Dict[str, Dict[str, pd.DataFrame]] = {}
        self.last_candle_time: Dict[str, Dict[str, datetime]] = {}
        self.is_ready: Dict[str, Dict[str, bool]] = {}
        
        # Initialize structures
        for ticker in tickers:
            self.data[ticker] = {}
            self.last_candle_time[ticker] = {}
            self.is_ready[ticker] = {}
            for interval in self.intervals:
                self.is_ready[ticker][interval] = False
        
        self.fetch_count = 0
        self.base_url = "https://www.tokocrypto.site/api/v3/klines"
        
        # Callbacks
        self.on_data_update: Optional[Callable] = None
        self.on_error: Optional[Callable] = None
        self.on_all_ready: Optional[Callable] = None
        
        self.columns = [
            "open_time", "open", "high", "low", "close", "volume",
            "close_time", "quote_asset_volume", "number_of_trades",
            "taker_buy_base_volume", "taker_buy_quote_volume", "ignore"
        ]
    
    def _get_symbol(self, ticker: str) -> str:
        """Convert BTC-USDT to BTCUSDT"""
        return ticker.replace('-', '').upper()
    
    def _get_interval_minutes(self, interval: str) -> int:
        """Convert interval string to minutes"""
        interval_map = {
            '1m': 1, '3m': 3, '5m': 5, '15m': 15, '30m': 30,
            '1h': 60, '2h': 120, '4h': 240, '6h': 360, '12h': 720,
            '1d': 1440, '3d': 4320, '1w': 10080,
        }
        return interval_map.get(interval, 15)
    
    async def fetch(self, ticker: str, interval: str, limit: int = 500) -> Optional[pd.DataFrame]:
        """
        Fetch klines data for specific ticker and interval
        """
        try:
            self.fetch_count += 1
            symbol = self._get_symbol(ticker)
            
            params = {
                "symbol": symbol,
                "interval": interval,
                "limit": str(limit)
            }
            
            timeout = aiohttp.ClientTimeout(total=30)
            
            async with aiohttp.ClientSession() as session:
                async with session.get(self.base_url, params=params, timeout=timeout) as response:
                    
                    if response.status != 200:
                        error_msg = f"HTTP {response.status}"
                        print(f"❌ {symbol} {interval}: {error_msg}")
                        if self.on_error:
                            self.on_error(ticker, interval, error_msg)
                        return None
                    
                    raw = await response.json()
            
            # Parse data
            klines = []
            for item in raw:
                row = dict(zip(self.columns, item))
                row["open_time"] = datetime.fromtimestamp(row["open_time"] / 1000, tz=timezone.utc)
                row["close_time"] = datetime.fromtimestamp(row["close_time"] / 1000, tz=timezone.utc)
                klines.append(row)
            
            df = pd.DataFrame(klines)
            
            # Convert numeric columns
            num_cols = ["open", "high", "low", "close", "volume",
                       "quote_asset_volume", "taker_buy_base_volume",
                       "taker_buy_quote_volume"]
            for col in num_cols:
                df[col] = pd.to_numeric(df[col], errors="coerce")
            
            df = df.set_index("open_time")
            df = df.drop(columns=['ignore'], errors='ignore')
            
            # Validate data freshness
            if len(df) >= 2:
                self._validate_and_log(ticker, interval, df)
            
            # Store data
            self.data[ticker][interval] = df
            self.is_ready[ticker][interval] = True
            
            # Trigger callback
            if self.on_data_update:
                self.on_data_update(ticker, interval, df)
            
            # Check if all data ready
            self._check_all_ready()
            
            return df
            
        except asyncio.TimeoutError:
            error_msg = "Timeout"
            print(f"⏱️ {ticker} {interval}: {error_msg}")
            if self.on_error:
                self.on_error(ticker, interval, error_msg)
            return None
            
        except Exception as e:
            error_msg = str(e)
            print(f"❌ {ticker} {interval}: {error_msg}")
            if self.on_error:
                self.on_error(ticker, interval, error_msg)
            return None
    
    def _validate_and_log(self, ticker: str, interval: str, df: pd.DataFrame):
        """Validate data freshness and log updates"""
        if len(df) < 2:
            return
        
        last_closed = df.index[-2]
        last_running = df.index[-1]
        now = datetime.now(timezone.utc)
        
        # Calculate running candle age
        running_age_minutes = (now - last_running).total_seconds() / 60
        interval_minutes = self._get_interval_minutes(interval)
        
        # Check if stale
        if running_age_minutes > interval_minutes + 1:
            stale_msg = f"Stale {running_age_minutes:.0f}m"
            print(f"⚠️ {self._get_symbol(ticker)} {interval}: {stale_msg}")
            if self.on_error:
                self.on_error(ticker, interval, stale_msg)
            return
        
        # Check for new candle
        prev_last = self.last_candle_time[ticker].get(interval)
        
        if prev_last is None:
            # First fetch
            print(f"✅ {self._get_symbol(ticker)} {interval} initialized")
        elif last_closed > prev_last:
            # New candle detected
            print(f"🔔 {self._get_symbol(ticker)} {interval} NEW CANDLE")
        
        self.last_candle_time[ticker][interval] = last_closed
    
    def _check_all_ready(self):
        """Check if all ticker-interval pairs are ready"""
        all_ready = all(
            self.is_ready[ticker][interval]
            for ticker in self.tickers
            for interval in self.intervals
        )
        
        if all_ready and self.on_all_ready:
            self.on_all_ready()
    
    async def start_adaptive_update(self):
        """
        Start adaptive polling with aggressive fetching near candle close
        """
        print(f"🔄 Multi-timeframe adaptive polling started")
        print(f"📊 Tickers: {', '.join(self.tickers)}")
        print(f"⏱️  Intervals: {', '.join(self.intervals)}")
        print(f"⚙️  Base interval: {self.auto_update_interval}s\n")
        
        # Initial fetch for all combinations
        for ticker in self.tickers:
            for interval in self.intervals:
                await self.fetch(ticker, interval)
                await asyncio.sleep(0.1)  # Prevent rate limiting
        
        # Continuous adaptive polling
        while True:
            try:
                now = datetime.now(timezone.utc)
                
                # Calculate time to next candle close (using shortest interval)
                shortest_interval = min(
                    self._get_interval_minutes(interval) 
                    for interval in self.intervals
                )
                
                current_minute = now.minute
                expected_minute = (current_minute // shortest_interval) * shortest_interval
                next_minute = expected_minute + shortest_interval
                if next_minute >= 60:
                    next_minute -= 60
                
                # Minutes until close
                if next_minute > current_minute:
                    minutes_to_close = next_minute - current_minute
                else:
                    minutes_to_close = (60 - current_minute) + next_minute
                
                # ADAPTIVE INTERVAL
                if minutes_to_close <= 2:
                    fetch_interval = 5  # Aggressive
                    mode = "🔥 AGGRESSIVE"
                else:
                    fetch_interval = self.auto_update_interval  # Normal
                    mode = "⏸️  NORMAL"
                
                # Fetch all ticker-interval pairs
                print(f"\n[{mode}] Fetching... (Next close in {minutes_to_close}m)")
                
                for ticker in self.tickers:
                    for interval in self.intervals:
                        await self.fetch(ticker, interval)
                        await asyncio.sleep(0.1)
                
                await asyncio.sleep(fetch_interval)
                
            except Exception as e:
                print(f"❌ Critical error in update loop: {e}")
                await asyncio.sleep(self.auto_update_interval)
    
    def get_candles(self, ticker: str, interval: str) -> Optional[pd.DataFrame]:
        """Get stored candles for ticker-interval"""
        return self.data.get(ticker, {}).get(interval)
    
    def is_interval_ready(self, ticker: str, interval: str) -> bool:
        """Check if specific ticker-interval is ready"""
        return self.is_ready.get(ticker, {}).get(interval, False)
    
    def get_latest_price(self, ticker: str, interval: str = None) -> Optional[float]:
        """Get latest close price"""
        interval = interval or self.intervals[0]
        df = self.get_candles(ticker, interval)
        if df is not None and len(df) > 0:
            return float(df['close'].iloc[-1])
        return None


# ===== PRESET TICKER LISTS =====
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
    M1 = '1m'
    M5 = '5m'
    M15 = '15m'
    M30 = '30m'
    H1 = '1h'
    H4 = '4h'
    D1 = '1d'
    
    COMMON = ['5m', '15m', '30m', '1h', '4h', '1d']
    TRADING = ['1m', '5m', '15m', '1h', '4h']


# ===== USAGE EXAMPLES =====
async def example_single_pair():
    """Example: Single pair, multiple timeframes"""
    hook = CryptoDataHook(
        tickers=['BTC-USDT'],
        intervals=['5m', '15m', '1h'],
        auto_update_interval=60
    )
    
    def on_update(ticker, interval, df):
        print(f"📈 {ticker} {interval}: {len(df)} candles, Latest: ${df['close'].iloc[-1]:.2f}")
    
    hook.on_data_update = on_update
    
    await hook.start_adaptive_update()


async def example_multi_pair():
    """Example: Multiple pairs, single timeframe"""
    hook = CryptoDataHook(
        tickers=TokoCryptoPairs.MAJOR,
        intervals=['15m'],
        auto_update_interval=60
    )
    
    def on_update(ticker, interval, df):
        if len(df) > 0:
            latest = df['close'].iloc[-1]
            print(f"💰 {ticker}: ${latest:.2f}")
    
    def on_all_ready():
        print("✅ All pairs loaded!")
    
    hook.on_data_update = on_update
    hook.on_all_ready = on_all_ready
    
    await hook.start_adaptive_update()


async def example_full_monitoring():
    """Example: Multi-pair, multi-timeframe with price monitoring"""
    hook = CryptoDataHook(
        tickers=['BTC-USDT', 'ETH-USDT', 'SOL-USDT'],
        intervals=['5m', '15m', '1h'],
        auto_update_interval=45
    )
    
    def on_update(ticker, interval, df):
        if len(df) >= 2:
            latest = df['close'].iloc[-1]
            prev = df['close'].iloc[-2]
            change_pct = ((latest - prev) / prev) * 100
            
            emoji = "🟢" if change_pct >= 0 else "🔴"
            print(f"{emoji} {ticker} [{interval}]: ${latest:.2f} ({change_pct:+.2f}%)")
    
    def on_error(ticker, interval, error):
        print(f"⚠️ Error {ticker} {interval}: {error}")
    
    hook.on_data_update = on_update
    hook.on_error = on_error
    
    await hook.start_adaptive_update()


if __name__ == "__main__":
    print("🚀 Crypto Data Hook - Multi-Asset Multi-Timeframe\n")
    print("Choose example:")
    print("1. Single pair, multiple timeframes")
    print("2. Multiple pairs, single timeframe")
    print("3. Full monitoring (multi-pair, multi-timeframe)")
    
    choice = input("\nEnter choice (1-3): ").strip()
    
    if choice == "1":
        asyncio.run(example_single_pair())
    elif choice == "2":
        asyncio.run(example_multi_pair())
    elif choice == "3":
        asyncio.run(example_full_monitoring())
    else:
        print("Running default: Full monitoring")
        asyncio.run(example_full_monitoring())