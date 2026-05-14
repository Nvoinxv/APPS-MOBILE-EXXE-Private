// lib/hooks/indikator_hook.dart

import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/script_file.dart';
import '../postingan/postingan_tradingview.dart';

class Indicator_Exclusive_Hook {
  static const String baseUrl = "http://localhost:8080";

  // ===============================
  // GET ALL INDICATORS
  // ===============================
  static Future<Map<String, dynamic>> GetAllIndicators({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/tradingview/indicators"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);

        if (jsonList is! List) {
          return {
            "success": false,
            "message": "Invalid data format: expected List",
          };
        }

        final List<IndicatorMeta> indicators = jsonList
            .whereType<Map<String, dynamic>>()
            .map(_mapJsonToMeta)
            .whereType<IndicatorMeta>()
            .toList();

        return {
          "success": true,
          "data": indicators,
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
  // DELETE INDICATOR
  // ===============================
  static Future<Map<String, dynamic>> DeleteIndicator({
    required String token,
    required String indicatorId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/tradingview/indicators/$indicatorId"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 204) {
        return {"success": true, "message": "Berhasil dihapus"};
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
  // MAPPER
  // ===============================
  static IndicatorMeta? _mapJsonToMeta(Map<String, dynamic> j) {
    try {
      final updatedAt = DateTime.parse(j["updated_at"] as String);
      final createdAt = DateTime.parse(j["created_at"] as String);

      return IndicatorMeta(
        id:          j["id"] as String,
        name:        j["name"] as String,
        description: j["description"] as String? ?? "",
        category:    _parseCategory(j["category"] as String?),
        ownership:   j["ownership"] == "shared"
            ? IndicatorOwnership.shared
            : IndicatorOwnership.personal,
        authorId:    j["author_id"]    as String? ?? "",
        authorLabel: j["author_label"] as String? ?? "Unknown",
        tags: (j["tags"] as List<dynamic>?)
                ?.map((t) => t.toString())
                .toList() ?? [],
        previewCode: j["preview_code"]   as String? ?? "",
        linkedFile: ScriptFile(
          id:        j["id"]          as String,
          name:      j["script_name"] as String? ?? "indicator.py",
          content:   j["script_content"] as String? ?? "",
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
        updatedAt:  updatedAt,
        isFavorite: j["is_favorite"] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  static IndicatorCategory _parseCategory(String? raw) {
    switch (raw) {
      case "momentum":   return IndicatorCategory.momentum;
      case "trend":      return IndicatorCategory.trend;
      case "volatility": return IndicatorCategory.volatility;
      case "volume":     return IndicatorCategory.volume;
      default:           return IndicatorCategory.custom;
    }
  }
}