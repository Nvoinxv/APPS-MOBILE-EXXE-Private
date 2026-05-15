import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/auth_storage.dart';

// Base URL — pakai TestingUrlExternal dari auth_storage.dart
const String _base = TestingUrlExternal;

class News_Exclusive_Hook {

  // ===============================
  // GET ALL NEWS
  // ===============================
  static Future<Map<String, dynamic>> GetAllNewsExclusive() async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse("$_base/get-news-exclusive");

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
        final data = jsonResponse["data"];

        if (data is! List) {
          return {
            "success": false,
            "message": "Invalid data format: expected List",
          };
        }

        return {"success": true, "data": data};
      }

      return {
        "success": false,
        "message": "Status ${response.statusCode}: ${response.body}",
      };
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // =================================
  // GET NEWS BY TITLE
  // =================================
  static Future<Map<String, dynamic>> GetNewsByTitle({
    required String title,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse(
        "$_base/get-news-exclusive-title?title=${Uri.encodeComponent(title)}",
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
        final data = jsonResponse["data"];

        if (data is! Map) {
          return {
            "success": false,
            "message": "Invalid data format: expected Map",
          };
        }

        return {"success": true, "data": data};
      }

      if (response.statusCode == 404) {
        return {"success": false, "message": "News not found"};
      }

      return {
        "success": false,
        "message": "Status ${response.statusCode}: ${response.body}",
      };
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // =====================================
  // UPLOAD NEWS (ADMIN ONLY)
  // =====================================
  static Future<Map<String, dynamic>> UploadNewsExclusive({
    required String title,
    required String description,
    required String source,
    required String imagesLink,
    required String newsDate,
    required String imagePath1,
    required String imagePath2,
  }) async {
    try {
      final token = await AuthStorage.getToken();

      var request = http.MultipartRequest(
        "POST",
        Uri.parse("$_base/upload-news-exclusive"),
      );

      request.headers.addAll({
        "Authorization": "Bearer ${token ?? ''}",
        "Accept": "application/json",
      });

      request.fields['title']       = title;
      request.fields['description'] = description;
      request.fields['source']      = source;
      request.fields['images_link'] = imagesLink;
      request.fields['news_date']   = newsDate;

      request.files.add(await http.MultipartFile.fromPath('images',   imagePath1));
      request.files.add(await http.MultipartFile.fromPath('images_2', imagePath2));

      final streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // Auto-refresh 401 — rebuild request karena MultipartRequest tidak bisa di-replay
      if (response.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (!refreshed) {
          return {"success": false, "message": "Session expired. Silakan login ulang."};
        }
        final newToken = await AuthStorage.getToken();

        var retryRequest = http.MultipartRequest(
          "POST",
          Uri.parse("$_base/upload-news-exclusive"),
        );
        retryRequest.headers.addAll({
          "Authorization": "Bearer ${newToken ?? ''}",
          "Accept": "application/json",
        });
        retryRequest.fields['title']       = title;
        retryRequest.fields['description'] = description;
        retryRequest.fields['source']      = source;
        retryRequest.fields['images_link'] = imagesLink;
        retryRequest.fields['news_date']   = newsDate;
        retryRequest.files.add(await http.MultipartFile.fromPath('images',   imagePath1));
        retryRequest.files.add(await http.MultipartFile.fromPath('images_2', imagePath2));

        final retryStreamed = await retryRequest.send();
        response = await http.Response.fromStream(retryStreamed);
      }

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final data = jsonResponse["data"];

        if (data is! Map) {
          return {
            "success": false,
            "message": "Invalid data format: expected Map",
          };
        }

        return {
          "success": true,
          "message": jsonResponse["message"] ?? "Upload berhasil",
          "data": data,
        };
      }

      if (response.statusCode == 400) {
        return {
          "success": false,
          "message": "Format tanggal harus YYYY-MM-DD",
        };
      }

      return {
        "success": false,
        "message": "Status ${response.statusCode}: ${response.body}",
      };
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ===============================
  // DELETE NEWS
  // ===============================
  static Future<Map<String, dynamic>> DeleteNewsExclusive({
    required String newsId,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse("$_base/delete-news-exclusive?news_id=$newsId");

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
        return {
          "success": true,
          "message": jsonResponse["message"] ?? "Berhasil dihapus",
          "data": jsonResponse["data"],
        };
      }

      if (response.statusCode == 404) {
        return {"success": false, "message": "News tidak ditemukan"};
      }

      if (response.statusCode == 400) {
        return {"success": false, "message": "ID tidak valid"};
      }

      return {
        "success": false,
        "message": "Status ${response.statusCode}: ${response.body}",
      };
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ===========================================
  // GET NEWS WITH UPLOADER INFO
  // ===========================================
  static Future<Map<String, dynamic>> GetNewsWithUploader() async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse("$_base/get-news-with-uploader-exclusive");

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
        final data = jsonResponse["data"];

        if (data is! List) {
          return {
            "success": false,
            "message": "Invalid data format: expected List",
          };
        }

        return {"success": true, "data": data};
      }

      return {
        "success": false,
        "message": "Status ${response.statusCode}: ${response.body}",
      };
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }
}