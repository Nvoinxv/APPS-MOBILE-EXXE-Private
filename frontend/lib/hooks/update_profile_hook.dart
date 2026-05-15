// ============================================================
// FILE: hooks/update_profile_hook.dart
//
// FIX LOG:
//   1. Semua http call → pakai AuthStorage.get/post/patch
//      → Auto inject token terbaru dari storage
//      → Auto refresh kalau 401 (token expired)
//      → Ga perlu passing token manual lagi
//
//   2. Parameter `token` dihapus dari semua fungsi
//      → Token diambil otomatis dari SharedPreferences via AuthStorage
//      → Profile page ga perlu kirim widget.token ke hook
//
//   3. uploadProfileImageHook tetap pakai http.MultipartRequest manual
//      → AuthStorage belum punya helper untuk multipart
//      → Tapi token diambil dari AuthStorage.getToken() — selalu fresh
// ============================================================

import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth_storage.dart';

// ─── 0. GET /profile ─────────────────────────────────────────────────────────
// FIX: pakai AuthStorage.get() → auto inject token + auto refresh kalau 401
// Token parameter dihapus — diambil otomatis dari storage
Future<Map<String, dynamic>?> getProfileHook() async {
  try {
    final response = await AuthStorage.get('/profile');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      await _syncToLocal(data);
      return data;
    }

    print('[WARNING] GET /profile gagal: ${response.statusCode}');
    return null;

  } on SocketException {
    print('[WARNING] GET /profile: tidak ada koneksi, pakai data lokal');
    return null;
  } catch (e) {
    print('[WARNING] GET /profile error: $e');
    return null;
  }
}

// ─── 1. PUT /update-profile ───────────────────────────────────────────────────
// FIX: pakai AuthStorage.patch() → auto refresh kalau token expired
Future<Map<String, dynamic>> updateProfileHook({
  required String displayName,
  required String description,
  required String birthYear,
}) async {
  try {
    final response = await AuthStorage.patch(
      '/update-profile',
      body: {
        'display_name': displayName,
        'description':  description.trim().isEmpty ? null : description.trim(),
        'birth_year':   birthYear.trim().isEmpty   ? null : birthYear.trim(),
      },
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      await _saveProfileLocal(
        displayName: displayName,
        description: description,
        birthYear:   birthYear,
      );
      return data as Map<String, dynamic>;
    }

    throw Exception(data['detail'] ?? 'Gagal update profile');

  } on SocketException {
    throw Exception('Tidak ada koneksi internet');
  } catch (e) {
    if (e is Exception) rethrow;
    throw Exception('Gagal terhubung ke server: $e');
  }
}

// ─── 2. POST /upload-profile-image ───────────────────────────────────────────
// MultipartRequest tidak bisa pakai AuthStorage helper langsung,
// tapi token tetap diambil fresh dari AuthStorage.getToken()
Future<String> uploadProfileImageHook({
  required File imageFile,
}) async {
  try {
    // ── Ambil token fresh dari storage ──────────────────────────────────
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan, silakan login ulang');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$TestingUrlExternal/upload-profile-image'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data     = json.decode(response.body);

    if (response.statusCode == 200) {
      final imageUrl = data['image_url'] as String;
      await _saveImageUrlLocal(imageUrl);
      return imageUrl;
    }

    throw Exception(data['detail'] ?? 'Gagal upload foto');

  } on SocketException {
    throw Exception('Tidak ada koneksi internet');
  } catch (e) {
    if (e is Exception) rethrow;
    throw Exception('Gagal upload foto: $e');
  }
}

// ─── Sync response GET /profile ke SharedPreferences ─────────────────────────
Future<void> _syncToLocal(Map<String, dynamic> serverData) async {
  final prefs      = await SharedPreferences.getInstance();
  final rawString  = prefs.getString('user_data');
  Map<String, dynamic> existing = {};
  if (rawString != null) {
    try { existing = json.decode(rawString) as Map<String, dynamic>; } catch (_) {}
  }
  existing['display_name']      = serverData['display_name'];
  existing['description']       = serverData['description'];
  existing['birth_year']        = serverData['birth_year'];
  existing['profile_image_url'] = serverData['profile_image_url'];
  await prefs.setString('user_data', json.encode(existing));
}

Future<void> _saveProfileLocal({
  required String displayName,
  required String description,
  required String birthYear,
}) async {
  final prefs     = await SharedPreferences.getInstance();
  final rawString = prefs.getString('user_data');
  Map<String, dynamic> existing = {};
  if (rawString != null) {
    try { existing = json.decode(rawString) as Map<String, dynamic>; } catch (_) {}
  }
  existing['display_name'] = displayName;
  existing['description']  = description;
  existing['birth_year']   = birthYear;
  await prefs.setString('user_data', json.encode(existing));
}

Future<void> _saveImageUrlLocal(String imageUrl) async {
  final prefs     = await SharedPreferences.getInstance();
  final rawString = prefs.getString('user_data');
  Map<String, dynamic> existing = {};
  if (rawString != null) {
    try { existing = json.decode(rawString) as Map<String, dynamic>; } catch (_) {}
  }
  existing['profile_image_url'] = imageUrl;
  await prefs.setString('user_data', json.encode(existing));
}