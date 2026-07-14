/**
 * Seed default categories into Firestore `categories/{id}`.
 * Usage (from functions/): node scripts/seed-categories.mjs
 *
 * Requires Application Default Credentials for project auto-expense-tracker-2026
 * (e.g. `firebase login` + `gcloud auth application-default login`).
 */
import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const { DEFAULT_CATEGORIES, COLLECTIONS } = require('../lib/schema.js');

if (getApps().length === 0) {
  initializeApp({ projectId: 'auto-expense-tracker-2026' });
}

const db = getFirestore();

async function main() {
  const batch = db.batch();
  const now = FieldValue.serverTimestamp();

  for (const category of DEFAULT_CATEGORIES) {
    const { id, ...fields } = category;
    const ref = db.collection(COLLECTIONS.categories).doc(id);
    batch.set(
      ref,
      {
        ...fields,
        createdAt: now,
        updatedAt: now,
      },
      { merge: true },
    );
  }

  await batch.commit();
  console.log(
    `Seeded ${DEFAULT_CATEGORIES.length} categories into ${COLLECTIONS.categories}/`,
  );
  for (const c of DEFAULT_CATEGORIES) {
    console.log(`  ${c.id}: ${c.name} (${c.type})`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
