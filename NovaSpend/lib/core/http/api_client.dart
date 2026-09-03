import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/exceptions.dart';

typedef IdTokenFetcher = Future<String?> Function();

/// Thin JSON HTTP client for the NovaSpend FastAPI backend.
///
/// Pass-through Firebase ID tokens as `Authorization: Bearer …` (Phase E).
class ApiClient {
  ApiClient({
    http.Client? client,
    this.baseUrl = AppConstants.apiBaseUrl,
    IdTokenFetcher? idTokenFetcher,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _idTokenFetcher = idTokenFetcher ?? _defaultIdToken;

  static const Duration _timeout = Duration(seconds: 30);

  /// Gemini parse can take longer than a typical CRUD call.
  static const Duration parseTimeout = Duration(seconds: 45);

  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final IdTokenFetcher _idTokenFetcher;

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool requireAuth = false,
  }) {
    return _send('GET', path, query: query, requireAuth: requireAuth);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
    Duration? timeout,
  }) {
    return _send(
      'POST',
      path,
      body: body,
      requireAuth: requireAuth,
      timeout: timeout,
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
  }) {
    return _send('PATCH', path, body: body, requireAuth: requireAuth);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
  }) {
    return _send('PUT', path, body: body, requireAuth: requireAuth);
  }

  Future<void> delete(String path, {bool requireAuth = false}) async {
    await _send('DELETE', path, requireAuth: requireAuth, expectEmpty: true);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool requireAuth = false,
    bool expectEmpty = false,
    Duration? timeout,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    if (requireAuth) {
      String? idToken;
      try {
        idToken = await _idTokenFetcher();
      } on FirebaseAuthException catch (_) {
        throw ApiException(
          statusCode: 401,
          message: 'Authentication required.',
          code: 'unauthenticated',
        );
      }
      if (idToken == null || idToken.isEmpty) {
        throw ApiException(
          statusCode: 401,
          message: 'Authentication required.',
          code: 'unauthenticated',
        );
      }
      headers['Authorization'] = 'Bearer $idToken';
    }

    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    _logRequest(method, uri, headers, encoded);

    final stopwatch = Stopwatch()..start();
    final wait = timeout ?? _timeout;
    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(wait);
        case 'POST':
          response = await _client
              .post(uri, headers: headers, body: encoded)
              .timeout(wait);
        case 'PATCH':
          response = await _client
              .patch(uri, headers: headers, body: encoded)
              .timeout(wait);
        case 'PUT':
          response = await _client
              .put(uri, headers: headers, body: encoded)
              .timeout(wait);
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(wait);
        default:
          throw ArgumentError('Unsupported method: $method');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Network error. Please try again.',
        code: 'network_error',
      );
    }
    stopwatch.stop();
    _logResponse(method, path, response, stopwatch.elapsedMilliseconds);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (expectEmpty || response.statusCode == 204 || response.body.isEmpty) {
        return <String, dynamic>{};
      }
      return _tryDecode(response.body);
    }

    final decoded = _tryDecode(response.body);
    throw ApiException(
      statusCode: response.statusCode,
      message:
          decoded['detail']?.toString() ??
          'Request failed (${response.statusCode})',
      code: decoded['code']?.toString(),
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
      return <String, dynamic>{'detail': body};
    }
  }

  void _logRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    if (!kDebugMode) return;
    debugPrint(
      '[API] → $method $uri\n'
      '  headers: $headers\n'
      '  body: ${body ?? ''}',
    );
  }

  void _logResponse(
    String method,
    String path,
    http.Response response,
    int elapsedMs,
  ) {
    if (!kDebugMode) return;
    debugPrint(
      '[API] ← $method $path ${response.statusCode} (${elapsedMs}ms)\n'
      '  body: ${response.body}',
    );
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  static const _deadSessionCodes = {
    'user-token-expired',
    'invalid-user-token',
    'user-disabled',
    'user-not-found',
  };

  static Future<void>? _signingOut;

  static Future<String?> _defaultIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken();
    } on FirebaseAuthException catch (e) {
      if (_deadSessionCodes.contains(e.code)) {
        await _signOutDeadSession();
        return null;
      }
      rethrow;
    }
  }

  static Future<void> _signOutDeadSession() {
    final inFlight = _signingOut;
    if (inFlight != null) return inFlight;

    final future = () async {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {
        // Best-effort: AuthGate still needs a null user if sign-out fails.
      }
    }();
    _signingOut = future;
    return future.whenComplete(() {
      if (identical(_signingOut, future)) {
        _signingOut = null;
      }
    });
  }
}

class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.rawBody,
  });

  final int statusCode;
  final String message;
  final String? code;
  final String? rawBody;

  bool get isEmailExists =>
      code == 'email_exists' ||
      message.toLowerCase().contains('already in use');

  bool get isNetwork => code == 'network_error' || statusCode == 0;

  Exception toDataException() {
    if (isNetwork) return NetworkException(message);
    if (statusCode == 401 || statusCode == 403) return AuthException(message);
    return ServerException(message);
  }

  @override
  String toString() =>
      'ApiException($statusCode${code != null ? ', $code' : ''}): $message';
}
