import 'package:http/http.dart' as http;
import 'dart:convert';

class Daily_Research_Exclusive_Hook {
    static const String baseUrl = "http://127.0.0.1:8080";

    // ===============================
    // GET ALL DAILY RESEARCH (FIXED)
    // ===============================
    static Future<Map<String, dynamic>> GetAllDailyResearch({
        required String token,
    }) async {
        try {
            final response = await http.get(
                Uri.parse("$baseUrl/get-daily-research-exclusive"),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                },
            );

            if (response.statusCode == 200) {
                final jsonResponse = jsonDecode(response.body);
            
                // ✅ Validasi data adalah List
                final data = jsonResponse["data"];
                if (data is! List) {
                    return {
                        "success": false,
                        "message": "Invalid data format: expected List",
                    };
                }
                
                // ✅ HANYA return data as-is, biarkan Flutter handle parsing
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

    // ===============================
    // GET DAILY RESEARCH BY TITLE
    // ===============================
    static Future<Map<String, dynamic>> GetDailyResearchByTitle({
        required String title,
        required String token,
    }) async {
        try {
            final response = await http.get(
                Uri.parse(
                    "$baseUrl/get-research-title-exclusive?title=${Uri.encodeComponent(title)}",
                ),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                }
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
                    "data": data,
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
    // UPLOAD DAILY RESEARCH (ADMIN ONLY)
    // =====================================
    static Future<Map<String, dynamic>> UploadDailyResearch({
        required String token,
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
            var request = http.MultipartRequest(
                "POST",
                Uri.parse("$baseUrl/upload-daily-research-exclusive"),
            );

            request.headers.addAll({
                "Authorization": "Bearer $token",
                "Accept": "application/json",
            });

            request.fields['title'] = title;
            request.fields['sub_title'] = subTitle;
            request.fields['deskripsi_1'] = deskripsi1;
            request.fields['deskripsi_2'] = deskripsi2;
            request.fields['deskripsi_3'] = deskripsi3;
            request.fields['Date'] = date;
            request.fields['Source'] = source;

            request.files.add(
                await http.MultipartFile.fromPath('images', imagePath),
            );

            request.files.add(
                await http.MultipartFile.fromPath('Video', videoPath),
            );

            final streamedResponse = await request.send();
            final response = await http.Response.fromStream(streamedResponse);

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
            return {
                "success": false,
                "error": e.toString(),
            };
        }
    }

    // ===============================
    // DELETE DAILY RESEARCH
    // ===============================
    static Future<Map<String, dynamic>> DeleteDailyResearch({
        required String token,
        required String researchId,
    }) async {
        try {
            final response = await http.delete(
                Uri.parse(
                    "$baseUrl/delete-daily-research-exclusive?research_daily_id=$researchId",
                ),
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
    // GET DAILY RESEARCH WITH UPLOADER
    // ===========================================
    static Future<Map<String, dynamic>> GetDailyResearchWithUploader({
        required String token,
    }) async {
        try {
            final response = await http.get(
                Uri.parse(
                    "$baseUrl/get-upload-daily-research-with-uploader-exclusive",
                ),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                },
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