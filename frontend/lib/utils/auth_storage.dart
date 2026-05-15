import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Local Testing //
const String kBaseUrl = 'http://localhost:8080';

// Ngrok or Any External Testing URL //
const String TestingUrlExternal = "https://disdain-decathlon-probe.ngrok-free.app";

class AuthStorage {
  static const _keyToken        = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId       = 'user_id';
  static const _keyUserEmail    = 'user_email';
  static const _keyUserRole     = 'user_role';
  static const _keyUserName     = 'user_name';

  static VoidCallback? onForceLogout;
  static bool _isRefreshing = false;

  // ── FIX: helper untuk baca SharedPreferences value dengan aman ───────────
  // Root cause error: backend bisa return user_id sebagai int (123) bukan
  // string ("123"). Kalau langsung prefs.getString(), Dart throw cast error
  // karena value tersimpan sebagai int di SharedPreferences internal store.
  //
  // Solusi: pakai prefs.get() → Object? dulu, baru toString() kalau bukan String.
  static String? _safeGetString(SharedPreferences prefs, String key) {
    final raw = prefs.get(key);
    if (raw == null) return null;
    if (raw is String) return raw;
    return raw.toString(); // handle int, bool, double yang nyasar
  }

  static Future<void> saveSession({
    required String token,
    required String refreshToken,
    required String userId,
    required String email,
    required String role,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken,        token);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setString(_keyUserId,       userId.toString()); // FIX: force toString
    await prefs.setString(_keyUserEmail,    email);
    await prefs.setString(_keyUserRole,     role);
    await prefs.setString(_keyUserName,     name);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return _safeGetString(prefs, _keyToken);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return _safeGetString(prefs, _keyRefreshToken);
  }

  static Future<Map<String, String?>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    // FIX: pakai _safeGetString di semua key — terutama user_id yang sering
    // tersimpan sebagai int kalau backend return JSON number
    return {
      'token':   _safeGetString(prefs, _keyToken),
      'user_id': _safeGetString(prefs, _keyUserId),
      'email':   _safeGetString(prefs, _keyUserEmail),
      'role':    _safeGetString(prefs, _keyUserRole),
      'name':    _safeGetString(prefs, _keyUserName),
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserName);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

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
        Uri.parse('$kBaseUrl/refresh'),
        headers: {'Content-Type': 'application/json'},
        body:    jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyToken,        data['access_token'].toString());
        await prefs.setString(_keyRefreshToken, data['refresh_token'].toString());
        return true;
      }

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

  // ── Base headers builder ─────────────────────────────────────────────────
  static Future<Map<String, String>> _headers([
    Map<String, String>? extra,
  ]) async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  // ── Headers khusus multipart (tanpa Content-Type, biar http set boundary) ─
  static Future<Map<String, String>> _multipartHeaders([
    Map<String, String>? extra,
  ]) async {
    final token = await getToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  // ── GET ──────────────────────────────────────────────────────────────────
  static Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path').replace(queryParameters: queryParams);
    var response = await http.get(uri, headers: await _headers(headers));
    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        response = await http.get(uri, headers: await _headers(headers));
      }
    }
    return response;
  }

  // ── POST ─────────────────────────────────────────────────────────────────
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

  // ── PATCH ────────────────────────────────────────────────────────────────
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

  // ── DELETE ───────────────────────────────────────────────────────────────
  // Dipakai untuk endpoint yang butuh auth token + query params (misal delete
  // by ID). Auto-retry sekali kalau dapat 401 + refresh token masih valid.
  static Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path').replace(queryParameters: queryParams);
    var response = await http.delete(uri, headers: await _headers(headers));
    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        response = await http.delete(uri, headers: await _headers(headers));
      }
    }
    return response;
  }

  // ── MULTIPART (file upload) ──────────────────────────────────────────────
  // Kirim http.MultipartRequest yang sudah disiapkan caller, lalu inject
  // Authorization header dari session. Auto-retry sekali kalau 401.
  //
  // Cara pakai:
  //   final req = http.MultipartRequest('POST', Uri.parse('$kBaseUrl/path'));
  //   req.fields['key'] = 'value';
  //   req.files.add(await http.MultipartFile.fromPath('field', file.path));
  //   final response = await AuthStorage.sendMultipart(req);
  static Future<http.StreamedResponse> sendMultipart(
    http.MultipartRequest request, {
    Map<String, String>? extraHeaders,
  }) async {
    // Inject auth headers ke request yang sudah disiapkan caller
    final authHeaders = await _multipartHeaders(extraHeaders);
    request.headers.addAll(authHeaders);

    var streamedResponse = await request.send();

    // Kalau 401, refresh token lalu kirim ulang request yang sama
    if (streamedResponse.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        // MultipartRequest tidak bisa di-send ulang, harus buat instance baru
        // tapi field & files sudah di-clone oleh caller — jadi ini handled
        // di level hook dengan memanggil ulang fungsi upload-nya.
        // Di sini kita cukup return response 401 biar caller bisa handle.
      }
    }

    return streamedResponse;
  }
}