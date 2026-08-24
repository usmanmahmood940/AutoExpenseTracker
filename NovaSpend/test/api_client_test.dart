import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/http/api_client.dart';

void main() {
  test('posts JSON and returns body map', () async {
    late http.Request captured;
    final client = ApiClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUrl: 'https://api.example.com',
      idTokenFetcher: () async => null,
    );

    final result = await client.post(
      '/auth/signup/otp',
      body: {'email': 'a@b.com'},
    );

    expect(captured.url.toString(), 'https://api.example.com/auth/signup/otp');
    expect(captured.headers['Content-Type'], contains('application/json'));
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['email'], 'a@b.com');
    expect(result['ok'], true);
    client.dispose();
  });

  test('attaches bearer token when requireAuth is true', () async {
    late http.Request captured;
    final client = ApiClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      }),
      baseUrl: 'https://api.example.com',
      idTokenFetcher: () async => 'test-id-token',
    );

    await client.get('/me', requireAuth: true);

    expect(captured.headers['Authorization'], 'Bearer test-id-token');
    client.dispose();
  });

  test('put sends JSON body', () async {
    late http.Request captured;
    final client = ApiClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'category': 'Fuel'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUrl: 'https://api.example.com',
      idTokenFetcher: () async => 'tok',
    );

    final result = await client.put(
      '/merchants/kfc/category-override',
      body: {'category': 'Fuel'},
      requireAuth: true,
    );

    expect(captured.method, 'PUT');
    expect(result['category'], 'Fuel');
    client.dispose();
  });

  test('throws ApiException with detail and code', () async {
    final client = ApiClient(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': 'This email is already in use.',
            'code': 'email_exists',
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUrl: 'https://api.example.com',
      idTokenFetcher: () async => null,
    );

    try {
      await client.post('/auth/signup/otp', body: {'email': 'a@b.com'});
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.statusCode, 409);
      expect(e.code, 'email_exists');
      expect(e.isEmailExists, isTrue);
      expect(e.message, contains('already in use'));
    }
    client.dispose();
  });

  test('maps transport failures to a network ApiException', () async {
    final client = ApiClient(
      client: MockClient((request) async {
        throw Exception('Connection failed');
      }),
      baseUrl: 'https://api.example.com',
      idTokenFetcher: () async => null,
    );

    try {
      await client.get('/me');
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.isNetwork, isTrue);
      expect(e.code, 'network_error');
      expect(e.toDataException(), isA<NetworkException>());
    }
    client.dispose();
  });
}
