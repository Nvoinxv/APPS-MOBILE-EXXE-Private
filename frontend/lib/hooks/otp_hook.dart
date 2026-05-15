import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/auth_storage.dart';

// Base URL — pakai TestingUrlExternal dari auth_storage.dart
const String _base = TestingUrlExternal;

class SendOtpHook {

  // ─────────────────────────────────────────
  // SEND OTP KE EMAIL
  // ─────────────────────────────────────────
  static Future<Map<String, dynamic>> sendOtp({
    required String email,
  }) async {
    try {
      print('[DEBUG] Sending OTP to: $email');

      final uri      = Uri.parse("$_base/send-otp-to-email");
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body:    jsonEncode({"email": email}),
      );

      print('[DEBUG] Response status: ${response.statusCode}');
      print('[DEBUG] Response body: ${response.body}');

      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode == 200) {
        return {
          "success":        data["success"]        ?? true,
          "message":        data["message"]        ?? "OTP berhasil dikirim",
          "expiry_minutes": data["expiry_minutes"] ?? 8,
        };
      }

      return {
        "success": false,
        "message": data["detail"] ?? "Gagal kirim OTP",
      };
    } catch (e) {
      print('[ERROR] Send OTP error: $e');
      return {"success": false, "message": "Network error: $e"};
    }
  }

  // ─────────────────────────────────────────
  // VERIFY OTP — Return JWT token
  // ─────────────────────────────────────────
  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      print('[DEBUG] Verifying OTP for: $email');
      print('[DEBUG] OTP: $otp');

      final uri      = Uri.parse("$_base/verify-otp");
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body:    jsonEncode({"email": email, "otp": otp}),
      );

      print('[DEBUG] Verify response status: ${response.statusCode}');
      print('[DEBUG] Verify response body: ${response.body}');

      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode == 200) {
        // Simpan session via AuthStorage kalau token tersedia
        if (data["token"] != null) {
          await AuthStorage.saveSession(
            token:        data["token"].toString(),
            refreshToken: data["refresh_token"]?.toString() ?? '',
            userId:       data["user_id"]?.toString() ?? '',
            email:        data["email"]?.toString() ?? email,
            role:         data["role"]?.toString() ?? '',
            name:         data["name"]?.toString() ?? '',
          );
          print('[DEBUG] Auth data saved via AuthStorage');
        }

        return {
          "success":    data["success"]    ?? true,
          "message":    data["message"]    ?? "Verifikasi berhasil",
          "token":      data["token"],
          "user_id":    data["user_id"],
          "email":      data["email"],
          "role":       data["role"],
          "token_type": data["token_type"] ?? "Bearer",
          "expires_in": data["expires_in"],
        };
      }

      return {
        "success": false,
        "message": data["detail"] ?? "OTP salah atau expired",
      };
    } catch (e) {
      print('[ERROR] Verify OTP error: $e');
      return {"success": false, "message": "Network error: $e"};
    }
  }

  // ─────────────────────────────────────────
  // GET JWT TOKEN
  // ─────────────────────────────────────────
  static Future<String?> getToken() async {
    return AuthStorage.getToken();
  }

  // ─────────────────────────────────────────
  // GET USER DATA
  // ─────────────────────────────────────────
  static Future<Map<String, dynamic>?> getUserData() async {
    final userData = await AuthStorage.getUserData();
    if (userData['token'] == null) return null;
    return {
      'token':   userData['token'],
      'user_id': userData['user_id'],
      'email':   userData['email'],
      'role':    userData['role'],
      'name':    userData['name'],
    };
  }

  // ─────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────
  static Future<void> logout() async {
    await AuthStorage.clearSession();
    print('[DEBUG] User logged out, auth data cleared');
  }

  // ─────────────────────────────────────────
  // CHECK IS LOGGED IN
  // ─────────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    return AuthStorage.isLoggedIn();
  }

  // ─────────────────────────────────────────
  // AUTHENTICATED REQUEST (generic helper)
  // ─────────────────────────────────────────
  static Future<Map<String, dynamic>> authenticatedRequest({
    required String endpoint,
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    try {
      final token = await AuthStorage.getToken();

      if (token == null || token.isEmpty) {
        return {
          "success": false,
          "message": "Not authenticated. Please login first.",
          "logout":  true,
        };
      }

      print('[DEBUG] Making authenticated $method request to: $endpoint');
      print('[DEBUG] Token: ${token.substring(0, token.length.clamp(0, 20))}...');

      final uri     = Uri.parse("$_base$endpoint");
      final headers = {
        "Content-Type":  "application/json",
        "Authorization": "Bearer $token",
      };

      http.Response response;

      if (method == 'GET') {
        response = await http.get(uri, headers: headers);
      } else if (method == 'POST') {
        response = await http.post(
          uri, headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      } else if (method == 'PUT') {
        response = await http.put(
          uri, headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      } else if (method == 'DELETE') {
        response = await http.delete(uri, headers: headers);
      } else {
        throw Exception('Unsupported HTTP method: $method');
      }

      print('[DEBUG] Response status: ${response.statusCode}');

      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode == 200) {
        return {"success": true, "data": data};
      }

      // Auto-refresh 401
      if (response.statusCode == 401) {
        print('[WARNING] 401 Unauthorized — trying token refresh...');
        final refreshed = await AuthStorage.refreshAccessToken();

        if (!refreshed) {
          print('[WARNING] Refresh failed — forcing logout');
          await logout();
          return {
            "success": false,
            "message": "Session expired. Please login again.",
            "logout":  true,
          };
        }

        // Retry sekali dengan token baru
        return authenticatedRequest(
          endpoint: endpoint,
          method:   method,
          body:     body,
        );
      }

      if (response.statusCode == 403) {
        return {
          "success": false,
          "message": data["detail"] ?? "Access forbidden. Insufficient permissions.",
        };
      }

      return {
        "success": false,
        "message": data["detail"] ?? "Request failed",
      };
    } catch (e) {
      print('[ERROR] Authenticated request error: $e');
      return {"success": false, "message": "Network error: $e"};
    }
  }
}