import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/errors/app_error_mapper.dart';
import 'package:nova_spend/features/auth/presentation/auth_error_mapper.dart';
import 'package:nova_spend/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('AppErrorMapper', () {
    test('returns generic for unknown objects', () {
      expect(AppErrorMapper.message(l10n, Exception('x')), isNotEmpty);
    });

    test('delegates auth message formatting via AuthErrorMapper', () {
      expect(
        AuthErrorMapper.friendlyAuthError(l10n, 'network-request-failed', null),
        l10n.authNetworkError,
      );
    });
  });
}
