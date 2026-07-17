/**
 * One-time backfill: set merchantNormalized (+ default isRecurring) on existing transactions.
 *
 * Usage (from functions/):
 *   npm run build && node scripts/backfill-merchant-normalized.mjs
 *
 * Optional:
 *   DRY_RUN=1 node scripts/backfill-merchant-normalized.mjs
 *   USER_ID=<uid> node scripts/backfill-merchant-normalized.mjs   # single user only
 *
 * Requires Application Default Credentials for project auto-expense-tracker-2026.
 */
import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const { COLLECTIONS, normalizeMerchant } = require('../lib/schema.js');

if (getApps().length === 0) {
  initializeApp({ projectId: 'auto-expense-tracker-2026' });
}

const db = getFirestore();
const DRY_RUN = process.env.DRY_RUN === '1' || process.env.DRY_RUN === 'true';
const ONLY_UID = process.env.USER_ID?.trim() || null;

async function backfillCollection(ref, label) {
  let updated = 0;
  let scanned = 0;
  let lastDoc = null;

  for (;;) {
    let query = ref.orderBy('__name__').limit(200);
    if (lastDoc) query = query.startAfter(lastDoc);
    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    let batchOps = 0;

    for (const doc of snap.docs) {
      scanned++;
      const data = doc.data() || {};
      const merchant = typeof data.merchant === 'string' ? data.merchant : '';
      const key = normalizeMerchant(merchant);
      const needsNormalized =
        !data.merchantNormalized || data.merchantNormalized !== key;
      const needsRecurring = typeof data.isRecurring !== 'boolean';

      if (!needsNormalized && !needsRecurring) continue;

      const patch = {
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (needsNormalized) patch.merchantNormalized = key;
      if (needsRecurring) patch.isRecurring = false;

      if (!DRY_RUN) {
        batch.update(doc.ref, patch);
        batchOps++;
      }
      updated++;
    }

    if (!DRY_RUN && batchOps > 0) {
      await batch.commit();
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < 200) break;
  }

  console.log(`  ${label}: scanned=${scanned} updated=${updated}`);
  return { scanned, updated };
}

async function main() {
  console.log(
    `Backfill merchantNormalized (dryRun=${DRY_RUN}${ONLY_UID ? `, uid=${ONLY_UID}` : ''})`,
  );

  let totalUpdated = 0;

  // Legacy top-level transactions
  if (!ONLY_UID) {
    const legacy = await backfillCollection(
      db.collection(COLLECTIONS.transactions),
      'transactions (legacy)',
    );
    totalUpdated += legacy.updated;
  }

  // Per-user nested transactions
  if (ONLY_UID) {
    const ref = db
      .collection(COLLECTIONS.users)
      .doc(ONLY_UID)
      .collection(COLLECTIONS.transactions);
    const result = await backfillCollection(ref, `users/${ONLY_UID}/transactions`);
    totalUpdated += result.updated;
  } else {
    const usersSnap = await db.collection(COLLECTIONS.users).get();
    for (const userDoc of usersSnap.docs) {
      const ref = userDoc.ref.collection(COLLECTIONS.transactions);
      const result = await backfillCollection(
        ref,
        `users/${userDoc.id}/transactions`,
      );
      totalUpdated += result.updated;
    }
  }

  console.log(`Done. totalUpdated=${totalUpdated}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
