// =============================================================================
// FILE: lib/hooks/login_hook.dart
//
// FIX LOG:
//   1. URL: /auth/login → /login
//      → main.py pakai app.include_router(router_autentikasi) TANPA prefix
//      → jadi endpoint langsung /login, /register, /refresh — tanpa /auth
//
//   2. Error parsing: data['message'] → data['detail']
//      → FastAPI selalu return {"detail": "..."} bukan {"message": "..."}
//      → Sebelumnya selalu throw "Gagal login" karena field-nya ga ketemu
//
//   3. Validasi refresh_token dari response
//      → Kalau backend ga return refresh_token → throw error jelas
//      → Jangan simpan empty string ke storage
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/auth_storage.dart';

Future<Map<String, dynamic>> LoginHook({
  required String email,
  required String password,
}) async {
  try {
    // ── FIX #1: /login tanpa prefix ──────────────────────────────────────
    // main.py: app.include_router(router_autentikasi)  ← ga ada prefix="/auth"
    // endpoint = /login, /register, /refresh — bukan /auth/login dst.
    final response = await AuthStorage.post(
       '/login',
      body: {'email': email, 'password': password},
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final accessToken  = data['access_token']  as String?;
      final refreshToken = data['refresh_token'] as String?;
      final user         = data['user']           as Map<String, dynamic>?;

      // ── FIX #3: Validasi field sebelum disimpan ──────────────────────
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Response tidak mengandung access_token');
      }
      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception('Response tidak mengandung refresh_token');
      }
      if (user == null) {
        throw Exception('Response tidak mengandung data user');
      }

      await AuthStorage.saveSession(
        token:        accessToken,
        refreshToken: refreshToken,
        userId:       user['id'].toString(),
        email:        user['email'] as String,
        role:         user['role']  as String,
        name:         user['name']  as String,
      );

      return data;
    }

    // ── FIX #2: FastAPI return 'detail', bukan 'message' ─────────────────
    final detail   = data['detail'];
    final errorMsg = detail is String
        ? detail
        : detail?.toString() ?? 'Login gagal (status ${response.statusCode})';

    throw Exception(errorMsg);

  } on Exception {
    rethrow;
  } catch (e) {
    throw Exception('Gagal terhubung ke server: $e');
  }
}