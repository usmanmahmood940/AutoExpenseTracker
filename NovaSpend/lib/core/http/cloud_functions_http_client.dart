import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nova_spend/core/constants/app_constants.dart';

typedef AppCheckTokenFetcher = Future<String?> Function();
typedef IdTokenFetcher = Future<String?> Function();

/// Thin HTTP client for Firebase callable Cloud Functions (v2 protocol).
class CloudFunctionsHttpClient {
  CloudFunctionsHttpClient({
    http.Client? client,
    this.projectId = AppConstants.projectId,
    this.region = AppConstants.region,
    AppCheckTokenFetcher? appCheckTokenFetcher,
    IdTokenFetcher? idTokenFetcher,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _appCheckTokenFetcher = appCheckTokenFetcher ?? _defaultAppCheckToken,
        _idTokenFetcher = idTokenFetcher ?? _defaultIdToken;

  static const int _maxLoggedBodyChars = 4000;

  final http.Client _client;
  final bool _ownsClient;
  final String projectId;
  final String region;
  final AppCheckTokenFetcher _appCheckTokenFetcher;
  final IdTokenFetcher _idTokenFetcher;

  Uri _uri(String functionName) => Uri.parse(
        'https://$region-$projectId.cloudfunctions.net/$functionName',
      );

  Future<Map<String, dynamic>> call(
    String functionName, {
    Map<String, dynamic>? data,
    bool requireAuth = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    try {
      final appCheckToken = await _appCheckTokenFetcher();
      if (appCheckToken != null && appCheckToken.isNotEmpty) {
        headers['X-Firebase-AppCheck'] = appCheckToken;
      }
    } catch (_) {
      // App Check may be unavailable in some test/dev environments.
    }

    if (requireAuth) {
      final idToken = await _idTokenFetcher();
      if (idToken == null || idToken.isEmpty) {
        throw CloudFunctionsHttpException(
          statusCode: 401,
          message: 'Authentication required.',
        );
      }
      headers['Authorization'] = 'Bearer $idToken';
    }

    final uri = _uri(functionName);
    final requestBody = jsonEncode({'data': data ?? <String, dynamic>{}});
    _logRequest(functionName, uri, headers, requestBody);

    final stopwatch = Stopwatch()..start();
    final response = await _client.post(
      uri,
      headers: headers,
      body: requestBody,
    );
    stopwatch.stop();
    _logResponse(functionName, response, stopwatch.elapsedMilliseconds);

    final body = _tryDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final result = body['result'];
      if (result is Map<String, dynamic>) {
        return result;
      }
      if (result == null) {
        return <String, dynamic>{};
      }
      return {'value': result};
    }

    final error = body['error'];
    String message = 'Request failed (${response.statusCode})';
    if (error is Map<String, dynamic>) {
      message = error['message']?.toString() ?? message;
    } else if (body['message'] != null) {
      message = body['message'].toString();
    }

    throw CloudFunctionsHttpException(
      statusCode: response.statusCode,
      message: message,
      rawBody: response.body,
    );
  }

  Map<String, dynamic> _tryDecode(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'value': decoded};
    } catch (_) {
      return <String, dynamic>{'message': body};
    }
  }

  void _logRequest(
    String functionName,
    Uri uri,
    Map<String, String> headers,
    String body,
  ) {
    if (!kDebugMode) return;
    debugPrint(
      '[CF] → POST $functionName\n'
      '  url: $uri\n'
      '  headers: ${_redactHeaders(headers)}\n'
      '  body: ${_truncate(body)}',
    );
  }

  void _logResponse(
    String functionName,
    http.Response response,
    int elapsedMs,
  ) {
    if (!kDebugMode) return;
    final summary = _responseSummary(response.body);
    debugPrint(
      '[CF] ← $functionName ${response.statusCode} (${elapsedMs}ms)'
      '${summary.isEmpty ? '' : '\n  $summary'}\n'
      '  body: ${_truncate(response.body)}',
    );
  }

  Map<String, String> _redactHeaders(Map<String, String> headers) {
    return headers.map((key, value) {
      final lower = key.toLowerCase();
      if (lower == 'authorization' || lower == 'x-firebase-appcheck') {
        return MapEntry(key, _redactToken(value));
      }
      return MapEntry(key, value);
    });
  }

  String _redactToken(String value) {
    if (value.startsWith('Bearer ')) {
      final token = value.substring(7);
      return 'Bearer ${_mask(token)}';
    }
    return _mask(value);
  }

  String _mask(String value) {
    if (value.length <= 12) return '***';
    return '${value.substring(0, 6)}…${value.substring(value.length - 4)}'
        ' (${value.length} chars)';
  }

  String _truncate(String value) {
    if (value.length <= _maxLoggedBodyChars) return value;
    return '${value.substring(0, _maxLoggedBodyChars)}… '
        '(truncated, ${value.length} chars total)';
  }

  String _responseSummary(String body) {
    final decoded = _tryDecode(body);
    final result = decoded['result'];
    if (result is! Map) return '';
    final parts = <String>[];
    final items = result['items'];
    if (items is List) parts.add('items=${items.length}');
    if (result['hasMore'] != null) parts.add('hasMore=${result['hasMore']}');
    if (result['nextCursor'] != null) {
      parts.add('nextCursor=${result['nextCursor']}');
    }
    if (result['totalCount'] != null) {
      parts.add('totalCount=${result['totalCount']}');
    }
    return parts.join(', ');
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  static Future<String?> _defaultAppCheckToken() async {
    return FirebaseAppCheck.instance.getToken();
  }

  static Future<String?> _defaultIdToken() async {
    return FirebaseAuth.instance.currentUser?.getIdToken();
  }
}

class CloudFunctionsHttpException implements Exception {
  CloudFunctionsHttpException({
    required this.statusCode,
    required this.message,
    this.rawBody,
  });

  final int statusCode;
  final String message;
  final String? rawBody;

  @override
  String toString() => 'CloudFunctionsHttpException($statusCode): $message';
}
