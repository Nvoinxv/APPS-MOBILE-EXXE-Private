// =============================================================================
// auth_storage.dart
// Path: frontend/lib/utils/auth_storage.dart
//
// Perubahan dari versi lama:
//   + simpan refresh_token di SharedPreferences
//   + refreshAccessToken() → hit POST /auth/refresh, update storage
//   + get() & post() → auto inject token + auto refresh kalau 401
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Ganti ke production URL kalau deploy
const String kBaseUrl = 'http://10.0.2.2:8080';

class AuthStorage {
  static const _keyToken        = 'access_token';
  static const _keyRefreshToken = 'refresh_token'; // ← BARU
  static const _keyUserId       = 'user_id';
  static const _keyUserEmail    = 'user_email';
  static const _keyUserRole     = 'user_role';
  static const _keyUserName     = 'user_name';

  // Callback — set dari main.dart atau root widget,
  // dipanggil kalau refresh gagal → paksa ke login screen
  static VoidCallback? onForceLogout;

  // Guard biar ga double-refresh kalau banyak request barengan
  static bool _isRefreshing = false;

  // ── Simpan semua data setelah login / register ──────────────────────────

  static Future<void> saveSession({
    required String token,
    required String refreshToken, // ← BARU (wajib sekarang)
    required String userId,
    required String email,
    required String role,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken,        token);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setString(_keyUserId,       userId);
    await prefs.setString(_keyUserEmail,    email);
    await prefs.setString(_keyUserRole,     role);
    await prefs.setString(_keyUserName,     name);
  }

  // ── Baca token ────────────────────────────────────────────────────────────

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  // ── Baca semua data user ──────────────────────────────────────────────────

  static Future<Map<String, String?>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'token':   prefs.getString(_keyToken),
      'user_id': prefs.getString(_keyUserId),
      'email':   prefs.getString(_keyUserEmail),
      'role':    prefs.getString(_keyUserRole),
      'name':    prefs.getString(_keyUserName),
    };
  }

  // ── Hapus semua saat logout ───────────────────────────────────────────────

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserName);
  }

  // ── Cek apakah user sudah login ───────────────────────────────────────────

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── Refresh access token ──────────────────────────────────────────────────
  // Panggil POST /auth/refresh, simpan token baru, return true kalau berhasil

  static Future<bool> refreshAccessToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;

    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _forceLogout();
        return false;
      }

      final response = await http.post(
        Uri.parse('$kBaseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body:    jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyToken,        data['access_token']  as String);
        await prefs.setString(_keyRefreshToken, data['refresh_token'] as String);
        return true;
      }

      // Refresh token juga expired / invalid → logout paksa
      await _forceLogout();
      return false;

    } catch (_) {
      await _forceLogout();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  static Future<void> _forceLogout() async {
    await clearSession();
    onForceLogout?.call();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HTTP Helpers — pakai ini di semua hooks, bukan raw http.get/post
  //
  //  Auto flow:
  //    1. Inject Authorization header dari storage
  //    2. Kalau response 401 → coba refresh token sekali
  //    3. Kalau refresh berhasil → retry request dengan token baru
  //    4. Kalau refresh gagal → force logout
  // ─────────────────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _headers([
    Map<String, String>? extra,
  ]) async {
    final token = await getToken();
    return {
      'Content-Type':  'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  /// GET dengan auto-refresh
  static Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path').replace(
      queryParameters: queryParams,
    );

    var response = await http.get(uri, headers: await _headers(headers));

    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        response = await http.get(uri, headers: await _headers(headers));
      }
    }

    return response;
  }

  /// POST dengan auto-refresh
  static Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path');

    var response = await http.post(
      uri,
      headers: await _headers(headers),
      body:    body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        response = await http.post(
          uri,
          headers: await _headers(headers),
          body:    body != null ? jsonEncode(body) : null,
        );
      }
    }

    return response;
  }

  /// PATCH dengan auto-refresh
  static Future<http.Response> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path');

    var response = await http.patch(
      uri,
      headers: await _headers(headers),
      body:    body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        response = await http.patch(
          uri,
          headers: await _headers(headers),
          body:    body != null ? jsonEncode(body) : null,
        );
      }
    }

    return response;
  }
}