import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// MODE SWITCHER — HANYA UBAH INI
// ============================================================
// AppMode.maintenance → pakai URL list maintenance (localhost/ngrok)
// AppMode.production  → pakai URL list production (server deploy)
//
// Cukup ganti satu baris di bawah, semua method ikut otomatis.
// ============================================================
enum AppMode { maintenance, production }

const AppMode _mode = AppMode.maintenance; // ← GANTI DI SINI DOANG

// ============================================================
// URL CONFIG PER MODE — TestingUrlExternal
// Tambah/hapus URL di sini, tidak perlu ubah logik lain.
// Urutan = prioritas (index 0 dicoba duluan, berikutnya fallback).
// ============================================================
const Map<AppMode, List<String>> TestingUrlExternal = {
  AppMode.maintenance: [                       // Local dev utama
    'http://103.16.117.89:8080', // IP publik buat share ke teman gw
  ],
  AppMode.production: [
    'https://api.yourproduction.com',                 // Production utama
    // 'https://api-backup.yourproduction.com',       // Backup — uncomment kalau ada
  ],
};

class AuthStorage {
  static const _keyToken        = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId       = 'user_id';
  static const _keyUserEmail    = 'user_email';
  static const _keyUserRole     = 'user_role';
  static const _keyUserName     = 'user_name';

  static VoidCallback? onForceLogout;
  static bool _isRefreshing = false;

  // URL aktif di-cache supaya tidak loop setiap request.
  // Di-reset kalau koneksi gagal atau saat logout.
  static String? _activeBaseUrl;

  // Getter publik — untuk hook yang butuh build URI multipart secara manual
  // Fallback ke index 0 kalau belum ada request sebelumnya
  static String get activeBaseUrl =>
      _activeBaseUrl ?? TestingUrlExternal[_mode]!.first;

  // ── Helper baca SharedPreferences dengan aman ────────────────────────────
  // Root cause: backend bisa return user_id sebagai int (123) bukan string.
  // prefs.getString() throw cast error. Solusi: pakai prefs.get() → toString().
  static String? _safeGetString(SharedPreferences prefs, String key) {
    final raw = prefs.get(key);
    if (raw == null) return null;
    if (raw is String) return raw;
    return raw.toString();
  }

  // ============================================================
  // FALLBACK CORE
  // Coba URL satu per satu sesuai mode aktif (_mode).
  // Kalau _activeBaseUrl sudah ada, langsung pakai (skip loop).
  // Kalau URL aktif mati, reset dan fallback ke URL berikutnya.
  // ============================================================
  static Future<http.Response> _tryUrls(
    Future<http.Response> Function(String baseUrl) build,
  ) async {
    final urls = TestingUrlExternal[_mode]!;

    if (_activeBaseUrl != null) {
      try {
        return await build(_activeBaseUrl!);
      } catch (_) {
        _activeBaseUrl = null;
      }
    }

    Exception? last;
    for (final url in urls) {
      try {
        final res  = await build(url);
        _activeBaseUrl = url;
        return res;
      } catch (e) {
        last = e is Exception ? e : Exception(e.toString());
      }
    }
    throw last ?? Exception('[$_mode] Semua URL tidak dapat dicapai: $urls');
  }

  // Versi multipart untuk file upload
  static Future<http.StreamedResponse> _tryUrlsMultipart(
    http.MultipartRequest Function(String baseUrl) build,
  ) async {
    final urls        = TestingUrlExternal[_mode]!;
    final authHeaders = await _multipartHeaders();

    if (_activeBaseUrl != null) {
      try {
        final req = build(_activeBaseUrl!);
        req.headers.addAll(authHeaders);
        return await req.send();
      } catch (_) {
        _activeBaseUrl = null;
      }
    }

    Exception? last;
    for (final url in urls) {
      try {
        final req = build(url);
        req.headers.addAll(authHeaders);
        final res  = await req.send();
        _activeBaseUrl = url;
        return res;
      } catch (e) {
        last = e is Exception ? e : Exception(e.toString());
      }
    }
    throw last ?? Exception('[$_mode] Semua URL tidak dapat dicapai: $urls');
  }

