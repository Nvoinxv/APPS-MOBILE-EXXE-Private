import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Quant_Exclusive_Hook {
  static const String baseUrl = "http://127.0.0.1:8080";

  // ===============================
  // GET ALL QUANT //
  // ===============================
  static Future<Map<String, dynamic>> GetAllQuantExclusive({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get-quant-exclusive"),  // ✅ Fixed endpoint
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
        "message": response.body,
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // ===============================
  // GET QUANT BY TITLE //
  // ===============================
  static Future<Map<String, dynamic>> GetQuantByTitle({
    required String token,
    required String title,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/get-quant-title-exclusive?title=${Uri.encodeComponent(title)}",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        
        // ✅ Validate structure (single object)
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
        "message": response.body,
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // =====================================
  // UPLOAD QUANT (ADMIN ONLY) //
  // =====================================
  static Future<Map<String, dynamic>> UploadQuantExclusiveData({
    required String token,
    required String judulPair,
    required String name,  // ✅ Added missing name field
    required String linkTradingView,
    required String imageSampulPath,
    required String imageChartPath,
    required String judul1,
    required String deskripsi1,
    required String judul2,
    required String deskripsi2,
    required String judul3,
    required String deskripsi3,
    required String judul4,
    required String deskripsi4,
    required String AI_Summary,
    required String Source,
  }) async {
    try {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/upload-quant-exclusive"),
      );

      request.headers.addAll({
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      });

      // ✅ Add all required fields
      request.fields['judul_pair'] = judulPair;
      request.fields['Name'] = name;  // ✅ Don't forget this!
      request.fields['Link_Trading_View'] = linkTradingView;

      request.fields['Judul_1'] = judul1;
      request.fields['Deskripsi_1'] = deskripsi1;
      request.fields['Judul_2'] = judul2;
      request.fields['Deskripsi_2'] = deskripsi2;
      request.fields['Judul_3'] = judul3;
      request.fields['Deskripsi_3'] = deskripsi3;
      request.fields['Judul_4'] = judul4;
      request.fields['Deskripsi_4'] = deskripsi4;
      
      request.fields['AI_Summary'] = AI_Summary;
      request.fields['Source'] = Source;

      request.files.add(
        await http.MultipartFile.fromPath(
          'Image_sampul',
          imageSampulPath,
        ),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'Image_chart',
          imageChartPath,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // ===============================
  // DELETE QUANT //
  // ===============================
  static Future<Map<String, dynamic>> DeleteQuantExclusive({
    required String token,
    required String quantId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse(
          "$baseUrl/delete-quant-trade-exclusive?quant_id=$quantId",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ===========================================
  // GET QUANT WITH UPLOADER //
  // ===========================================
  static Future<Map<String, dynamic>> GetQuantWithUploader() async {
    try {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/get-quant-trade-with-upload-exclusive",
        ),
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
        "message": response.body,
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // ===============================
  // RESPONSE HANDLER //
  // ===============================
  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      try {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return {
          "success": true,
          "data": jsonResponse,
        };
      } catch (e) {
        return {
          "success": false,
          "message": "Failed to parse response",
        };
      }
    }
    
    return {
      "success": false,
      "message": response.body,
      "statusCode": response.statusCode,
    };
  }
}