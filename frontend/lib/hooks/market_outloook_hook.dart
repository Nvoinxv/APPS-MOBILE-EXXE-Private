import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class Market_Outlook_Hook {
  static const String baseUrl = "http://127.0.0.1:8080";

  static Future<Map<String, dynamic>> getAllMarketOutlook({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/market-outlook-exclusive"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        
        // ✅ Validate structure
        if (jsonResponse['status'] == 'success' && 
            jsonResponse['data'] is List) {
          return {
            "success": true,
            "data": jsonResponse['data'],  // Return the list directly
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
  // 2. GET BY TITLE (REQUIRES AUTH)
  // ✅ FIXED: Add token parameter and proper validation
  // ===============================
  static Future<Map<String, dynamic>> getByTitle({
    required String token,
    required String title,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/market-outlook-exclusive/title?title=${Uri.encodeComponent(title)}"
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        
        // ✅ Validate structure (single object or null)
        if (jsonResponse['status'] == 'success') {
          return {
            "success": true,
            "data": jsonResponse['data'],  // Can be null or object
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
  // ✅ FIXED: Better error handling
  // ===============================
  static Future<Map<String, dynamic>> uploadMarketOutlook({
    required String token,
    required String title,
    required String date, // Format: YYYY-MM-DD
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
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/market-outlook-exclusive"),
      );

      // Header Authorization
      request.headers.addAll({
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      });

      // Form Fields
      request.fields['title'] = title;
      request.fields['Date'] = date;
      request.fields['Isi_1'] = isi1;
      request.fields['Isi_2'] = isi2;
      request.fields['Isi_3'] = isi3;
      request.fields['Video_Drive'] = videoDrive;
      request.fields['Source'] = source;

      // Files (Images & Video)
      request.files.add(
        await http.MultipartFile.fromPath('Images_1', imagePath1)
      );
      request.files.add(
        await http.MultipartFile.fromPath('Images_2', imagePath2)
      );
      request.files.add(
        await http.MultipartFile.fromPath('Images_3', imagePath3)
      );
      request.files.add(
        await http.MultipartFile.fromPath('Video', videoPath)
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

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
      final response = await http.delete(
        Uri.parse("$baseUrl/market-outlook-exclusive/$marketOutlookId"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
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
  // 5. GET WITH UPLOADER INFO (PUBLIC)
  // ✅ FIXED: Properly validate and extract list
  // ===============================
  static Future<Map<String, dynamic>> getWithUploader() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/market-outlook-exclusive/full"),
        headers: {
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        
        // ✅ Validate structure
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
  // ✅ FIXED: Better error handling
  // ===============================
  static Map<String, dynamic> _processResponse(http.Response response) {
    try {
      final Map<String, dynamic> body = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": body['data'] ?? body,
          "message": body['message']
        };
      } else {
        return {
          "success": false,
          "message": body['detail'] ?? body['message'] ?? "Terjadi kesalahan pada server",
          "code": response.statusCode
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": "Failed to parse response: ${e.toString()}",
        "code": response.statusCode
      };
    }
  }
}