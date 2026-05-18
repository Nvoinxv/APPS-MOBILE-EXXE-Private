// news_ai_hook.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/auth_storage.dart';

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
  final String generatedSummary;
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

  static String _extractSummary(Map<String, dynamic> json) {
    final fromJson = json['generated_summary'] as String?;
    if (fromJson != null && fromJson.trim().isNotEmpty) return fromJson.trim();

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

// Satu deklarasi — sudah include schedulerActive & nextRun
class AiNewsStatusResponse {
  final String status;
  final String service;
  final String timestamp;
  final bool apiKeyAi;
  final bool apiKeyNews;
  final bool schedulerActive;
  final String? nextRun;

  const AiNewsStatusResponse({
    required this.status,
    required this.service,
    required this.timestamp,
    required this.apiKeyAi,
    required this.apiKeyNews,
    required this.schedulerActive,
    this.nextRun,
  });

  bool get isReady => status == 'ready';

  factory AiNewsStatusResponse.fromJson(Map<String, dynamic> json) {
    return AiNewsStatusResponse(
      status:          json['status']           as String? ?? '',
      service:         json['service']          as String? ?? '',
      timestamp:       json['timestamp']        as String? ?? '',
      apiKeyAi:        json['api_key_ai']        as bool?   ?? false,
      apiKeyNews:      json['api_key_news']      as bool?   ?? false,
      schedulerActive: json['scheduler_active'] as bool?   ?? false,
      nextRun:         json['next_run']          as String?,
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
// Internal helpers
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Hooks
// ---------------------------------------------------------------------------

class AiNewsStatusHook extends ChangeNotifier {
  AiNewsStatusResponse? data;
  bool isLoading = false;
  AiNewsException? error;

  Future<void> fetch() async {
    isLoading = true; error = null; notifyListeners();
    try {
      final response = await AuthStorage.get('/ai/news/status');
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

class AiNewsGenerateHook extends ChangeNotifier {
  GenerateNewsResponse? data;
  bool isLoading = false;
  AiNewsException? error;

  Future<void> generate([GenerateNewsRequest request = const GenerateNewsRequest()]) async {
    isLoading = true; error = null; notifyListeners();
    try {
      final response = await AuthStorage.post(
        '/ai/news/generate',
        body: request.toJson(),
      );
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

class AiNewsGenerateCustomHook extends ChangeNotifier {
  GenerateNewsResponse? data;
  bool isLoading = false;
  AiNewsException? error;

  Future<void> generate(GenerateNewsRequest request) async {
    isLoading = true; error = null; notifyListeners();
    try {
      final response = await AuthStorage.post(
        '/ai/news/generate/custom',
        body: request.toJson(),
      );
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
      final uri = Uri.parse('${AuthStorage.activeBaseUrl}/ai/news/generate/background').replace(
        queryParameters: {
          'max_news':   maxNews.toString(),
          'categories': categories,
          'language':   language,
        },
      );
      final token = await AuthStorage.getToken();
      var response = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (!refreshed) throw const AiNewsException(statusCode: 401, message: 'Session expired. Silakan login ulang.');
        final newToken = await AuthStorage.getToken();
        response = await http.post(uri, headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          if (newToken != null && newToken.isNotEmpty) 'Authorization': 'Bearer $newToken',
        });
      }

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