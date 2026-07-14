/// Data-layer exceptions mapped to [Failure] in repositories.
class ServerException implements Exception {
  const ServerException([this.message = 'Server error']);

  final String message;
}

class CacheException implements Exception {
  const CacheException([this.message = 'Cache error']);

  final String message;
}

class NetworkException implements Exception {
  const NetworkException([this.message = 'Network error']);

  final String message;
}

class AuthException implements Exception {
  const AuthException([this.message = 'Authentication error']);

  final String message;
}
