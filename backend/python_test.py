# EXXE.LAB Script Editor
# Role: Exclusive — User: BTC-USDT

def strategy(close: list, period: int = 14) -> dict:
    """
    Custom trading strategy.
    Returns: { "signal": "buy" | "sell" | "hold", "value": float }
    """
    if len(close) < period:
        return {"signal": "hold", "value": 0.0}

    avg  = sum(close[-period:]) / period
    last = close[-1]

    if last > avg * 1.02:
        return {"signal": "buy",  "value": last}
    elif last < avg * 0.98:
        return {"signal": "sell", "value": last}
    return {"signal": "hold", "value": last}


if __name__ == "__main__":
    prices = [100, 102, 104, 103, 107, 110, 108, 112,
              115, 113, 116, 118, 120, 119, 122, 125]
    result = strategy(prices)
    print(f"Signal: {result['signal']} @ {result['value']:.2f}")
