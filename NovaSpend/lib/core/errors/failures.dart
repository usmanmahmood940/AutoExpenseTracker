import 'package:equatable/equatable.dart';
import 'package:nova_spend/core/errors/exceptions.dart';

/// Base class for domain-level failures.
abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => message;
}

/// Maps data-layer exceptions to domain [Failure]s for repositories.
Never throwAsFailure(Object error) {
  if (error is Failure) throw error;
  if (error is NetworkException) throw NetworkFailure(error.message);
  if (error is AuthException) throw AuthFailure(error.message);
  if (error is CacheException) throw CacheFailure(error.message);
  if (error is ServerException) {
    throw ServerFailure(error.message, error.code);
  }
  throw UnknownFailure(error.toString());
}

Stream<T> mapStreamFailures<T>(Stream<T> source) {
  return source.handleError((Object error, StackTrace stackTrace) {
    throwAsFailure(error);
  });
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error', this.code]);

  final String? code;

  @override
  List<Object?> get props => [message, code];
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache error']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication error']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Validation error']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Unknown error']);
}
