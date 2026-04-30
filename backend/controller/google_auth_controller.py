# ============================================
# TAMBAHAN di: controller/autentikasi_controller.py
# ============================================
# Tambahkan import ini di bagian atas file existing lo:
#
#   from pydantic import BaseModel
#   import httpx
#
# Lalu tambahkan endpoint di bawah ini ke router_autentikasi
# ============================================

from pydantic import BaseModel
import httpx

# ── Request model ──────────────────────────────────────────────────────────────
class GoogleAuthRequest(BaseModel):
    id_token: str  # idToken dari google_sign_in Flutter package


# ── Helper: verify idToken ke Google ──────────────────────────────────────────
async def _verify_google_token(id_token: str) -> dict:
    """
    Verifikasi idToken ke Google tokeninfo endpoint.
    Return payload jika valid, raise HTTPException jika tidak.
    """
    url = f"https://oauth2.googleapis.com/tokeninfo?id_token={id_token}"
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(url)

    if resp.status_code != 200:
        raise HTTPException(
            status_code=401,
            detail="Google token tidak valid atau sudah expired"
        )

    payload = resp.json()

    # Pastikan token memang untuk app lo — ganti dengan CLIENT_ID lo
    # Bisa multiple client IDs (Android + iOS)
    ALLOWED_CLIENT_IDS = {
        "YOUR_ANDROID_CLIENT_ID.apps.googleusercontent.com",
        "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com",
    }

    aud = payload.get("aud", "")
    if aud not in ALLOWED_CLIENT_IDS:
        raise HTTPException(
            status_code=401,
            detail="Token bukan untuk aplikasi ini"
        )

    return payload  # berisi: email, name, picture, sub (google_id), dll.


# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT: POST /auth/google
# ══════════════════════════════════════════════════════════════════════════════
@router_autentikasi.post("/auth/google")
async def google_auth(body: GoogleAuthRequest):
    """
    Flow:
      1. Flutter kirim idToken hasil Google Sign-In
      2. Backend verify ke Google
      3. Cek user di DB:
         - Sudah ada → langsung login, return JWT
         - Belum ada → auto-register (tanpa password), return JWT
    """
    connection, cursor = get_db_connection()
    try:
        # 1. Verify token ke Google
        google_payload = await _verify_google_token(body.id_token)

        email       = google_payload.get("email", "").strip().lower()
        name        = google_payload.get("name", email.split("@")[0])
        google_id   = google_payload.get("sub", "")  # unique Google user ID
        picture_url = google_payload.get("picture", "")

        if not email:
            raise HTTPException(status_code=400, detail="Email tidak ditemukan di token Google")

        # 2. Cek user sudah ada atau belum
        cursor.execute(
            "SELECT id, name, role, exclusive_until FROM users WHERE email = %s",
            (email,)
        )
        result = cursor.fetchone()

        now = datetime.now()

        if result:
            # ── User sudah ada → login ────────────────────────────────────
            if isinstance(result, dict):
                user_id        = result['id']
                user_name      = result['name']
                role           = result['role']
                exclusive_until = result['exclusive_until']
            else:
                user_id, user_name, role, exclusive_until = result

            # Auto-downgrade jika exclusive expired
            if role == UserRole.EXCLUSIVE and exclusive_until and exclusive_until < now:
                role = UserRole.GENERAL
                cursor.execute(
                    "UPDATE users SET role = %s WHERE email = %s",
                    (UserRole.GENERAL, email)
                )
                connection.get_connection().commit()

            # Update google_id jika belum tersimpan (user lama daftar manual)
            cursor.execute(
                "UPDATE users SET google_id = %s WHERE email = %s AND google_id IS NULL",
                (google_id, email)
            )
            connection.get_connection().commit()

            logging.info(f"Google login: {email} (existing user, id={user_id})")

        else:
            # ── User belum ada → auto-register ───────────────────────────
            role = UserRole.GENERAL

            cursor.execute(
                """
                INSERT INTO users (name, email, password, role, google_id)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id
                """,
                (name, email, None, role, google_id)
                # password = NULL karena login via Google (tidak pakai password)
            )
            result_insert = cursor.fetchone()
            user_id   = result_insert["id"] if isinstance(result_insert, dict) else result_insert[0]
            user_name = name

            connection.get_connection().commit()
            logging.info(f"Google register: {email} (new user, id={user_id})")

        # 3. Buat JWT lo sendiri — payload sama dengan /login
        access_token = create_access_token({
            "user_id": user_id,
            "email":   email,
            "role":    role,
        })

        return {
            "success": True,
            "message": "Login dengan Google berhasil",
            "access_token": access_token,
            "user": {
                "id":      user_id,
                "name":    user_name,
                "email":   email,
                "role":    role,
                "picture": picture_url,
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        connection.get_connection().rollback()
        logging.error(f"Google auth error: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")
    finally:
        connection.close_connection()