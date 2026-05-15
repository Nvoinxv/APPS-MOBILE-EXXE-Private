import 'dart:convert';
import '../utils/auth_storage.dart';

class Reset_Password_Hook {
  // Pakai TestingUrlExternal dari AuthStorage (ngrok / external URL) //
  // Kalau mau balik ke localhost, tinggal ganti ke kBaseUrl //
  // Belum production mode //
  // Soal nya rada mahal pengembangan nya //

  static Future<Map<String, dynamic>> ResetPassHook({
    required String email,
    required String password,
  }) async {
    try {
      // Pakai AuthStorage.post() biar konsisten sama base URL & headers //
      // Path /reset-password gak butuh auth token, tapi AuthStorage.post() //
      // tetap handle Content-Type otomatis jadi aman //
      final response = await AuthStorage.post(
        '/reset-password',
        body: {
          "email": email,
          "password": password,
        },
      );

      // Kalau backend balikin status sukses //
      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      }

      // Kalau gagal (email gak ada / error lain) //
      else {
        return {
          "success": false,
          "message": jsonDecode(response.body),
        };
      }
    }

    // Kalau error koneksi / parsing //
    catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }
}