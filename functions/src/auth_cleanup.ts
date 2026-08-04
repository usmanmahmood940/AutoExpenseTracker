/**
 * Monthly cleanup of expired auth ephemeral docs.
 * Also drains legacy OTP/session collections from before the authTemp consolidation.
 */

import type { Query } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { db } from './admin';
import { COLLECTIONS } from './schema';

const BATCH_SIZE = 400;

/** Legacy collections replaced by authTemp — wipe any leftover docs. */
const LEGACY_AUTH_COLLECTIONS = [
  'emailVerificationOtps',
  'passwordResetOtps',
  'passwordResetSessions',
] as const;

async function deleteQueryInBatches(
  collectionName: string,
  buildQuery: () => Query,
): Promise<number> {
  let deleted = 0;

  for (;;) {
    const snap = await buildQuery().limit(BATCH_SIZE).get();
    if (snap.empty) break;

    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deleted += snap.docs.length;

    if (snap.docs.length < BATCH_SIZE) break;
  }

  if (deleted > 0) {
    logger.info(`cleanupExpiredAuthDocs: deleted ${deleted} from ${collectionName}`);
  }
  return deleted;
}

async function deleteExpiredByExpiresAt(collectionName: string): Promise<number> {
  const now = Date.now();
  return deleteQueryInBatches(collectionName, () =>
    db.collection(collectionName).where('expiresAtMs', '<', now),
  );
}

async function deleteAllDocs(collectionName: string): Promise<number> {
  return deleteQueryInBatches(collectionName, () => db.collection(collectionName));
}

/**
 * Runs at 03:00 Asia/Karachi on the 1st of each month.
 * Removes expired authTemp + authRateLimits docs, and any leftover legacy auth collections.
 */
export const cleanupExpiredAuthDocs = onSchedule(
  {
    schedule: '0 3 1 * *',
    timeZone: 'Asia/Karachi',
  },
  async () => {
    let total = 0;

    total += await deleteExpiredByExpiresAt(COLLECTIONS.authTemp);
    total += await deleteExpiredByExpiresAt(COLLECTIONS.authRateLimits);

    for (const name of LEGACY_AUTH_COLLECTIONS) {
      total += await deleteAllDocs(name);
    }

    logger.info('cleanupExpiredAuthDocs finished', { totalDeleted: total });
  },
);
