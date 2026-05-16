import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/auth_storage.dart';

class News_Exclusive_Hook {

  // ===============================
  // GET ALL NEWS
  // ===============================
  static Future<Map<String, dynamic>> GetAllNewsExclusive() async {
    try {
      final response = await AuthStorage.get("/get-news-exclusive");

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
      final response = await AuthStorage.get(
        "/get-news-exclusive-title",
        queryParams: {"title": title},
      );

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
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("${AuthStorage.activeBaseUrl}/upload-news-exclusive"),
      );

      request.fields['title']       = title;
      request.fields['description'] = description;
      request.fields['source']      = source;
      request.fields['images_link'] = imagesLink;
      request.fields['news_date']   = newsDate;

      request.files.add(await http.MultipartFile.fromPath('images',   imagePath1));
      request.files.add(await http.MultipartFile.fromPath('images_2', imagePath2));

      final response = await http.Response.fromStream(
        await AuthStorage.sendMultipart(request),
      );

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
      final response = await AuthStorage.delete(
        "/delete-news-exclusive",
        queryParams: {"news_id": newsId},
      );

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
      final response = await AuthStorage.get(
        "/get-news-with-uploader-exclusive",
      );

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