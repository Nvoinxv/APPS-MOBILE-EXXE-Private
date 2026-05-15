// news_ai_hook.dart
// ------------------
// Hook untuk endpoint AI News Generator — EXXE News
//
// Changelog:
//   - Tambah field `generatedSummary` di GeneratedNewsArticle
//     (1–2 kalimat ringkasan, maks ~200 karakter, untuk preview card)
//   - Migrasi URL ke TestingUrlExternal via AuthStorage
//   - Token diambil otomatis dari AuthStorage.getToken()
//   - Auto-refresh 401 via AuthStorage.refreshAccessToken()

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/auth_storage.dart';

// ---------------------------------------------------------------------------
// Base URL — pakai TestingUrlExternal dari auth_storage.dart
// ---------------------------------------------------------------------------

const String _kBaseUrl = TestingUrlExternal;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class GeneratedNewsArticle {
  final String originalTitle;
  final String originalLink;
  final String originalSource;
  final String originalDomain;
  final String originalPublished;

  final String generatedTitle;
  final String generatedSummary; // 1–2 kalimat, maks ~200 karakter
  final String generatedBody;
  final String imageUrl;

  final String sentiment;
  final double confidence;
  final double score;

  final String generatedAt;
  final String owner;

  const GeneratedNewsArticle({
    required this.originalTitle,
    required this.originalLink,
    required this.originalSource,
    required this.originalDomain,
    required this.originalPublished,
    required this.generatedTitle,
    required this.generatedSummary,
    required this.generatedBody,
    required this.sentiment,
    required this.confidence,
    required this.score,
    required this.generatedAt,
    required this.owner,
    required this.imageUrl,
  });

  factory GeneratedNewsArticle.fromJson(Map<String, dynamic> json) {
    return GeneratedNewsArticle(
      originalTitle:     json['original_title']     as String? ?? '',
      originalLink:      json['original_link']      as String? ?? '',
      originalSource:    json['original_source']    as String? ?? '',
      originalDomain:    json['original_domain']    as String? ?? '',
      originalPublished: json['original_published'] as String? ?? '',
      generatedTitle:    json['generated_title']    as String? ?? '',
      imageUrl:          json['Image']              as String? ?? '',
      generatedSummary:  _extractSummary(json),
      generatedBody:     json['generated_body']     as String? ?? '',
      sentiment:         json['sentiment']          as String? ?? '',
      confidence:        (json['confidence'] as num?)?.toDouble() ?? 0.0,
      score:             (json['score']      as num?)?.toDouble() ?? 0.0,
      generatedAt:       json['generated_at']       as String? ?? '',
      owner:             json['owner']              as String? ?? '',
    );
  }

  /// Ekstrak summary dari JSON.
  /// Kalau field `generated_summary` ada → pakai itu.
  /// Kalau tidak ada (data lama) → ambil 2 kalimat pertama dari `generated_body`.
  static String _extractSummary(Map<String, dynamic> json) {
    final fromJson = json['generated_summary'] as String?;
    if (fromJson != null && fromJson.trim().isNotEmpty) {
      return fromJson.trim();
    }

    // Fallback: generate dari body
    final body = json['generated_body'] as String? ?? '';
    if (body.isEmpty) return '';

    final sentences = body
        .replaceAll('\n', ' ')
        .split('.')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final fallback = sentences.take(2).join('. ').trim();
    if (fallback.isEmpty) return '';
    final result = fallback.endsWith('.') ? fallback : '$fallback.';
    return result.length > 200 ? '${result.substring(0, 197)}...' : result;
  }

  Map<String, dynamic> toJson() => {
    'original_title':     originalTitle,
    'original_link':      originalLink,
    'original_source':    originalSource,
    'original_domain':    originalDomain,
    'original_published': originalPublished,
    'generated_title':    generatedTitle,
    'generated_summary':  generatedSummary,
    'Image':              imageUrl,
    'generated_body':     generatedBody,
    'sentiment':          sentiment,
    'confidence':         confidence,
    'score':              score,
    'generated_at':       generatedAt,
    'owner':              owner,
  };
}

class GenerateNewsResponse {
  final bool success;
  final int total;
  final String generatedAt;
  final String owner;
  final List<GeneratedNewsArticle> articles;

