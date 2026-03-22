import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class Research_Coin_Hook {
    static const String baseUrl = "http://127.0.0.1:8080";

    // ===============================
    // GET ALL RESEARCH COIN
    // ===============================
    static Future<Map<String, dynamic>> GetAllResearchCoin({
        required String token,
    }) async {
        try {
            final response = await http.get(
                Uri.parse("$baseUrl/get-research-coin-exclusive"),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                },
            );

            if (response.statusCode == 200) {
                final jsonResponse = jsonDecode(response.body);
                
                // ✅ KONSISTEN: Selalu return data dari key "data"
                return {
                    "success": true,
                    "data": jsonResponse["data"], // Array
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

    // =================================
    // GET RESEARCH COIN BY TITLE
    // =================================
    static Future<Map<String, dynamic>> GetResearchCoinByTitle({
        required String token,
        required String title,
    }) async {
        try {
            final response = await http.get(
                Uri.parse("$baseUrl/get-title-research-coin-exclusive?title=$title"),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                },
            );

            if (response.statusCode == 200) {
                final jsonResponse = jsonDecode(response.body);
                
                // KONSISTEN: Return single object dari key "data"
                return {
                    "success": true,
                    "data": jsonResponse["data"], // Single object
                };
            }
            
            if (response.statusCode == 404) {
                return {
                    "success": false,
                    "message": "Data tidak ditemukan",
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
    // UPLOAD RESEARCH COIN (ADMIN ONLY)
    // =====================================
    static Future<Map<String, dynamic>> UploadResearchCoin({
        required String token,
        required String title,
        required String fileLink,
        required File image,
        required File logoCoin,
    }) async {
        try {
            final request = http.MultipartRequest(
                "POST",
                Uri.parse("$baseUrl/upload-research-coin-exclusive"),
            );

            // ADD JWT HEADER
            request.headers.addAll({
                "Authorization": "Bearer $token",
                "Accept": "application/json",
            });

            // FORM DATA
            request.fields["title"] = title;
            request.fields["file"] = fileLink;

            // FILE DATA
            request.files.add(
                await http.MultipartFile.fromPath(
                    "Image",
                    image.path,
                ),
            );

            request.files.add(
                await http.MultipartFile.fromPath(
                    "Logo_coin",
                    logoCoin.path,
                ),
            );

            final streamedResponse = await request.send();
            final responseBody = await streamedResponse.stream.bytesToString();

            if (streamedResponse.statusCode == 200) {
                final jsonResponse = jsonDecode(responseBody);
                
                // ✅ KONSISTEN: Return object dari key "data"
                return {
                    "success": true,
                    "message": jsonResponse["message"],
                    "data": jsonResponse["data"], // Object berisi mongo_id, uploaded_by, dll
                };
            }
            
            return {
                "success": false,
                "message": responseBody,
            };
        } catch (e) {
            return {
                "success": false,
                "error": e.toString(),
            };
        }
    }

    // ===============================
    // DELETE RESEARCH COIN
    // ===============================
    static Future<Map<String, dynamic>> DeleteResearchCoin({
        required String token,
        required String researchId,
    }) async {
        try {
            final response = await http.delete(
                Uri.parse(
                    "$baseUrl/delete-research-coin-exclusive?research_id=$researchId",
                ),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                },
            );

            if (response.statusCode == 200) {
                final jsonResponse = jsonDecode(response.body);
                
                // ✅ KONSISTEN: Return dari key "data" (null untuk delete)
                return {
                    "success": true,
                    "message": jsonResponse["message"],
                    "data": jsonResponse["data"], // null
                };
            }
            
            if (response.statusCode == 404) {
                return {
                    "success": false,
                    "message": "Data tidak ditemukan",
                };
            }
            
            if (response.statusCode == 400) {
                return {
                    "success": false,
                    "message": "ID tidak valid",
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

    // ===========================================
    // GET RESEARCH COIN WITH UPLOADER INFO
    // ===========================================
    static Future<Map<String, dynamic>> GetResearchCoinWithUploader({
        required String token,
    }) async {
        try {
            final response = await http.get(
                Uri.parse(
                    "$baseUrl/get-research-coin-with-upload-exclusive",
                ),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                },
            );

            if (response.statusCode == 200) {
                final jsonResponse = jsonDecode(response.body);
                
                // ✅ KONSISTEN: Return array dari key "data"
                return {
                    "success": true,
                    "data": jsonResponse["data"], // Array
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
}