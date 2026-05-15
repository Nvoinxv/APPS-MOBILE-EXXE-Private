// ============================================================
// FILE: hooks/register_hook.dart
// ============================================================
// Alur register:
//   STEP 1 (wajib)    → POST /register             → name, email, password
//   STEP 2 (opsional) → PUT  /update-profile        → description, birth_year
//   STEP 3 (opsional) → POST /upload-profile-image  → foto profile
//
// Description, profile image, dan birth_year TIDAK wajib diisi.
// Kalau user skip, langsung return hasil register saja.
// ============================================================

import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/auth_storage.dart';

// Base URL — pakai TestingUrlExternal dari auth_storage.dart
const String _baseUrl = TestingUrlExternal;

// ─── Main Register Hook ───────────────────────────────────────────────────────
// Parameter wajib   : name, email, password
// Parameter opsional: description, birthYear, profileImage
//
// Kenapa dipisah jadi 3 step?
// → Backend /register tidak terima multipart (file), dia terima JSON biasa.
//   Jadi foto dan data tambahan harus dikirim terpisah setelah register sukses
//   dan kita sudah punya token JWT dari response login pasca register.
Future<Map<String, dynamic>> registerHook({
  // ── WAJIB DIISI ──────────────────────────────────────────────────────────
  required String name,
  required String email,
  required String password,

  // ── OPSIONAL — boleh null / kosong ───────────────────────────────────────
  String? description,
  String? birthYear,
  File? profileImage,
}) async {
  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1: Register akun (wajib)
  // ══════════════════════════════════════════════════════════════════════════
  final registerResult = await _step1Register(
    name:     name,
    email:    email,
    password: password,
  );

  // Setelah register, kita perlu login dulu untuk dapat JWT token
  // yang dibutuhkan di step 2 & 3.
  // Kalau backend lu langsung return token di /register, pakai itu.
  // Kalau tidak, kita login dulu.
  final token = registerResult['access_token'] as String?;

  // Simpan session ke AuthStorage kalau token tersedia
  if (token != null && token.isNotEmpty) {
    await AuthStorage.saveSession(
      token:        token,
      refreshToken: registerResult['refresh_token']?.toString() ?? '',
      userId:       registerResult['user_id']?.toString() ?? '',
      email:        email,
      role:         registerResult['role']?.toString() ?? '',
      name:         name,
    );
    print('[DEBUG] Session saved via AuthStorage after register');
  }

  // Kalau tidak ada data opsional yang diisi, langsung selesai
  final bool hasOptionalData = _hasAnyOptionalData(
    description:  description,
    birthYear:    birthYear,
    profileImage: profileImage,
  );

  if (!hasOptionalData || token == null) {
    // Tidak ada data opsional atau token tidak tersedia — return hasil register
    return registerResult;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2: Update profile teks opsional (kalau ada)
  // ══════════════════════════════════════════════════════════════════════════
  final bool hasTextData =
      (description != null && description.trim().isNotEmpty) ||
      (birthYear   != null && birthYear.trim().isNotEmpty);

  if (hasTextData) {
    await _step2UpdateProfile(
      token:       token,
      displayName: name, // display_name diisi dari name yang sudah dipakai di register
      description: description ?? '',
      birthYear:   birthYear   ?? '',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3: Upload foto profile opsional (kalau ada)
  // ══════════════════════════════════════════════════════════════════════════
  if (profileImage != null) {
    await _step3UploadImage(
      token:     token,
      imageFile: profileImage,
    );
  }

  return registerResult;
}

// ─── Step 1: POST /register ───────────────────────────────────────────────────
Future<Map<String, dynamic>> _step1Register({
  required String name,
  required String email,
  required String password,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$_baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name':     name,
        'email':    email,
        'password': password,
        // ROLE TIDAK DIKIRIM — backend auto set ke GENERAL
        // Role hanya berubah kalau user upgrade ke EXCLUSIVE (berbayar)
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorData = json.decode(response.body);
      // Backend pakai key 'detail' (FastAPI default) atau 'message'
      throw Exception(
        errorData['detail'] ?? errorData['message'] ?? 'Gagal registrasi',
      );
    }
  } on SocketException {
    throw Exception('Tidak ada koneksi internet');
  } catch (e) {
    if (e is Exception) rethrow;
    throw Exception('Gagal terhubung ke server: ${e.toString()}');
  }
}

// ─── Step 2: PUT /update-profile (opsional) ───────────────────────────────────
// Dipanggil hanya kalau description atau birthYear diisi
Future<void> _step2UpdateProfile({
  required String token,
  required String displayName,
  required String description,
  required String birthYear,
}) async {
  try {
    // Coba dengan token yang ada dulu
    var response = await http.put(
      Uri.parse('$_baseUrl/update-profile'),
      headers: {
        'Content-Type':  'application/json',
        // JWT token wajib ada — backend pakai ini untuk tau siapa usernya
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'display_name': displayName,
        'description':  description.trim().isEmpty ? null : description.trim(),
        'birth_year':   birthYear.trim().isEmpty   ? null : birthYear.trim(),
      }),
    );

    // Auto-refresh 401
    if (response.statusCode == 401) {
      final refreshed = await AuthStorage.refreshAccessToken();
      if (refreshed) {
        final newToken = await AuthStorage.getToken();
        response = await http.put(
          Uri.parse('$_baseUrl/update-profile'),
          headers: {
            'Content-Type':  'application/json',
            'Authorization': 'Bearer ${newToken ?? ''}',
          },
          body: json.encode({
            'display_name': displayName,
            'description':  description.trim().isEmpty ? null : description.trim(),
            'birth_year':   birthYear.trim().isEmpty   ? null : birthYear.trim(),
          }),
        );
      }
    }

    if (response.statusCode != 200) {
      // Step 2 gagal tidak fatal untuk register — cukup log saja
      // User masih bisa update profile nanti dari halaman Profile
      final errorData = json.decode(response.body);
      print('[WARNING] Update profile opsional gagal: '
          '${errorData['detail'] ?? errorData['message']}');
    }
  } catch (e) {
    // Jangan throw — step ini opsional, gagal tidak batalkan register
    print('[WARNING] Step 2 update profile skip: $e');
  }
}

// ─── Step 3: POST /upload-profile-image (opsional) ───────────────────────────
// Dipanggil hanya kalau user memilih foto
Future<void> _step3UploadImage({
  required String token,
  required File imageFile,
}) async {
  try {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/upload-profile-image'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    // Field name "file" harus sama persis dengan parameter di FastAPI:
    // file: UploadFile = File(...)
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    // Auto-refresh 401 — rebuild MultipartRequest karena tidak bisa di-replay
    if (response.statusCode == 401) {
      final refreshed = await AuthStorage.refreshAccessToken();
      if (refreshed) {
        final newToken = await AuthStorage.getToken();

        final retryRequest = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/upload-profile-image'),
        );
        retryRequest.headers['Authorization'] = 'Bearer ${newToken ?? ''}';
        retryRequest.files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );

        final retryStreamed = await retryRequest.send();
        response = await http.Response.fromStream(retryStreamed);
      }
    }

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      print('[WARNING] Upload foto profile opsional gagal: '
          '${errorData['detail'] ?? errorData['message']}');
    }
  } catch (e) {
    // Jangan throw — step ini opsional, gagal tidak batalkan register
    print('[WARNING] Step 3 upload image skip: $e');
  }
}

// ─── Helper: cek apakah ada data opsional yang perlu dikirim ─────────────────
bool _hasAnyOptionalData({
  String? description,
  String? birthYear,
  File? profileImage,
}) {
  final hasDesc  = description  != null && description.trim().isNotEmpty;
  final hasBirth = birthYear    != null && birthYear.trim().isNotEmpty;
  final hasImage = profileImage != null;
  return hasDesc || hasBirth || hasImage;
}