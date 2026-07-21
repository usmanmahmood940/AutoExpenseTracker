#!/usr/bin/env node
/**
 * Keeps `shared/types/schema.ts` (a mirror for future client apps) in sync
 * with `functions/src/schema.ts` (the actual deployed source of truth).
 *
 * Cloud Functions deploys only the contents of `functions/`, so the
 * Cloud Functions build cannot simply `import` from `shared/` — instead
 * this script copies the source of truth over, prefixed with a generated
 * banner, so the two files can never silently drift.
 *
 * Usage:
 *   node scripts/sync-shared-schema.mjs         # regenerate shared/types/schema.ts
 *   node scripts/sync-shared-schema.mjs --check # exit 1 if shared copy is stale (CI)
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const rootDir = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const sourcePath = path.join(rootDir, 'functions', 'src', 'schema.ts');
const targetPath = path.join(rootDir, 'shared', 'types', 'schema.ts');

const BANNER = `/**
 * GENERATED FILE — DO NOT EDIT DIRECTLY.
 *
 * Mirrors \`functions/src/schema.ts\` (the deployed source of truth) for
 * future client apps that cannot import across the Cloud Functions
 * deploy boundary. Edit the source file, then run:
 *
 *   node scripts/sync-shared-schema.mjs
 */

`;

function buildTargetContents() {
  const source = readFileSync(sourcePath, 'utf8');
  return BANNER + source;
}

function main() {
  const check = process.argv.includes('--check');
  const generated = buildTargetContents();

  if (!check) {
    writeFileSync(targetPath, generated);
    console.log(`Wrote ${path.relative(rootDir, targetPath)}`);
    return;
  }

  if (!existsSync(targetPath)) {
    console.error(`${path.relative(rootDir, targetPath)} does not exist. Run without --check to generate it.`);
    process.exit(1);
  }

  const existing = readFileSync(targetPath, 'utf8');
  if (existing !== generated) {
    console.error(
      `${path.relative(rootDir, targetPath)} is out of date with ${path.relative(rootDir, sourcePath)}.\n` +
        'Run `node scripts/sync-shared-schema.mjs` and commit the result.',
    );
    process.exit(1);
  }

  console.log('shared/types/schema.ts is up to date.');
}

main();
