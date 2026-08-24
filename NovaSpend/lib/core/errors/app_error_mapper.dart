import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/core/http/api_client.dart';
import 'package:nova_spend/core/http/cloud_functions_http_client.dart';
import 'package:nova_spend/features/auth/presentation/auth_error_mapper.dart';
import 'package:nova_spend/l10n/app_localizations.dart';

/// Routes unexpected errors to localized user-facing messages.
abstract final class AppErrorMapper {
  static String message(AppLocalizations l10n, Object error) {
    if (error is FirebaseAuthException) {
      return AuthErrorMapper.friendlyAuthError(
        l10n,
        error.code,
        error.message,
      );
    }
    if (error is PlatformException) {
      return AuthErrorMapper.friendlyPlatformAuthError(
        l10n,
        error.code,
        error.message,
      );
    }
    if (isNetwork(error)) return l10n.errorNetwork;
    if (error is Failure ||
        error is ApiException ||
        error is CloudFunctionsHttpException ||
        error is ServerException ||
        error is AuthException ||
        error is CacheException) {
      return l10n.errorLoadFailed;
    }
    return l10n.errorGeneric;
  }

  static bool isNetwork(Object? error) {
    if (error == null) return false;
    if (error is NetworkFailure || error is NetworkException) return true;
    if (error is ApiException) return error.isNetwork;
    if (error is CloudFunctionsHttpException) return error.isNetwork;
    final text = error.toString().toLowerCase();
    return text.contains('network error') ||
        text.contains('network_error') ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('no internet');
  }
}
