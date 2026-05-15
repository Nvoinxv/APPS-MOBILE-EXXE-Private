import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../utils/auth_storage.dart';

// Base URL — pakai TestingUrlExternal dari auth_storage.dart
const String _base = TestingUrlExternal;

class Research_Coin_Hook {

  // ===============================
  // GET ALL RESEARCH COIN
  // ===============================
  static Future<Map<String, dynamic>> GetAllResearchCoin() async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse("$_base/get-research-coin-exclusive");

      var response = await http.get(uri, headers: {
        "Authorization": "Bearer ${token ?? ''}",
        "Accept": "application/json",
      });

      // Auto-refresh 401
      if (response.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (!refreshed) {
          return {"success": false, "message": "Session expired. Silakan login ulang."};
        }
        final newToken = await AuthStorage.getToken();
        response = await http.get(uri, headers: {
          "Authorization": "Bearer ${newToken ?? ''}",
          "Accept": "application/json",
        });
      }

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        // KONSISTEN: Selalu return data dari key "data"
        return {"success": true, "data": jsonResponse["data"]}; // Array
      }

      return {"success": false, "message": response.body};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // =================================
  // GET RESEARCH COIN BY TITLE
  // =================================
  static Future<Map<String, dynamic>> GetResearchCoinByTitle({
    required String title,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse(
        "$_base/get-title-research-coin-exclusive?title=$title",
      );

      var response = await http.get(uri, headers: {
        "Authorization": "Bearer ${token ?? ''}",
        "Accept": "application/json",
      });

      // Auto-refresh 401
      if (response.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (!refreshed) {
          return {"success": false, "message": "Session expired. Silakan login ulang."};
        }
        final newToken = await AuthStorage.getToken();
        response = await http.get(uri, headers: {
          "Authorization": "Bearer ${newToken ?? ''}",
          "Accept": "application/json",
        });
      }

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        // KONSISTEN: Return single object dari key "data"
        return {"success": true, "data": jsonResponse["data"]}; // Single object
      }

      if (response.statusCode == 404) {
        return {"success": false, "message": "Data tidak ditemukan"};
      }

      return {"success": false, "message": response.body};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // =====================================
  // UPLOAD RESEARCH COIN (ADMIN ONLY)
  // =====================================
  static Future<Map<String, dynamic>> UploadResearchCoin({
    required String title,
    required String fileLink,
    required File image,
    required File logoCoin,
  }) async {
    try {
      final token = await AuthStorage.getToken();

      Future<http.MultipartRequest> buildRequest(String? t) async {
        final request = http.MultipartRequest(
          "POST",
          Uri.parse("$_base/upload-research-coin-exclusive"),
        );
        request.headers.addAll({
          "Authorization": "Bearer ${t ?? ''}",
          "Accept": "application/json",
        });
        request.fields["title"] = title;
        request.fields["file"]  = fileLink;
        request.files.add(await http.MultipartFile.fromPath("Image",     image.path));
        request.files.add(await http.MultipartFile.fromPath("Logo_coin", logoCoin.path));
        return request;
      }

      var streamed     = await (await buildRequest(token)).send();
      var responseBody = await streamed.stream.bytesToString();

      // Auto-refresh 401 — rebuild MultipartRequest karena tidak bisa di-replay
      if (streamed.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (!refreshed) {
          return {"success": false, "message": "Session expired. Silakan login ulang."};
        }
        final newToken = await AuthStorage.getToken();
        streamed     = await (await buildRequest(newToken)).send();
        responseBody = await streamed.stream.bytesToString();
      }

      if (streamed.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        // KONSISTEN: Return object dari key "data"
        return {
          "success": true,
          "message": jsonResponse["message"],
          "data":    jsonResponse["data"], // Object berisi mongo_id, uploaded_by, dll
        };
      }

      return {"success": false, "message": responseBody};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ===============================
  // DELETE RESEARCH COIN
  // ===============================
  static Future<Map<String, dynamic>> DeleteResearchCoin({
    required String researchId,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse(
        "$_base/delete-research-coin-exclusive?research_id=$researchId",
      );

      var response = await http.delete(uri, headers: {
        "Authorization": "Bearer ${token ?? ''}",
        "Accept": "application/json",
      });

      // Auto-refresh 401
      if (response.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (!refreshed) {
          return {"success": false, "message": "Session expired. Silakan login ulang."};
        }
        final newToken = await AuthStorage.getToken();
        response = await http.delete(uri, headers: {
          "Authorization": "Bearer ${newToken ?? ''}",
          "Accept": "application/json",
        });
      }

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        // KONSISTEN: Return dari key "data" (null untuk delete)
        return {
          "success": true,
          "message": jsonResponse["message"],
          "data":    jsonResponse["data"], // null
        };
      }

      if (response.statusCode == 404) {
        return {"success": false, "message": "Data tidak ditemukan"};
      }

      if (response.statusCode == 400) {
        return {"success": false, "message": "ID tidak valid"};
      }

      return {"success": false, "message": response.body};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ===========================================
  // GET RESEARCH COIN WITH UPLOADER INFO
  // ===========================================
  static Future<Map<String, dynamic>> GetResearchCoinWithUploader() async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse("$_base/get-research-coin-with-upload-exclusive");

      var response = await http.get(uri, headers: {
        "Authorization": "Bearer ${token ?? ''}",
        "Accept": "application/json",
      });

      // Auto-refresh 401
      if (response.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (!refreshed) {
          return {"success": false, "message": "Session expired. Silakan login ulang."};
        }
        final newToken = await AuthStorage.getToken();
        response = await http.get(uri, headers: {
          "Authorization": "Bearer ${newToken ?? ''}",
          "Accept": "application/json",
        });
      }

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        // KONSISTEN: Return array dari key "data"
        return {"success": true, "data": jsonResponse["data"]}; // Array
      }

      return {"success": false, "message": response.body};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }
}