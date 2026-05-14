import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/auth_storage.dart';

class Daily_Research_Exclusive_Hook {

  // ===============================
  // GET ALL DAILY RESEARCH
  // ===============================
  static Future<Map<String, dynamic>> GetAllDailyResearch() async {
    try {
      final response = await AuthStorage.get(
        "/get-daily-research-exclusive",
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final data = jsonResponse["data"];
        if (data is! List) {
          return {"success": false, "message": "Invalid data format: expected List"};
        }
        return {"success": true, "data": data};
      }

      return {"success": false, "message": "Status ${response.statusCode}: ${response.body}"};
    } catch (e) {
      print("❌ Hook Error: $e");
      return {"success": false, "error": e.toString()};
    }
  }

  // ===============================
  // GET DAILY RESEARCH BY TITLE
  // ===============================
  static Future<Map<String, dynamic>> GetDailyResearchByTitle({
    required String title,
  }) async {
    try {
      final response = await AuthStorage.get(
        "/get-research-title-exclusive",
        queryParams: {"title": title},
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final data = jsonResponse["data"];
        if (data is! Map) {
          return {"success": false, "message": "Invalid data format: expected Map"};
        }
        return {"success": true, "data": data};
      }

      if (response.statusCode == 404) {
        return {"success": false, "message": "Data tidak ditemukan"};
      }

      return {"success": false, "message": "Status ${response.statusCode}: ${response.body}"};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // =====================================
  // UPLOAD DAILY RESEARCH (ADMIN ONLY)
  // multipart — ambil token manual dari storage
  // =====================================
  static Future<Map<String, dynamic>> UploadDailyResearch({
    required String title,
    required String subTitle,
    required String deskripsi1,
    required String deskripsi2,
    required String deskripsi3,
    required String date,
    required String source,
    required String imagePath,
    required String videoPath,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        return {"success": false, "message": "Token tidak ditemukan, silakan login ulang"};
      }

      var request = http.MultipartRequest(
        "POST",
        Uri.parse("$kBaseUrl/upload-daily-research-exclusive"),
      );

      request.headers.addAll({
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      });

      request.fields['title']       = title;
      request.fields['sub_title']   = subTitle;
      request.fields['deskripsi_1'] = deskripsi1;
      request.fields['deskripsi_2'] = deskripsi2;
      request.fields['deskripsi_3'] = deskripsi3;
      request.fields['Date']        = date;
      request.fields['Source']      = source;

      request.files.add(await http.MultipartFile.fromPath('images', imagePath));
      request.files.add(await http.MultipartFile.fromPath('Video',  videoPath));

      final streamedResponse = await request.send();
      final response         = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final data = jsonResponse["data"];
        if (data is! Map) {
          return {"success": false, "message": "Invalid data format: expected Map"};
        }
        return {
          "success": true,
          "message": jsonResponse["message"] ?? "Upload berhasil",
          "data": data,
        };
      }

      if (response.statusCode == 400) {
        return {"success": false, "message": "Format tanggal harus YYYY-MM-DD"};
      }

      return {"success": false, "message": "Status ${response.statusCode}: ${response.body}"};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ===============================
  // DELETE DAILY RESEARCH
  // ===============================
  static Future<Map<String, dynamic>> DeleteDailyResearch({
    required String researchId,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        return {"success": false, "message": "Token tidak ditemukan, silakan login ulang"};
      }

      final response = await http.delete(
        Uri.parse("$kBaseUrl/delete-daily-research-exclusive?research_daily_id=$researchId"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return {
          "success": true,
          "message": jsonResponse["message"] ?? "Berhasil dihapus",
          "data": jsonResponse["data"],
        };
      }

      if (response.statusCode == 404) return {"success": false, "message": "Data tidak ditemukan"};
      if (response.statusCode == 400) return {"success": false, "message": "ID tidak valid"};

      return {"success": false, "message": "Status ${response.statusCode}: ${response.body}"};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ===========================================
  // GET DAILY RESEARCH WITH UPLOADER
  // ===========================================
  static Future<Map<String, dynamic>> GetDailyResearchWithUploader() async {
    try {
      final response = await AuthStorage.get(
        "/get-upload-daily-research-with-uploader-exclusive",
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final data = jsonResponse["data"];
        if (data is! List) {
          return {"success": false, "message": "Invalid data format: expected List"};
        }
        return {"success": true, "data": data};
      }

      return {"success": false, "message": "Status ${response.statusCode}: ${response.body}"};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }
}