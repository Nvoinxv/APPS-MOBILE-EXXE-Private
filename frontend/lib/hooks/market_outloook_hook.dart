import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/auth_storage.dart';

class Market_Outlook_Hook {

  // ===============================
  // 1. GET ALL MARKET OUTLOOK
  // ===============================
  static Future<Map<String, dynamic>> getAllMarketOutlook({
    required String token,
  }) async {
    try {
      final response = await AuthStorage.get(
        "/market-outlook-exclusive",
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success' &&
            jsonResponse['data'] is List) {
          return {
            "success": true,
            "data": jsonResponse['data'],
          };
        }

        return {
          "success": false,
          "message": "Invalid response structure",
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
  // 2. GET BY TITLE
  // ===============================
  static Future<Map<String, dynamic>> getByTitle({
    required String token,
    required String title,
  }) async {
    try {
      final response = await AuthStorage.get(
        "/market-outlook-exclusive/title",
        queryParams: {"title": title},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success') {
          return {
            "success": true,
            "data": jsonResponse['data'],
          };
        }

        return {
          "success": false,
          "message": "Invalid response structure",
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
  // 3. UPLOAD (ADMIN ONLY)
  // ===============================
  static Future<Map<String, dynamic>> uploadMarketOutlook({
    required String token,
    required String title,
    required String date,
    required String isi1,
    required String isi2,
    required String isi3,
    required String imagePath1,
    required String imagePath2,
    required String imagePath3,
    required String videoPath,
    required String videoDrive,
    required String source,
  }) async {
    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("${AuthStorage.activeBaseUrl}/market-outlook-exclusive"),
      );

      request.fields['title']       = title;
      request.fields['Date']        = date;
      request.fields['Isi_1']       = isi1;
      request.fields['Isi_2']       = isi2;
      request.fields['Isi_3']       = isi3;
      request.fields['Video_Drive'] = videoDrive;
      request.fields['Source']      = source;

      request.files.add(await http.MultipartFile.fromPath('Images_1', imagePath1));
      request.files.add(await http.MultipartFile.fromPath('Images_2', imagePath2));
      request.files.add(await http.MultipartFile.fromPath('Images_3', imagePath3));
      request.files.add(await http.MultipartFile.fromPath('Video',    videoPath));

      final response = await http.Response.fromStream(
        await AuthStorage.sendMultipart(request),
      );

      return _processResponse(response);
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // ===============================
  // 4. DELETE (ADMIN ONLY)
  // ===============================
  static Future<Map<String, dynamic>> deleteMarketOutlook({
    required String token,
    required String marketOutlookId,
  }) async {
    try {
      final response = await AuthStorage.delete(
        "/market-outlook-exclusive/$marketOutlookId",
      );

      return _processResponse(response);
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // ===============================
  // 5. GET WITH UPLOADER INFO
  // ===============================
  static Future<Map<String, dynamic>> getWithUploader() async {
    try {
      final response = await AuthStorage.get(
        "/market-outlook-exclusive/full",
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success' &&
            jsonResponse['data'] is List) {
          return {
            "success": true,
            "data": jsonResponse['data'],
          };
        }

        return {
          "success": false,
          "message": "Invalid response structure",
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
  // HELPER: PROCESS RESPONSE
  // ===============================
  static Map<String, dynamic> _processResponse(http.Response response) {
    try {
      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": body['data'] ?? body,
          "message": body['message'],
        };
      } else {
        return {
          "success": false,
          "message": body['detail'] ?? body['message'] ?? "Terjadi kesalahan pada server",
          "code": response.statusCode,
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": "Failed to parse response: ${e.toString()}",
        "code": response.statusCode,
      };
    }
  }
}