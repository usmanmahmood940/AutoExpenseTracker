import { readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { DEFAULT_CATEGORIES, normalizeMerchantKey } from './schema';

interface MerchantKeyCase {
  input: string;
  expected: string;
}

interface MerchantKeyFixture {
  cases: MerchantKeyCase[];
}

// Shared with NovaSpend/test/normalize_merchant_key_test.dart — both
// implementations must agree, since normalizeMerchantKey drives merchant
// grouping, category overrides, and search prefix queries across the
// backend and the Flutter client.
const fixturePath = path.join(
  __dirname,
  '..',
  '..',
  'shared',
  'test-fixtures',
  'normalize-merchant-key-cases.json',
);

function loadCases(): MerchantKeyCase[] {
  const raw = readFileSync(fixturePath, 'utf8');
  const fixture = JSON.parse(raw) as MerchantKeyFixture;
  return fixture.cases;
}

test('normalizeMerchantKey matches shared cross-language fixture', () => {
  const cases = loadCases();
  assert.ok(cases.length > 0, 'fixture should not be empty');

  for (const { input, expected } of cases) {
    assert.equal(
      normalizeMerchantKey(input),
      expected,
      `normalizeMerchantKey(${JSON.stringify(input)}) should equal ${JSON.stringify(expected)}`,
    );
  }
});

const hexColor = /^#[0-9A-F]{6}$/;

test('DEFAULT_CATEGORIES colors match shared psychology fixture', () => {
  const fixturePath = path.join(
    __dirname,
    '..',
    '..',
    'shared',
    'test-fixtures',
    'category-colors.json',
  );
  const fixture = JSON.parse(readFileSync(fixturePath, 'utf8')) as {
    colors: Record<string, string>;
  };

  const seen = new Set<string>();
  for (const category of DEFAULT_CATEGORIES) {
    assert.match(
      category.color,
      hexColor,
      `${category.id} color must be #RRGGBB`,
    );
    assert.equal(
      category.color,
      fixture.colors[category.id],
      `${category.id} color should match shared fixture`,
    );
    assert.equal(
      seen.has(category.color),
      false,
      `${category.id} color ${category.color} must be unique`,
    );
    seen.add(category.color);
  }

  assert.equal(
    Object.keys(fixture.colors).length,
    DEFAULT_CATEGORIES.length,
    'fixture should list every default category',
  );
});
