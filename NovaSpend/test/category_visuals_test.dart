import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/utils/category_visuals.dart';

File _findFixtureFile() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = File(
      '${dir.path}/shared/test-fixtures/category-colors.json',
    );
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw FileSystemException(
    'Could not locate shared/test-fixtures/category-colors.json '
    'above ${Directory.current.path}',
  );
}

void main() {
  late Map<String, String> fixtureColors;

  setUpAll(() {
    final fixture =
        jsonDecode(_findFixtureFile().readAsStringSync())
            as Map<String, dynamic>;
    fixtureColors = (fixture['colors'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );
  });

  test('psychology palette matches shared Firestore color fixture', () {
    expect(kCategoryColorHexById.keys.toSet(), fixtureColors.keys.toSet());
    for (final entry in fixtureColors.entries) {
      expect(
        kCategoryColorHexById[entry.key],
        entry.value,
        reason: '${entry.key} should use ${entry.value}',
      );
    }
  });

  test('resolves display names to the same hex as category ids', () {
    expect(categoryColorHex('Food & Dining'), fixtureColors['food_dining']);
    expect(categoryColorHex('food_dining'), fixtureColors['food_dining']);
    expect(categoryColorHex('Groceries'), fixtureColors['groceries']);
    expect(categoryColorHex('Healthcare'), fixtureColors['healthcare']);
    expect(categoryColorHex('Unknown'), fixtureColors['uncategorized']);
  });

  test('prefers a valid Firestore hex over the local palette', () {
    expect(categoryColorHex('Food & Dining', storedHex: '#112233'), '#112233');
  });

  test('icon background uses the category hue at 0.2 alpha', () {
    final glyph = categoryColor('Fuel');
    final fill = categoryIconBackground('Fuel');
    expect(fill.r, glyph.r);
    expect(fill.g, glyph.g);
    expect(fill.b, glyph.b);
    expect(fill.a, closeTo(kCategoryIconBackgroundAlpha, 0.001));
  });
}
