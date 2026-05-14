import httpx
from fastapi import Request, APIRouter, HTTPException, Body, BackgroundTasks
import os
from model.user_model import UserModel, UserRole
from database.postgres_sql import Postgres_SQL
from dotenv import load_dotenv
from datetime import datetime
import time
import asyncio
from dateutil.relativedelta import relativedelta

# Load .env
path_env = os.path.join(os.path.dirname(__file__), ".env")
load_dotenv(dotenv_path=path_env)
bsc_trace_url = os.getenv("BSC_TRACE_URL")

router_payment = APIRouter()

# ─────────────────────────────────────────────
#   BSC / Web3 Config
# ─────────────────────────────────────────────
WALLET_ADDRESS    = "0xdF77f7eEA03613A4Dd8ee2e2a002b16C4CA28d45"
USDT_CONTRACT_BSC = "0x55d398326f99059fF775485246999027B3197955"
BSCSCAN_API_KEY   = os.getenv("BSCSCAN_API_KEY")
DISCORD_INVITE    = os.getenv("DISCORD_INVITE_LINK")
USDT_DECIMALS     = 18

# ─────────────────────────────────────────────
#   Harga paket dalam USDT
# ─────────────────────────────────────────────
PLAN_PRICING = {
    "monthly": {
        "name":       "Paket Bulanan",
        "price_usdt": 65,
        "months":     1
    },
    "semi_annual": {
        "name":       "Paket 6 Bulan",
        "price_usdt": 250,
        "months":     6
    },
    "annual": {
        "name":       "Paket Tahunan",
        "price_usdt": 375,
        "months":     12
    }
}

# ─────────────────────────────────────────────
#   Validator: format wallet address EVM
# ─────────────────────────────────────────────
def is_valid_wallet(address: str) -> bool:
    """Cek format wallet address EVM: 0x + 40 hex chars."""
    import re
    return bool(re.fullmatch(r"0x[0-9a-fA-F]{40}", address))

def usdt_to_wei(amount_usdt: float) -> int:
    return int(amount_usdt * (10 ** USDT_DECIMALS))


# ─────────────────────────────────────────────
#   Background Task: verifikasi pembayaran USDT
# ─────────────────────────────────────────────
async def verify_usdt_payment(
    order_id:      str,
    expected_usdt: float,
    user_wallet:   str,   # ganti dari user_email
    plan_type:     str,
    created_at_ts: int
):
    expected_wei = usdt_to_wei(expected_usdt)
    deadline     = time.time() + 3600

    while time.time() < deadline:
        await asyncio.sleep(30)

        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.get(
                    "https://api.bscscan.com/api",
                    params={
                        "module":          "account",
                        "action":          "tokentx",
                        "contractaddress": USDT_CONTRACT_BSC,
                        "address":         WALLET_ADDRESS,
                        "sort":            "desc",
                        "apikey":          BSCSCAN_API_KEY,
                    }
                )
                data = resp.json()

            if data.get("status") != "1" or not data.get("result"):
                continue

            for tx in data["result"]:
                tx_to        = tx["to"].lower()
                tx_value     = int(tx["value"])
                tx_hash      = tx["hash"]
                tx_timestamp = int(tx["timeStamp"])

                if (
                    tx_to    == WALLET_ADDRESS.lower() and
                    tx_value == expected_wei and
                    tx_timestamp >= created_at_ts
                ):
                    connection, cursor = Postgres_SQL()
                    try:
                        cursor.execute(
                            "SELECT status FROM transactions WHERE order_id = %s",
                            (order_id,)
                        )
                        row    = cursor.fetchone()
                        status = row["status"] if isinstance(row, dict) else row[0]

                        if status != "pending":
                            return

                        cursor.execute(
                            "SELECT COUNT(*) FROM transactions WHERE tx_hash = %s",
                            (tx_hash,)
                        )
                        count_row = cursor.fetchone()
                        count     = count_row["count"] if isinstance(count_row, dict) else count_row[0]

                        if count > 0:
                            continue

                        cursor.execute(
                            """
                            UPDATE transactions
                            SET status = %s, tx_hash = %s, updated_at = %s
                            WHERE order_id = %s
                            """,
                            ("paid", tx_hash, datetime.now(), order_id)
                        )

                        # ── Update role user by wallet address ──
                        months = PLAN_PRICING[plan_type]["months"]
                        now    = datetime.now()

                        cursor.execute(
                            "SELECT role, exclusive_until FROM users WHERE wallet_address = %s",
                            (user_wallet.lower(),)
                        )
                        user_data     = cursor.fetchone()
                        current_role  = user_data["role"]           if isinstance(user_data, dict) else user_data[0]
                        current_until = user_data["exclusive_until"] if isinstance(user_data, dict) else user_data[1]

                        base_date = (
                            current_until
                            if current_role == UserRole.EXCLUSIVE and current_until and current_until > now
                            else now
                        )
                        exclusive_until = base_date + relativedelta(months=months)

                        cursor.execute(
                            "UPDATE users SET role = %s, exclusive_until = %s WHERE wallet_address = %s",
                            (UserRole.EXCLUSIVE, exclusive_until, user_wallet.lower())
                        )

                        connection.get_connection().commit()
                        print(f"[Payment] ✅ Order {order_id} PAID | wallet: {user_wallet} | tx: {tx_hash}")
                        return

                    except Exception as inner_e:
                        connection.get_connection().rollback()
                        print(f"[Payment] DB error on {order_id}: {inner_e}")
                    finally:
                        connection.close_connection()

        except Exception as e:
            print(f"[Payment] BSCScan fetch error: {e}")
            continue

    # ── Timeout: order expired ──
    connection, cursor = Postgres_SQL()
    try:
        cursor.execute(
            "UPDATE transactions SET status = %s, updated_at = %s WHERE order_id = %s",
            ("expired", datetime.now(), order_id)
        )
        connection.get_connection().commit()
        print(f"[Payment] ⏰ Order {order_id} EXPIRED")
    finally:
        connection.close_connection()


