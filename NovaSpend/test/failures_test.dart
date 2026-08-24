import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/errors/failures.dart';

void main() {
  test('throwAsFailure maps network exceptions', () {
    expect(
      () => throwAsFailure(const NetworkException('offline')),
      throwsA(
        isA<NetworkFailure>().having((e) => e.message, 'message', 'offline'),
      ),
    );
  });

  test('throwAsFailure maps server exceptions', () {
    expect(
      () => throwAsFailure(const ServerException('boom')),
      throwsA(isA<ServerFailure>().having((e) => e.message, 'message', 'boom')),
    );
  });

  test('Failure.toString exposes the message', () {
    expect(const ServerFailure('hidden').toString(), 'hidden');
  });
}
