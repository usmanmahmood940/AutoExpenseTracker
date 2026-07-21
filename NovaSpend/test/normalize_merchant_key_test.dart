import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/constants/app_constants.dart';

/// Shared with functions/src/schema.test.ts — both implementations must
/// agree, since normalizeMerchantKey drives merchant grouping, category
/// overrides, and search prefix queries across the backend and this client.
File _findFixtureFile() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = File(
      '${dir.path}/shared/test-fixtures/normalize-merchant-key-cases.json',
    );
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw FileSystemException(
    'Could not locate shared/test-fixtures/normalize-merchant-key-cases.json '
    'above ${Directory.current.path}',
  );
}

void main() {
  test('normalizeMerchantKey matches shared cross-language fixture', () {
    final fixture = jsonDecode(_findFixtureFile().readAsStringSync())
        as Map<String, dynamic>;
    final cases = fixture['cases'] as List<dynamic>;
    expect(cases, isNotEmpty);

    for (final rawCase in cases) {
      final map = rawCase as Map<String, dynamic>;
      final input = map['input'] as String;
      final expected = map['expected'] as String;
      expect(
        normalizeMerchantKey(input),
        expected,
        reason: 'normalizeMerchantKey(${jsonEncode(input)}) '
            'should equal ${jsonEncode(expected)}',
      );
    }
  });
}
