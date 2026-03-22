import 'package:http/http.dart' as http;
import 'dart:convert';

class Trade_Ideas_Hook {
    static const String baseUrl = "http://127.0.0.1:8080";

    // ===============================
    // GET ALL TRADE IDEAS
    // ===============================
    static Future<Map<String, dynamic>> GetAllTradeIdeas({
        required String token,
    }) async {
        try {
            final response = await http.get(
                Uri.parse("$baseUrl/trade-ideas-exclusive"),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                },
            );

            if (response.statusCode == 200) {
                final jsonData = jsonDecode(response.body);
                
                // ✅ EXTRACT DATA DARI WRAPPER
                return {
                    "success": true,
                    "data": jsonData["data"] ?? [], // Ambil array dari key "data"
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

    // =================================
    // GET TRADE IDEAS BY TITLE
    // =================================
    static Future<Map<String, dynamic>> GetTradeIdeasByTitle({
        required String token,
        required String title,
    }) async {
        try {
            final response = await http.get(
                Uri.parse(
                    "$baseUrl/trade-ideas-exclusive/title?title=${Uri.encodeComponent(title)}",
                ),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                },
            );

            if (response.statusCode == 200) {
                final jsonData = jsonDecode(response.body);
                
                // ✅ EXTRACT DATA DARI WRAPPER
                return {
                    "success": true,
                    "data": jsonData["data"], // Single object
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

    // =====================================
    // UPLOAD TRADE IDEAS (ADMIN ONLY)
    // =====================================
    static Future<Map<String, dynamic>> UploadTradeIdea({
        required String token,
        required String tradeIdea,
        required String tipeTrade,
        required String aktivasi,
        required String date,
        required double entry,
        required double stoploss,
        required double target,
        required bool status,
    }) async {
        try {
            final response = await http.post(
                Uri.parse("$baseUrl/trade-ideas-exclusive"),
                headers: {
                    "Authorization": "Bearer $token",
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json",
                },
                body: {
                    "Trade_idea": tradeIdea,
                    "Tipe_trade": tipeTrade,
                    "Aktivasi": aktivasi,
                    "Date": date,
                    "Entry": entry.toString(),
                    "Stoploss": stoploss.toString(),
                    "Target": target.toString(),
                    "Status": status.toString(),
                },
            );

            if (response.statusCode == 200) {
                return {
                    "success": true,
                    "data": jsonDecode(response.body),
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
    // DELETE TRADE IDEAS
    // ===============================
    static Future<Map<String, dynamic>> DeleteTradeIdea({
        required String token,
        required String tradeId,
    }) async {
        try {
            final response = await http.delete(
                Uri.parse(
                    "$baseUrl/trade-ideas-exclusive/$tradeId",
                ),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                },
            );

            if (response.statusCode == 200) {
                return {
                    "success": true,
                    "data": jsonDecode(response.body),
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

    // ===========================================
    // GET TRADE IDEAS WITH UPLOADER INFO
    // ===========================================
    static Future<Map<String, dynamic>> GetTradeIdeasWithUploader({
        required String token,
    }) async {
        try {
            final response = await http.get(
                Uri.parse(
                    "$baseUrl/trade-ideas-exclusive/full",
                ),
                headers: {
                    "Authorization": "Bearer $token",
                    "Accept": "application/json",
                },
            );

            if (response.statusCode == 200) {
                final jsonData = jsonDecode(response.body);
                
                // ✅ EXTRACT DATA DARI WRAPPER
                return {
                    "success": true,
                    "data": jsonData["data"] ?? [], // Ambil array dari key "data"
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
}