  // ── Session management ───────────────────────────────────────────────────
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
    await prefs.setString(_keyUserId,       userId.toString());
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
    _activeBaseUrl = null; // Reset cache URL saat logout
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

      // Refresh token juga ikut fallback sesuai mode
      final response = await _tryUrls(
        (baseUrl) => http.post(
          Uri.parse('$baseUrl/refresh'),
          headers: {'Content-Type': 'application/json'},
          body:    jsonEncode({'refresh_token': refreshToken}),
        ).timeout(const Duration(seconds: 10)),
      );

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

  // ── Base headers ─────────────────────────────────────────────────────────
  static Future<Map<String, String>> _headers([Map<String, String>? extra]) async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  // Headers multipart (tanpa Content-Type, biar http set boundary otomatis)
  static Future<Map<String, String>> _multipartHeaders([Map<String, String>? extra]) async {
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
    final h = await _headers(headers);

    var response = await _tryUrls((baseUrl) {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
      return http.get(uri, headers: h);
    });

    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        final newH = await _headers(headers);
        response = await _tryUrls((baseUrl) {
          final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
          return http.get(uri, headers: newH);
        });
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
    final h   = await _headers(headers);
    final enc = body != null ? jsonEncode(body) : null;

    var response = await _tryUrls((baseUrl) {
      return http.post(Uri.parse('$baseUrl$path'), headers: h, body: enc);
    });

    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        final newH = await _headers(headers);
        response = await _tryUrls((baseUrl) {
          return http.post(Uri.parse('$baseUrl$path'), headers: newH, body: enc);
        });
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
    final h   = await _headers(headers);
    final enc = body != null ? jsonEncode(body) : null;

    var response = await _tryUrls((baseUrl) {
      return http.patch(Uri.parse('$baseUrl$path'), headers: h, body: enc);
    });

    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        final newH = await _headers(headers);
        response = await _tryUrls((baseUrl) {
          return http.patch(Uri.parse('$baseUrl$path'), headers: newH, body: enc);
        });
      }
    }
    return response;
  }

  // ── DELETE ───────────────────────────────────────────────────────────────
  static Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    final h = await _headers(headers);

    var response = await _tryUrls((baseUrl) {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
      return http.delete(uri, headers: h);
    });

    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        final newH = await _headers(headers);
        response = await _tryUrls((baseUrl) {
          final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
          return http.delete(uri, headers: newH);
        });
      }
    }
    return response;
  }

  // ── MULTIPART (file upload) — backward compat ────────────────────────────
  // Cara pakai lama tetap jalan:
  //   final req = http.MultipartRequest('POST', Uri.parse('${TestingUrlExternal[_mode]!.first}/path'));
  //   req.fields['key'] = 'value';
  //   req.files.add(await http.MultipartFile.fromPath('field', file.path));
  //   final response = await AuthStorage.sendMultipart(req);
  static Future<http.StreamedResponse> sendMultipart(
    http.MultipartRequest request, {
    Map<String, String>? extraHeaders,
  }) async {
    final authHeaders = await _multipartHeaders(extraHeaders);
    request.headers.addAll(authHeaders);

    var streamedResponse = await request.send();

    if (streamedResponse.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        // MultipartRequest tidak bisa di-send ulang setelah dikirim.
        // Return 401 ke caller agar hook memanggil ulang fungsi upload-nya.
      }
    }
    return streamedResponse;
  }

  // ── MULTIPART dengan builder — RECOMMENDED untuk hook baru ──────────────
  // Pakai ini agar upload bisa auto-fallback ke URL lain kalau koneksi putus.
  //
  // Cara pakai:
  //   final streamed = await AuthStorage.sendMultipartWithFallback((baseUrl) {
  //     final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload-xxx'));
  //     req.fields['key'] = 'value';
  //     req.files.add(await http.MultipartFile.fromPath('file', path));
  //     return req;
  //   });
  //   final response = await http.Response.fromStream(streamed);
  static Future<http.StreamedResponse> sendMultipartWithFallback(
    http.MultipartRequest Function(String baseUrl) requestBuilder,
  ) async {
    return _tryUrlsMultipart(requestBuilder);
  }
}