import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/auth_storage.dart';

class Quant_Exclusive_Hook {

  // ===============================
  // GET ALL QUANT
  // ===============================
  static Future<Map<String, dynamic>> GetAllQuantExclusive() async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse("${AuthStorage.activeBaseUrl}/get-quant-exclusive");

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
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success' && jsonResponse['data'] is List) {
          return {"success": true, "data": jsonResponse['data']};
        }

        return {"success": false, "message": "Invalid response structure"};
      }

      return {"success": false, "message": response.body};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ===============================
  // GET QUANT BY TITLE
  // ===============================
  static Future<Map<String, dynamic>> GetQuantByTitle({
    required String title,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse(
        "${AuthStorage.activeBaseUrl}/get-quant-title-exclusive?title=${Uri.encodeComponent(title)}",
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
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success') {
          return {"success": true, "data": jsonResponse['data']};
        }

        return {"success": false, "message": "Invalid response structure"};
      }

      return {"success": false, "message": response.body};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // =====================================
  // UPLOAD QUANT (ADMIN ONLY)
  // =====================================
  static Future<Map<String, dynamic>> UploadQuantExclusiveData({
    required String judulPair,
    required String name,
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
      final token = await AuthStorage.getToken();

      var request = http.MultipartRequest(
        "POST",
        Uri.parse("${AuthStorage.activeBaseUrl}/upload-quant-exclusive"),
      );

      request.headers.addAll({
        "Authorization": "Bearer ${token ?? ''}",
        "Accept": "application/json",
      });

      request.fields['judul_pair']        = judulPair;
      request.fields['Name']              = name;
      request.fields['Link_Trading_View'] = linkTradingView;
      request.fields['Judul_1']           = judul1;
      request.fields['Deskripsi_1']       = deskripsi1;
      request.fields['Judul_2']           = judul2;
      request.fields['Deskripsi_2']       = deskripsi2;
      request.fields['Judul_3']           = judul3;
      request.fields['Deskripsi_3']       = deskripsi3;
      request.fields['Judul_4']           = judul4;
      request.fields['Deskripsi_4']       = deskripsi4;
      request.fields['AI_Summary']        = AI_Summary;
      request.fields['Source']            = Source;

      request.files.add(
        await http.MultipartFile.fromPath('Image_sampul', imageSampulPath),
      );
      request.files.add(
        await http.MultipartFile.fromPath('Image_chart', imageChartPath),
      );

      final streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // Auto-refresh 401 — rebuild MultipartRequest karena tidak bisa di-replay
      if (response.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (!refreshed) {
          return {"success": false, "message": "Session expired. Silakan login ulang."};
        }
        final newToken = await AuthStorage.getToken();

        var retryRequest = http.MultipartRequest(
          "POST",
          Uri.parse("${AuthStorage.activeBaseUrl}/upload-quant-exclusive"),
        );
        retryRequest.headers.addAll({
          "Authorization": "Bearer ${newToken ?? ''}",
          "Accept": "application/json",
        });
        retryRequest.fields['judul_pair']        = judulPair;
        retryRequest.fields['Name']              = name;
        retryRequest.fields['Link_Trading_View'] = linkTradingView;
        retryRequest.fields['Judul_1']           = judul1;
        retryRequest.fields['Deskripsi_1']       = deskripsi1;
        retryRequest.fields['Judul_2']           = judul2;
        retryRequest.fields['Deskripsi_2']       = deskripsi2;
        retryRequest.fields['Judul_3']           = judul3;
        retryRequest.fields['Deskripsi_3']       = deskripsi3;
        retryRequest.fields['Judul_4']           = judul4;
        retryRequest.fields['Deskripsi_4']       = deskripsi4;
        retryRequest.fields['AI_Summary']        = AI_Summary;
        retryRequest.fields['Source']            = Source;
        retryRequest.files.add(
          await http.MultipartFile.fromPath('Image_sampul', imageSampulPath),
        );
        retryRequest.files.add(
          await http.MultipartFile.fromPath('Image_chart', imageChartPath),
        );

        final retryStreamed = await retryRequest.send();
        response = await http.Response.fromStream(retryStreamed);
      }

      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ===============================
  // DELETE QUANT
  // ===============================
  static Future<Map<String, dynamic>> DeleteQuantExclusive({
    required String quantId,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse(
        "${AuthStorage.activeBaseUrl}/delete-quant-trade-exclusive?quant_id=$quantId",
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

      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ===========================================
  // GET QUANT WITH UPLOADER
  // ===========================================
  static Future<Map<String, dynamic>> GetQuantWithUploader() async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse("${AuthStorage.activeBaseUrl}/get-quant-trade-with-upload-exclusive");

      var response = await http.get(
        uri,
        headers: {
          if (token != null && token.isNotEmpty)
            "Authorization": "Bearer $token",
        },
      );

      // Auto-refresh 401
      if (response.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (!refreshed) {
          return {"success": false, "message": "Session expired. Silakan login ulang."};
        }
        final newToken = await AuthStorage.getToken();
        response = await http.get(
          uri,
          headers: {
            if (newToken != null && newToken.isNotEmpty)
              "Authorization": "Bearer $newToken",
          },
        );
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success' && jsonResponse['data'] is List) {
          return {"success": true, "data": jsonResponse['data']};
        }

        return {"success": false, "message": "Invalid response structure"};
      }

      return {"success": false, "message": response.body};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ===============================
  // RESPONSE HANDLER
  // ===============================
  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      try {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return {"success": true, "data": jsonResponse};
      } catch (e) {
        return {"success": false, "message": "Failed to parse response"};
      }
    }

    return {
      "success":    false,
      "message":    response.body,
      "statusCode": response.statusCode,
    };
  }
}