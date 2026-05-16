import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/auth_storage.dart';

class Trade_Ideas_Hook {
  // Base URL diatur terpusat di auth_storage.dart (kBaseUrl / TestingUrlExternal) //
  // Gak perlu define ulang di sini //

  // ===============================
  // GET ALL TRADE IDEAS
  // ===============================
  // token parameter dihapus — AuthStorage.get() inject token otomatis dari session
  static Future<Map<String, dynamic>> GetAllTradeIdeas() async {
    try {
      final response = await AuthStorage.get(
        '/trade-ideas-exclusive',
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        // ✅ EXTRACT DATA DARI WRAPPER
        return {
          "success": true,
          "data": jsonData["data"] ?? [], // Ambil array dari key "data"
        };
      }
      return {
        "success": false,
        "message": "Error ${response.statusCode}: ${response.body}",
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // =================================
  // GET TRADE IDEAS BY TITLE
  // =================================
  // token parameter dihapus — AuthStorage.get() inject token otomatis dari session
  static Future<Map<String, dynamic>> GetTradeIdeasByTitle({
    required String title,
  }) async {
    try {
      // Pakai queryParams biar URL-safe, AuthStorage.get() handle encoding-nya
      final response = await AuthStorage.get(
        '/trade-ideas-exclusive/title',
        headers: {'Accept': 'application/json'},
        queryParams: {'title': title},
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        // ✅ EXTRACT DATA DARI WRAPPER
        return {
          "success": true,
          "data": jsonData["data"], // Single object
        };
      }
      return {
        "success": false,
        "message": "Error ${response.statusCode}: ${response.body}",
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // =====================================
  // UPLOAD TRADE IDEAS (ADMIN ONLY)
  // =====================================
  // token parameter dihapus — AuthStorage.post() inject token otomatis dari session
  // CATATAN: Endpoint ini pakai application/x-www-form-urlencoded bukan JSON.
  // AuthStorage.post() default pakai Content-Type: application/json, jadi kita
  // override header & kirim body manual lewat http.post() langsung — tapi tetap
  // ambil token dari AuthStorage.getToken() biar konsisten.
  static Future<Map<String, dynamic>> UploadTradeIdea({
    required String tradeIdea,
    required String tipeTrade,
    required String aktivasi,
    required String date,
    required double entry,
    required double stoploss,
    required double target,
    required bool status,
  }) async {
    try {
      final token = await AuthStorage.getToken();

      final response = await http.post(
        Uri.parse('${AuthStorage.activeBaseUrl}/trade-ideas-exclusive'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          "Trade_idea": tradeIdea,
          "Tipe_trade": tipeTrade,
          "Aktivasi": aktivasi,
          "Date": date,
          "Entry": entry.toString(),
          "Stoploss": stoploss.toString(),
          "Target": target.toString(),
          "Status": status.toString(),
        },
      );

      // Auto-retry sekali kalau 401 (token expired) — sama polanya kayak AuthStorage
      if (response.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (refreshed) {
          final newToken = await AuthStorage.getToken();
          final retryResponse = await http.post(
            Uri.parse('${AuthStorage.activeBaseUrl}/trade-ideas-exclusive'),
            headers: {
              if (newToken != null) 'Authorization': 'Bearer $newToken',
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: {
              "Trade_idea": tradeIdea,
              "Tipe_trade": tipeTrade,
              "Aktivasi": aktivasi,
              "Date": date,
              "Entry": entry.toString(),
              "Stoploss": stoploss.toString(),
              "Target": target.toString(),
              "Status": status.toString(),
            },
          );
          if (retryResponse.statusCode == 200) {
            return {
              "success": true,
              "data": jsonDecode(retryResponse.body),
            };
          }
          return {
            "success": false,
            "message": "Error ${retryResponse.statusCode}: ${retryResponse.body}",
          };
        }
      }

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      }
      return {
        "success": false,
        "message": "Error ${response.statusCode}: ${response.body}",
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // ===============================
  // DELETE TRADE IDEAS
  // ===============================
  // token parameter dihapus — AuthStorage.delete() inject token otomatis dari session
  // tradeId di-embed langsung ke path (bukan query param) sesuai endpoint aslinya
  static Future<Map<String, dynamic>> DeleteTradeIdea({
    required String tradeId,
  }) async {
    try {
      final response = await AuthStorage.delete(
        '/trade-ideas-exclusive/$tradeId',
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      }
      return {
        "success": false,
        "message": "Error ${response.statusCode}: ${response.body}",
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // ===========================================
  // GET TRADE IDEAS WITH UPLOADER INFO
  // ===========================================
  // token parameter dihapus — AuthStorage.get() inject token otomatis dari session
  static Future<Map<String, dynamic>> GetTradeIdeasWithUploader() async {
    try {
      final response = await AuthStorage.get(
        '/trade-ideas-exclusive/full',
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        // ✅ EXTRACT DATA DARI WRAPPER
        return {
          "success": true,
          "data": jsonData["data"] ?? [], // Ambil array dari key "data"
        };
      }
      return {
        "success": false,
        "message": "Error ${response.statusCode}: ${response.body}",
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }
}