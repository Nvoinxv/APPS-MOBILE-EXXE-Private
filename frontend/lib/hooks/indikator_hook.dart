// lib/hooks/indikator_hook.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/script_file.dart';
import '../utils/auth_storage.dart';
import '../postingan/postingan_tradingview.dart';

class Indicator_Exclusive_Hook {
  // ─── base URL pakai TestingUrlExternal dari auth_storage ────────────────
  static const String _base = TestingUrlExternal;

  // ===============================
  // GET ALL INDICATORS
  // ===============================
  static Future<Map<String, dynamic>> GetAllIndicators() async {
    try {
      final token = await AuthStorage.getToken();
      final response = await http.get(
        Uri.parse("$_base/tradingview/indicators"),
        headers: {
          "Authorization": "Bearer ${token ?? ''}",
          "Accept": "application/json",
        },
      );

      // Auto-refresh jika 401
      if (response.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (!refreshed) {
          return {"success": false, "message": "Session expired. Silakan login ulang."};
        }
        return GetAllIndicators(); // retry setelah refresh
      }

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

        return {"success": true, "data": indicators};
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
  // DELETE INDICATOR
  // ===============================
  static Future<Map<String, dynamic>> DeleteIndicator({
    required String indicatorId,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse("$_base/tradingview/indicators/$indicatorId");

      var response = await http.delete(
        uri,
        headers: {
          "Authorization": "Bearer ${token ?? ''}",
          "Accept": "application/json",
        },
      );

      // Auto-refresh jika 401
      if (response.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (!refreshed) {
          return {"success": false, "message": "Session expired. Silakan login ulang."};
        }
        final newToken = await AuthStorage.getToken();
        response = await http.delete(
          uri,
          headers: {
            "Authorization": "Bearer ${newToken ?? ''}",
            "Accept": "application/json",
          },
        );
      }

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
                .toList() ??
            [],
        previewCode: j["preview_code"] as String? ?? "",
        linkedFile: ScriptFile(
          id:        j["id"]              as String,
          name:      j["script_name"]     as String? ?? "indicator.py",
          content:   j["script_content"]  as String? ?? "",
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