# ─────────────────────────────────────────────
#   POST /checkout
# ─────────────────────────────────────────────
@router_payment.post("/checkout")
async def checkout(
    background_tasks: BackgroundTasks,
    user_wallet: str,                           # wallet address user (query param)
    plan_type:   str = Body(..., embed=True)    # monthly | semi_annual | annual
):
    if not is_valid_wallet(user_wallet):
        raise HTTPException(
            status_code=400,
            detail="Format wallet address tidak valid. Pastikan format EVM: 0x..."
        )

    if plan_type not in PLAN_PRICING:
        raise HTTPException(status_code=400, detail="Paket tidak valid.")

    selected_plan  = PLAN_PRICING[plan_type]
    order_id       = f"INV-{int(time.time())}-{plan_type}"
    created_at_ts  = int(time.time())
    normalized_wallet = user_wallet.lower()

    connection, cursor = Postgres_SQL()
    try:
        cursor.execute(
            """
            INSERT INTO transactions
            (order_id, user_wallet, plan_type, amount_usdt, status, created_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (
                order_id,
                normalized_wallet,
                plan_type,
                selected_plan["price_usdt"],
                "pending",
                datetime.now()
            )
        )
        connection.get_connection().commit()
    finally:
        connection.close_connection()

    background_tasks.add_task(
        verify_usdt_payment,
        order_id,
        selected_plan["price_usdt"],
        normalized_wallet,
        plan_type,
        created_at_ts
    )

    return {
        "status":         "success",
        "order_id":       order_id,
        "plan":           selected_plan["name"],
        "amount_usdt":    selected_plan["price_usdt"],
        "wallet_address": WALLET_ADDRESS,         # wallet tujuan (business)
        "user_wallet":    normalized_wallet,      # wallet pengirim (user)
        "network":        "BNB Smart Chain (BEP-20)",
        "token":          "USDT",
        "expires_in":     "60 menit",
        "note": (
            f"Kirim TEPAT {selected_plan['price_usdt']} USDT ke alamat di atas. "
            f"Pastikan kirim dari wallet {normalized_wallet}."
        )
    }


# ─────────────────────────────────────────────
#   GET /status/{order_id}
# ─────────────────────────────────────────────
@router_payment.get("/status/{order_id}")
async def payment_status(order_id: str):
    connection, cursor = Postgres_SQL()
    try:
        cursor.execute(
            "SELECT status, tx_hash, amount_usdt, plan_type, user_wallet FROM transactions WHERE order_id = %s",
            (order_id,)
        )
        row = cursor.fetchone()

        if not row:
            raise HTTPException(status_code=404, detail="Order tidak ditemukan")

        if isinstance(row, dict):
            status      = row["status"]
            tx_hash     = row["tx_hash"]
            amount      = row["amount_usdt"]
            plan_type   = row["plan_type"]
            user_wallet = row["user_wallet"]
        else:
            status, tx_hash, amount, plan_type, user_wallet = \
                row[0], row[1], row[2], row[3], row[4]

        response = {
            "order_id":    order_id,
            "status":      status,
            "amount_usdt": amount,
            "plan":        PLAN_PRICING.get(plan_type, {}).get("name", plan_type),
            "user_wallet": user_wallet,
        }

        if status == "paid":
            response["tx_hash"]      = tx_hash
            response["tx_explorer"]  = bsc_trace_url.replace("{{tx_hash}}", tx_hash)
            response["discord_link"] = DISCORD_INVITE
            response["message"]      = "✅ Pembayaran berhasil! Join Discord lo di sini."
        elif status == "expired":
            response["message"] = "⏰ Order expired. Silakan checkout ulang."
        else:
            response["message"] = "⏳ Menunggu pembayaran..."

        return response

    finally:
        connection.close_connection()