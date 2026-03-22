import midtransclient # ini wajib lu install btw!
from fastapi import Request, APIRouter, HTTPException, Body
import os
from model.user_model import UserModel, UserRole
from database.postgres_sql import Postgres_SQL
from controller.autentikasi_controller import router_autentikasi
from dotenv import load_dotenv
from datetime import datetime, timedelta
import time

# Kita set lokasi .env nya
# biar si python nya ngerti di mana lokasi .env nya
path_env = os.path.join(os.path.dirname(__file__), ".env")
load_dotenv(dotenv_path=path_env)

router_payment = APIRouter()

# setup SDK
# disini kita siapkan api nya 
# kenapa pakai fungsi snap?
# karna pembeli gk perlu perhi ke mana mana
# cukup tinggal klik bayar muncul kotak kecil atau pop up 
snap = midtransclient.Snap(
    is_production=False,
    server_key = os.getenv('MIDTRANS_SERVER_KEY'),
    client_key = os.getenv('MIDTRANS_CLIENT_KEY')
)

# Ini target price yang kita incar
PLAN_PRICING = {
    "monthly": {
        "name": "Paket Bulanan",
        "price": 1000000,
        "months": 1
    },
    "semi_annual": {
        "name": "Paket 6 Bulan",
        "price": 4000000,
        "months": 6
    },
    "annual": {
        "name": "Paket Tahunan",
        "price": 6000000,
        "months": 12
    }
}


# kita buat fungsi checkout nya
# biar bisa kelihatan apakah pembayaran nya sudah di terima atau belum
# kalau tanpa fungsi ini bakal susah sih
@router_payment.post('/checkout')
async def checkout(amount: int, 
                   customer_name: str, 
                   customer_email: str,
                   plan_type: str = Body(..., embed=True)):

    # validasi plan harga nya
    if plan_type not in PLAN_PRICING:
        raise HTTPException(status_code=400, detail="Paket tidak valid cuy!")
    
    selected_plan = PLAN_PRICING[plan_type]
    # Buat Order ID unik biar gak bentrok (Contoh: TRX-170456789)
    order_id = f"INV-{int(time.time())}-{plan_type}"

    # Parameter yang lebih lengkap & Optimized buat Indonesia
    param = {
        "transaction_details": {
            "order_id": order_id,
            "gross_amount": selected_plan["price"] # Harga otomatis dari server
        },
        "item_details": [{
            "id": plan_type,
            "price": selected_plan["price"],
            "quantity": 1,
            "name": selected_plan["name"]
        }],
        "customer_details": {
            "first_name": customer_name,
            "email": customer_email,
        },
        "enabled_payments": ["qris", "gopay", "shopeepay", "bca_va", "bni_va", "bri_va", "mandiri_clickpay"],
        "expiry": {
            "unit": "minutes",
            "duration": 60 # User punya waktu 1 jam buat bayar
        }
    }
    
    try:
        # Panggil API Midtrans
        transaction = snap.create_transaction(param)
        
        # Ini masukin ke database
        # jadi kita buat transaksi tabel di postgress sql
        connection, cursor = Postgres_SQL()
        try:
            # ini harus buat tabel 
            # transaction dulu
            query = """
                INSERT INTO transactions 
                (order_id, user_email, plan_type, amount, status) 
                VALUES (%s, %s, %s, %s, %s)
            """
            cursor.execute(query, (
                order_id,
                customer_email,
                plan_type,
                selected_plan["price"],
                'pending'
            ))
            connection.get_connection().commit()
        finally:
            connection.close_connection()

        # Kalau sukses nanti akan muncul seperti ini
        # di log backend gw
        return {
            "status": "success",
            "message": f"Silahkan bayar untuk paket {selected_plan['name']}",
            "amount": selected_plan["price"],
            "redirect_url": transaction['redirect_url'],
            "order_id": order_id
        }
    
    except Exception as e:
        # Log errornya kalau gagal
        raise HTTPException(status_code=500, detail=str(e))
    
# Disini gw buat webhook biar bisa
# menerima kabar dari midtrans kalau user udah bayar
@router_payment.post('/notification')
async def payment_notification(request: Request):
    data = await request.json()
    
    # Ambil status transaksinya
    transaction_status = data.get('transaction_status')
    order_id = data.get('order_id')
    
    # koneksi ke database dulu yakan
    connection, cursor = Postgres_SQL()

    try:
        # Ambil data transaksi dari database
        cursor.execute(
            "SELECT user_email, plan_type, status FROM transactions WHERE order_id = %s",
            (order_id,)
        )
        result = cursor.fetchone()
        
        if not result:
            print(f"Order tidak ditemukan: {order_id}")
            return {"status": "order_not_found"}
        
        # Handle result dict atau tuple
        if isinstance(result, dict):
            user_email = result['user_email']
            plan_type = result['plan_type']
            current_status = result['status']
        else:
            user_email, plan_type, current_status = result[0], result[1], result[2]
        
        # Kalau transaksi sukses (settlement)
        if transaction_status == 'settlement':
            # Update status transaksi jadi PAID
            cursor.execute(
                "UPDATE transactions SET status = %s, updated_at = %s WHERE order_id = %s",
                ('paid', datetime.now(), order_id)
            )
            
            # Upgrade user ke EXCLUSIVE
            months = PLAN_PRICING[plan_type]["months"]
            days_to_limit = months * 30
            exclusive_until = datetime.now() + timedelta(days=days_to_limit)
            
            cursor.execute(
                "UPDATE users SET role = %s, exclusive_until = %s WHERE email = %s",
                (UserRole.EXCLUSIVE, exclusive_until, user_email)
            )
            
            connection.get_connection().commit()
            print(f"✅ Pembayaran sukses! User {user_email} sekarang EXCLUSIVE sampai {exclusive_until}")
        
        # Kalau transaksi gagal
        elif transaction_status in ['cancel', 'deny', 'expire']:
            cursor.execute(
                "UPDATE transactions SET status = %s, updated_at = %s WHERE order_id = %s",
                ('failed', datetime.now(), order_id)
            )
            connection.get_connection().commit()
            print(f"❌ Pembayaran gagal: {order_id}")
        
        return {"status": "ok"}
    
    except Exception as e:
        connection.get_connection().rollback()
        print(f"Error processing webhook: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    
    finally:
        connection.close_connection()

