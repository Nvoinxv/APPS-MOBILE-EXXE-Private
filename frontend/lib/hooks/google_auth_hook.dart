// ============================================================
// FILE: hooks/google_auth_hook.dart
// ============================================================
// Dependency — tambahkan ke pubspec.yaml:
//
//   google_sign_in: ^6.2.1
//
// Lalu jalankan: flutter pub get
// ============================================================

import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart'; // ganti sesuai path BASE_URL lo

// Ganti dengan iOS Client ID lo dari Google Cloud Console
// Android tidak perlu clientId di sini — ambil otomatis dari google-services.json
const String _iosClientId =
    'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: _iosClientId, // iOS only — Android pakai google-services.json
  scopes: ['email', 'profile'],
);

/// Jalankan Google Sign-In → kirim idToken ke backend → return response JWT
Future<Map<String, dynamic>> googleAuthHook() async {
  try {
    // 1. Trigger Google Sign-In dialog
    final GoogleSignInAccount? account = await _googleSignIn.signIn();

    if (account == null) {
      // User cancel sign-in
      throw Exception('Login dibatalkan');
    }

    // 2. Ambil idToken dari Google
    final GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;

    if (idToken == null) {
      throw Exception('Gagal mendapatkan token dari Google. Coba lagi.');
    }

    // 3. Kirim idToken ke backend lo
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data; // berisi: access_token, user {id, name, email, role, picture}
    } else {
      throw Exception(data['detail'] ?? 'Google Sign-In gagal');
    }
  } on Exception {
    rethrow;
  } catch (e) {
    throw Exception('Terjadi error: $e');
  }
}

/// Sign out dari Google (opsional — panggil saat logout)
Future<void> googleSignOutHook() async {
  await _googleSignIn.signOut();
}