import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SendOtpHook {
  static const String baseUrl = "http://127.0.0.1:8080";
  
  /// SEND OTP KE EMAIL
  static Future<Map<String, dynamic>> sendOtp({
    required String email,
  }) async {
    try {
      print('[DEBUG] Sending OTP to: $email');
      
      final uri = Uri.parse("$baseUrl/send-otp-to-email");
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "email": email,
        }),
      );

      print('[DEBUG] Response status: ${response.statusCode}');
      print('[DEBUG] Response body: ${response.body}');

      final data = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : {};

      if (response.statusCode == 200) {
        return {
          "success": data["success"] ?? true, // ✅ Backend lu return "success": True
          "message": data["message"] ?? "OTP berhasil dikirim",
          "expiry_minutes": data["expiry_minutes"] ?? 8, // ✅ Backend lu default 8 menit
        };
      } else {
        return {
          "success": false,
          "message": data["detail"] ?? "Gagal kirim OTP",
        };
      }
    } catch (e) {
      print('[ERROR] Send OTP error: $e');
      return {
        "success": false,
        "message": "Network error: $e",
      };
    }
  }

  /// VERIFY OTP - Return JWT token
  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      print('[DEBUG] Verifying OTP for: $email');
      print('[DEBUG] OTP: $otp');
      
      final uri = Uri.parse("$baseUrl/verify-otp");
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "email": email,
          "otp": otp,
        }),
      );

      print('[DEBUG] Verify response status: ${response.statusCode}');
      print('[DEBUG] Verify response body: ${response.body}');

      final data = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : {};

      if (response.statusCode == 200) {
        // ✅ Simpan JWT token ke SharedPreferences
        if (data["token"] != null) {
          await _saveAuthData(
            token: data["token"],
            userId: data["user_id"],
            email: data["email"],
            role: data["role"], // ✅ TAMBAHKAN role (dari backend)
          );
        }

        return {
          "success": data["success"] ?? true,
          "message": data["message"] ?? "Verifikasi berhasil",
          "token": data["token"], // ✅ JWT token dari backend
          "user_id": data["user_id"],
          "email": data["email"],
          "role": data["role"], // ✅ TAMBAHKAN role
          "token_type": data["token_type"] ?? "Bearer",
          "expires_in": data["expires_in"],
        };
      } else {
        return {
          "success": false,
          "message": data["detail"] ?? "OTP salah atau expired",
        };
      }
    } catch (e) {
      print('[ERROR] Verify OTP error: $e');
      return {
        "success": false,
        "message": "Network error: $e",
      };
    }
  }

  /// Simpan auth data ke SharedPreferences
  static Future<void> _saveAuthData({
    required String token,
    required int userId,
    required String email,
    String? role, // ✅ TAMBAHKAN role (optional)
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setInt('user_id', userId);
    await prefs.setString('email', email);
    if (role != null) {
      await prefs.setString('role', role); // ✅ Simpan role juga
    }
    await prefs.setString('login_time', DateTime.now().toIso8601String());
    
    print('[DEBUG] Auth data saved to SharedPreferences');
  }

  /// Get JWT token dari SharedPreferences
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  /// Get user data dari SharedPreferences
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    
    if (token == null) return null;

    return {
      'token': token,
      'user_id': prefs.getInt('user_id'),
      'email': prefs.getString('email'),
      'role': prefs.getString('role'), // ✅ TAMBAHKAN role
      'login_time': prefs.getString('login_time'),
    };
  }

  /// Logout - hapus semua data auth
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
    await prefs.remove('email');
    await prefs.remove('role'); // ✅ Hapus role juga
    await prefs.remove('login_time');
    
    print('[DEBUG] User logged out, auth data cleared');
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  /// Contoh request dengan JWT token
  static Future<Map<String, dynamic>> authenticatedRequest({
    required String endpoint,
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    try {
      final token = await getToken();
      
      if (token == null) {
        return {
          "success": false,
          "message": "Not authenticated. Please login first.",
          "logout": true,
        };
      }

      print('[DEBUG] Making authenticated $method request to: $endpoint');
      print('[DEBUG] Token: ${token.substring(0, 20)}...'); // Print 20 char pertama

      final uri = Uri.parse("$baseUrl$endpoint");
      final headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token", // ✅ Format standard JWT
      };

      http.Response response;
      
      if (method == 'GET') {
        response = await http.get(uri, headers: headers);
      } else if (method == 'POST') {
        response = await http.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      } else if (method == 'PUT') {
        response = await http.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      } else if (method == 'DELETE') {
        response = await http.delete(uri, headers: headers);
      } else {
        throw Exception('Unsupported HTTP method: $method');
      }

      print('[DEBUG] Response status: ${response.statusCode}');

      final data = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : {};

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": data,
        };
      } else if (response.statusCode == 401) {
        // Token expired atau invalid - logout otomatis
        print('[WARNING] 401 Unauthorized - Token expired or invalid');
        await logout();
        return {
          "success": false,
          "message": "Session expired. Please login again.",
          "logout": true,
        };
      } else if (response.statusCode == 403) {
        // Forbidden - biasanya role tidak sesuai (bukan admin)
        return {
          "success": false,
          "message": data["detail"] ?? "Access forbidden. Insufficient permissions.",
        };
      } else {
        return {
          "success": false,
          "message": data["detail"] ?? "Request failed",
        };
      }
    } catch (e) {
      print('[ERROR] Authenticated request error: $e');
      return {
        "success": false,
        "message": "Network error: $e",
      };
    }
  }
}