  const GenerateNewsResponse({
    required this.success,
    required this.total,
    required this.generatedAt,
    required this.owner,
    required this.articles,
  });

  factory GenerateNewsResponse.fromJson(Map<String, dynamic> json) {
    final rawArticles = json['articles'] as List<dynamic>? ?? [];
    return GenerateNewsResponse(
      success:     json['success']      as bool?   ?? false,
      total:       json['total']        as int?    ?? 0,
      generatedAt: json['generated_at'] as String? ?? '',
      owner:       json['owner']        as String? ?? '',
      articles:    rawArticles
          .map((e) => GeneratedNewsArticle.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AiNewsStatusResponse {
  final String status;
  final String service;
  final String timestamp;
  final bool apiKeyAi;
  final bool apiKeyNews;

  const AiNewsStatusResponse({
    required this.status,
    required this.service,
    required this.timestamp,
    required this.apiKeyAi,
    required this.apiKeyNews,
  });

  bool get isReady => status == 'ready';

  factory AiNewsStatusResponse.fromJson(Map<String, dynamic> json) {
    return AiNewsStatusResponse(
      status:     json['status']       as String? ?? '',
      service:    json['service']      as String? ?? '',
      timestamp:  json['timestamp']    as String? ?? '',
      apiKeyAi:   json['api_key_ai']   as bool?   ?? false,
      apiKeyNews: json['api_key_news'] as bool?   ?? false,
    );
  }
}

class BackgroundAcceptedResponse {
  final bool accepted;
  final String message;
  final int maxNews;
  final List<String> categories;
  final String language;
  final String acceptedAt;

  const BackgroundAcceptedResponse({
    required this.accepted,
    required this.message,
    required this.maxNews,
    required this.categories,
    required this.language,
    required this.acceptedAt,
  });

  factory BackgroundAcceptedResponse.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categories'] as List<dynamic>? ?? [];
    return BackgroundAcceptedResponse(
      accepted:   json['accepted']    as bool?   ?? false,
      message:    json['message']     as String? ?? '',
      maxNews:    json['max_news']    as int?    ?? 3,
      categories: rawCats.map((e) => e.toString()).toList(),
      language:   json['language']    as String? ?? 'en',
      acceptedAt: json['accepted_at'] as String? ?? '',
    );
  }
}

class GenerateNewsRequest {
  final int maxNews;
  final List<String> categories;
  final String language;
  final bool exportJson;
  final bool exportTxt;

  const GenerateNewsRequest({
    this.maxNews    = 3,
    this.categories = const ['economy', 'technology', 'geopolitics'],
    this.language   = 'en',
    this.exportJson = true,
    this.exportTxt  = false,
  });

  Map<String, dynamic> toJson() => {
    'max_news':    maxNews,
    'categories':  categories,
    'language':    language,
    'export_json': exportJson,
    'export_txt':  exportTxt,
  };
}

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

class AiNewsException implements Exception {
  final int statusCode;
  final String message;

  const AiNewsException({required this.statusCode, required this.message});

  @override
  String toString() => 'AiNewsException($statusCode): $message';
}

// ---------------------------------------------------------------------------
// Internal HTTP helpers
// ---------------------------------------------------------------------------

/// Headers tanpa auth — untuk endpoint publik (status)
Map<String, String> get _publicHeaders => {
  'Content-Type': 'application/json',
  'Accept':       'application/json',
};

/// Headers dengan Bearer token — untuk endpoint yang butuh auth
Future<Map<String, String>> _authHeaders() async {
  final token = await AuthStorage.getToken();
  return {
    'Content-Type':  'application/json',
    'Accept':        'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}

void _assertOk(http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    String detail = response.body;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      detail = decoded['detail']?.toString() ?? detail;
    } catch (_) {}
    throw AiNewsException(statusCode: response.statusCode, message: detail);
  }
}

/// Coba refresh token kalau response 401, lalu ulangi request.
/// [retry] adalah callback yang dipanggil setelah refresh berhasil.
Future<http.Response> _withRefresh(
  http.Response response,
  Future<http.Response> Function() retry,
) async {
  if (response.statusCode != 401) return response;
  final refreshed = await AuthStorage.refreshAccessToken();
  if (!refreshed) {
    throw const AiNewsException(
      statusCode: 401,
      message: 'Session expired. Silakan login ulang.',
    );
  }
  return retry();
}

// ---------------------------------------------------------------------------
// Hooks
// ---------------------------------------------------------------------------

/// Status endpoint — tidak butuh auth
class AiNewsStatusHook extends ChangeNotifier {
  AiNewsStatusResponse? data;
  bool isLoading = false;
  AiNewsException? error;

  Future<void> fetch() async {
    isLoading = true; error = null; notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('$_kBaseUrl/ai/news/status'),
        headers: _publicHeaders,
      );
      _assertOk(response);
      data = AiNewsStatusResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on AiNewsException catch (e) {
      error = e;
    } catch (e) {
      error = AiNewsException(statusCode: 0, message: e.toString());
    } finally {
      isLoading = false; notifyListeners();
    }
  }

  void reset() { data = null; error = null; isLoading = false; notifyListeners(); }
}

/// Generate default — butuh auth
class AiNewsGenerateHook extends ChangeNotifier {
  GenerateNewsResponse? data;
  bool isLoading = false;
  AiNewsException? error;

  Future<void> generate([GenerateNewsRequest request = const GenerateNewsRequest()]) async {
    isLoading = true; error = null; notifyListeners();
    try {
      final uri  = Uri.parse('$_kBaseUrl/ai/news/generate');
      final body = jsonEncode(request.toJson());

      var response = await http.post(
        uri,
        headers: await _authHeaders(),
        body:    body,
      );

      // Auto-refresh 401
      response = await _withRefresh(response, () async => http.post(
        uri,
        headers: await _authHeaders(),
        body:    body,
      ));

      _assertOk(response);
      data = GenerateNewsResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on AiNewsException catch (e) {
      error = e;
    } catch (e) {
      error = AiNewsException(statusCode: 0, message: e.toString());
    } finally {
      isLoading = false; notifyListeners();
    }
  }

  void reset() { data = null; error = null; isLoading = false; notifyListeners(); }
}

/// Generate custom — butuh auth
class AiNewsGenerateCustomHook extends ChangeNotifier {
  GenerateNewsResponse? data;
  bool isLoading = false;
  AiNewsException? error;

  Future<void> generate(GenerateNewsRequest request) async {
    isLoading = true; error = null; notifyListeners();
    try {
      final uri  = Uri.parse('$_kBaseUrl/ai/news/generate/custom');
      final body = jsonEncode(request.toJson());

      var response = await http.post(
        uri,
        headers: await _authHeaders(),
        body:    body,
      );

      // Auto-refresh 401
      response = await _withRefresh(response, () async => http.post(
        uri,
        headers: await _authHeaders(),
        body:    body,
      ));

      _assertOk(response);
      data = GenerateNewsResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on AiNewsException catch (e) {
      error = e;
    } catch (e) {
      error = AiNewsException(statusCode: 0, message: e.toString());
    } finally {
      isLoading = false; notifyListeners();
    }
  }

  void reset() { data = null; error = null; isLoading = false; notifyListeners(); }
}

/// Generate background — butuh auth
class AiNewsGenerateBackgroundHook extends ChangeNotifier {
  BackgroundAcceptedResponse? data;
  bool isLoading = false;
  AiNewsException? error;

  Future<void> trigger({
    int    maxNews    = 3,
    String categories = 'economy,technology,geopolitics',
    String language   = 'en',
  }) async {
    isLoading = true; error = null; notifyListeners();
    try {
      final uri = Uri.parse('$_kBaseUrl/ai/news/generate/background').replace(
        queryParameters: {
          'max_news':   maxNews.toString(),
          'categories': categories,
          'language':   language,
        },
      );

      var response = await http.post(uri, headers: await _authHeaders());

      // Auto-refresh 401
      response = await _withRefresh(response, () async =>
        http.post(uri, headers: await _authHeaders()),
      );

      // 202 Accepted adalah sukses untuk background job
      if (response.statusCode != 202) _assertOk(response);

      data = BackgroundAcceptedResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on AiNewsException catch (e) {
      error = e;
    } catch (e) {
      error = AiNewsException(statusCode: 0, message: e.toString());
    } finally {
      isLoading = false; notifyListeners();
    }
  }

  void reset() { data = null; error = null; isLoading = false; notifyListeners(); }
}