import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

    final response = await _client.post(
      _uri(functionName),
      headers: headers,
      body: jsonEncode({'data': data ?? <String, dynamic>{}}),
    );

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
