import 'package:nova_spend/core/http/api_client.dart';

/// FastAPI `/auth/*` and `/me` calls for Phase E.
class BackendAuthDatasource {
  BackendAuthDatasource({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<void> sendSignupOtp({required String email}) async {
    await _api.post('/auth/signup/otp', body: {'email': email.trim()});
  }

  Future<Map<String, dynamic>> completeSignup({
    required String email,
    required String password,
    required String code,
  }) {
    return _api.post(
      '/auth/signup',
      body: {
        'email': email.trim(),
        'password': password,
        'code': code.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _api.post(
      '/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
      },
    );
  }

  Future<void> forgotPassword({required String email}) async {
    await _api.post(
      '/auth/forgot-password',
      body: {'email': email.trim()},
    );
  }

  Future<String> verifyResetOtp({
    required String email,
    required String code,
  }) async {
    final result = await _api.post(
      '/auth/verify-reset-otp',
      body: {
        'email': email.trim(),
        'code': code.trim(),
      },
    );
    final token = result['reset_token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException(
        statusCode: 500,
        message: 'Missing reset token',
        code: 'reset_token_missing',
      );
    }
    return token;
  }

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/reset-password',
      body: {
        'reset_token': resetToken,
        'new_password': newPassword,
      },
    );
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/change-password',
      body: {
        'old_password': oldPassword,
        'new_password': newPassword,
      },
      requireAuth: true,
    );
  }

  Future<void> logout() async {
    await _api.post('/auth/logout', requireAuth: true);
  }

  /// Ensures a Postgres profile exists (self-heal) and returns it.
  Future<Map<String, dynamic>> getMe() {
    return _api.get('/me', requireAuth: true);
  }

  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
    String? appVersion,
  }) async {
    final body = <String, dynamic>{
      'fcm_token': fcmToken,
      'platform': platform,
    };
    if (appVersion != null && appVersion.isNotEmpty) {
      body['app_version'] = appVersion;
    }
    await _api.post('/me/devices', body: body, requireAuth: true);
  }

  Future<void> unregisterDevice({required String fcmToken}) async {
    await _api.delete(
      '/me/devices/${Uri.encodeComponent(fcmToken)}',
      requireAuth: true,
    );
  }
}
