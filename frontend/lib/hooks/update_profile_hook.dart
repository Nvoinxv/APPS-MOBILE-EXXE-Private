// ============================================================
// FILE: hooks/update_profile_hook.dart
// ============================================================

import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const String _baseUrl = 'http://127.0.0.1:8080'; // ← Sesuaikan sama backend lu

// ─── 0. GET /profile — ambil data terbaru dari server ────────────────────────
// Ini source of truth yang sebenarnya.
// Dipanggil setiap kali ProfilePage dibuka supaya data selalu fresh dari DB.
Future<Map<String, dynamic>?> getProfileHook({
  required String token,
}) async {
  try {
    final response = await http.get(
      Uri.parse('$_baseUrl/profile'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;

      // ✅ Sinkronkan ke SharedPreferences sekalian supaya cache selalu update
      await _syncToLocal(data);

      return data;
    } else {
      // Kalau API gagal (misal offline), jangan throw — fallback ke lokal
      print('[WARNING] GET /profile gagal: ${response.statusCode}');
      return null;
    }
  } on SocketException {
    print('[WARNING] GET /profile: tidak ada koneksi, pakai data lokal');
    return null;
  } catch (e) {
    print('[WARNING] GET /profile error: $e');
    return null;
  }
}

// ─── 1. PUT /update-profile — simpan teks profile ke DB ──────────────────────
Future<Map<String, dynamic>> updateProfileHook({
  required String token,
  required String displayName,
  required String description,
  required String birthYear,
}) async {
  try {
    final response = await http.put(
      Uri.parse('$_baseUrl/update-profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'display_name': displayName,
        'description':  description.trim().isEmpty ? null : description.trim(),
        'birth_year':   birthYear.trim().isEmpty   ? null : birthYear.trim(),
      }),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      // ✅ Update SharedPreferences setelah DB update sukses
      await _saveProfileLocal(
        displayName: displayName,
        description: description,
        birthYear:   birthYear,
      );
      return data;
    } else {
      throw Exception(data['detail'] ?? data['message'] ?? 'Gagal update profile');
    }
  } on SocketException {
    throw Exception('Tidak ada koneksi internet');
  } catch (e) {
    if (e is Exception) rethrow;
    throw Exception('Gagal terhubung ke server: $e');
  }
}

// ─── 2. POST /upload-profile-image — upload foto ke server ───────────────────
Future<String> uploadProfileImageHook({
  required String token,
  required File imageFile,
}) async {
  try {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/upload-profile-image'),
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
    } else {
      throw Exception(data['detail'] ?? data['message'] ?? 'Gagal upload foto');
    }
  } on SocketException {
    throw Exception('Tidak ada koneksi internet');
  } catch (e) {
    if (e is Exception) rethrow;
    throw Exception('Gagal upload foto: $e');
  }
}

// ─── Sinkronkan response GET /profile ke SharedPreferences ───────────────────
Future<void> _syncToLocal(Map<String, dynamic> serverData) async {
  final prefs     = await SharedPreferences.getInstance();
  final rawString = prefs.getString('user_data');

  Map<String, dynamic> existing = {};
  if (rawString != null) {
    try {
      existing = json.decode(rawString) as Map<String, dynamic>;
    } catch (_) {}
  }

  // Merge: data server selalu menang (override data lokal yang mungkin stale)
  existing['display_name']      = serverData['display_name'];
  existing['description']       = serverData['description'];
  existing['birth_year']        = serverData['birth_year'];
  existing['profile_image_url'] = serverData['profile_image_url'];

  await prefs.setString('user_data', json.encode(existing));
}

// ─── Simpan teks profile ke SharedPreferences (setelah PUT sukses) ───────────
Future<void> _saveProfileLocal({
  required String displayName,
  required String description,
  required String birthYear,
}) async {
  final prefs     = await SharedPreferences.getInstance();
  final rawString = prefs.getString('user_data');

  Map<String, dynamic> existing = {};
  if (rawString != null) {
    try {
      existing = json.decode(rawString) as Map<String, dynamic>;
    } catch (_) {}
  }

  existing['display_name'] = displayName;
  existing['description']  = description;
  existing['birth_year']   = birthYear;

  await prefs.setString('user_data', json.encode(existing));
}

// ─── Simpan URL foto ke SharedPreferences (setelah upload sukses) ────────────
Future<void> _saveImageUrlLocal(String imageUrl) async {
  final prefs     = await SharedPreferences.getInstance();
  final rawString = prefs.getString('user_data');

  Map<String, dynamic> existing = {};
  if (rawString != null) {
    try {
      existing = json.decode(rawString) as Map<String, dynamic>;
    } catch (_) {}
  }

  existing['profile_image_url'] = imageUrl;

  await prefs.setString('user_data', json.encode(existing));
}