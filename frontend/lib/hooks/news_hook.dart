import 'package:http/http.dart' as http;
import 'dart:convert';

class News_Exclusive_Hook {
    static const String baseUrl = "http://127.0.0.1:8080";

    // ===============================
    // GET ALL NEWS
    // ===============================
    static Future<Map<String, dynamic>> GetAllNewsExclusive({
        required String token,
    }) async {
        try {
            final response = await http.get(
                Uri.parse("$baseUrl/get-news-exclusive"),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                },
            );

            if (response.statusCode == 200) {
                final jsonResponse = jsonDecode(response.body);
                final data = jsonResponse["data"];
                
                // ✅ Validasi data adalah List
                if (data is! List) {
                    return {
                        "success": false,
                        "message": "Invalid data format: expected List",
                    };
                }
                
                return {
                    "success": true,
                    "data": data,
                };
            }
            
            return {
                "success": false,
                "message": "Status ${response.statusCode}: ${response.body}",
            };
        } catch (e) {
            print("❌ Hook Error: $e");
            return {
                "success": false,
                "error": e.toString(),
            };
        }
    }

    // =================================
    // GET NEWS BY TITLE
    // =================================
    static Future<Map<String, dynamic>> GetNewsByTitle({
        required String token,
        required String title,
    }) async {
        try {
            final response = await http.get(
                Uri.parse(
                    "$baseUrl/get-news-exclusive-title?title=${Uri.encodeComponent(title)}",
                ),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                },
            );

            if (response.statusCode == 200) {
                final jsonResponse = jsonDecode(response.body);
                final data = jsonResponse["data"];
                
                // ✅ Validasi data adalah Map
                if (data is! Map) {
                    return {
                        "success": false,
                        "message": "Invalid data format: expected Map",
                    };
                }
                
                return {
                    "success": true,
                    "data": data,
                };
            }

            if (response.statusCode == 404) {
                return {
                    "success": false,
                    "message": "News not found",
                };
            }

            return {
                "success": false,
                "message": "Status ${response.statusCode}: ${response.body}",
            };
        } catch (e) {
            return {
                "success": false,
                "error": e.toString(),
            };
        }
    }

    // =====================================
    // UPLOAD NEWS (ADMIN ONLY)
    // =====================================
    static Future<Map<String, dynamic>> UploadNewsExclusive({
        required String token,
        required String title,
        required String description,
        required String source,
        required String imagesLink,
        required String newsDate,
        required String imagePath1,
        required String imagePath2,
    }) async {
        try {
            var request = http.MultipartRequest(
                "POST",
                Uri.parse("$baseUrl/upload-news-exclusive"),
            );

            request.headers.addAll({
                "Authorization": "Bearer $token",
                "Accept": "application/json",
            });

            request.fields['title'] = title;
            request.fields['description'] = description;
            request.fields['source'] = source;
            request.fields['images_link'] = imagesLink;
            request.fields['news_date'] = newsDate;

            request.files.add(
                await http.MultipartFile.fromPath('images', imagePath1)
            );
            request.files.add(
                await http.MultipartFile.fromPath('images_2', imagePath2)
            );

            final streamedResponse = await request.send();
            final response = await http.Response.fromStream(streamedResponse);

            if (response.statusCode == 200) {
                final jsonResponse = jsonDecode(response.body);
                final data = jsonResponse["data"];
                
                // ✅ Validasi data adalah Map
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
            return {
                "success": false,
                "error": e.toString(),
            };
        }
    }
    
    // ===============================
    // DELETE NEWS
    // ===============================
    static Future<Map<String, dynamic>> DeleteNewsExclusive({
        required String token,
        required String newsId,
    }) async {
        try {
            final response = await http.delete(
                Uri.parse("$baseUrl/delete-news-exclusive?news_id=$newsId"),
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

            if (response.statusCode == 404) {
                return {
                    "success": false,
                    "message": "News tidak ditemukan",
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
                "message": "Status ${response.statusCode}: ${response.body}",
            };
        } catch (e) {
            return {
                "success": false,
                "error": e.toString(),
            };
        }
    }

    // ===========================================
    // GET NEWS WITH UPLOADER INFO
    // ===========================================
    static Future<Map<String, dynamic>> GetNewsWithUploader({
        required String token,
    }) async {
        try {
            final response = await http.get(
                Uri.parse(
                    "$baseUrl/get-news-with-uploader-exclusive",
                ),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                },
            );

            if (response.statusCode == 200) {
                final jsonResponse = jsonDecode(response.body);
                final data = jsonResponse["data"];
                
                // ✅ Validasi data adalah List
                if (data is! List) {
                    return {
                        "success": false,
                        "message": "Invalid data format: expected List",
                    };
                }
                
                return {
                    "success": true,
                    "data": data,
                };
            }

            return {
                "success": false,
                "message": "Status ${response.statusCode}: ${response.body}",
            };
        } catch (e) {
            return {
                "success": false,
                "error": e.toString(),
            };
        }
    }
}