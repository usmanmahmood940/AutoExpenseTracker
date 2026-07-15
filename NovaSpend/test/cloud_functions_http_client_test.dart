import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nova_spend/core/http/cloud_functions_http_client.dart';

void main() {
  test('posts callable data envelope and returns result map', () async {
    late http.Request captured;
    final client = CloudFunctionsHttpClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'result': {'ok': true, 'resetToken': 'abc'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      projectId: 'demo-project',
      region: 'asia-south1',
      appCheckTokenFetcher: () async => null,
      idTokenFetcher: () async => null,
    );

    final result = await client.call(
      'verifyPasswordResetOtp',
      data: {'email': 'a@b.com', 'code': '123456'},
    );

    expect(
      captured.url.toString(),
      'https://asia-south1-demo-project.cloudfunctions.net/verifyPasswordResetOtp',
    );
    expect(captured.headers['Content-Type'], contains('application/json'));
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['data']['email'], 'a@b.com');
    expect(result['resetToken'], 'abc');
    client.dispose();
  });

  test('throws CloudFunctionsHttpException with message from error body',
      () async {
    final client = CloudFunctionsHttpClient(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Too many requests. Please try again later.'},
          }),
          429,
          headers: {'content-type': 'application/json'},
        );
      }),
      projectId: 'demo-project',
      region: 'asia-south1',
      appCheckTokenFetcher: () async => null,
      idTokenFetcher: () async => null,
    );

    expect(
      () => client.call('sendEmailOtp', data: {'email': 'a@b.com'}),
      throwsA(
        isA<CloudFunctionsHttpException>().having(
          (e) => e.message,
          'message',
          contains('Too many requests'),
        ),
      ),
    );
    client.dispose();
  });

  test('attaches App Check and auth headers when provided', () async {
    late http.Request captured;
    final client = CloudFunctionsHttpClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'result': {}}), 200);
      }),
      projectId: 'demo-project',
      region: 'asia-south1',
      appCheckTokenFetcher: () async => 'app-check-token',
      idTokenFetcher: () async => 'id-token',
    );

    await client.call('ensureUserProfile', requireAuth: true);
    expect(captured.headers['X-Firebase-AppCheck'], 'app-check-token');
    expect(captured.headers['Authorization'], 'Bearer id-token');
    client.dispose();
  });
}
