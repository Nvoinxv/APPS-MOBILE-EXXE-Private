import 'dart:convert';
import '../utils/auth_storage.dart';

class Reset_Password_Hook {
  // ── Step 1: Request OTP ───────────────────────────────────────────────────
  // Kirim OTP ke email user
  static Future<Map<String, dynamic>> requestOtp({
    required String email,
  }) async {
    try {
      final response = await AuthStorage.post(
        '/reset-password/request-otp',
        body: {
          "email": email,
        },
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "message": jsonDecode(response.body),
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // ── Step 2: Verify OTP ────────────────────────────────────────────────────
  // Verifikasi kode OTP yang dikirim ke email
  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      final response = await AuthStorage.post(
        '/reset-password/verify-otp',
        body: {
          "email": email,
          "otp_code": otpCode,
        },
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "message": jsonDecode(response.body),
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // ── Step 3: Confirm Reset Password ────────────────────────────────────────
  // Ganti password baru setelah OTP terverifikasi
  static Future<Map<String, dynamic>> confirmReset({
    required String email,
    required String otpCode,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await AuthStorage.post(
        '/reset-password/confirm',
        body: {
          "email": email,
          "otp_code": otpCode,
          "new_password": newPassword,
          "confirm_password": confirmPassword,
        },
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "message": jsonDecode(response.body),
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }
}