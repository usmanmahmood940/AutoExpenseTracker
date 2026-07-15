/**
 * Shared user profile upsert used by ingest and auth flows.
 */

import { FieldValue } from 'firebase-admin/firestore';

import { auth, db } from './admin';
import { COLLECTIONS, type User } from './schema';

export async function ensureUserDocument(
  uid: string,
  options?: { displayName?: string | null; email?: string | null },
): Promise<void> {
  const userRef = db.collection(COLLECTIONS.users).doc(uid);
  const existing = await userRef.get();
  if (existing.exists) {
    const updates: Record<string, unknown> = {
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (options?.displayName && !existing.get('displayName')) {
      updates.displayName = options.displayName;
    }
    await userRef.update(updates);
    return;
  }

  let displayName = options?.displayName?.trim() ?? '';
  if (!displayName && options?.email) {
    displayName = options.email.split('@')[0] ?? '';
  }

  const now = FieldValue.serverTimestamp();
  const user: Omit<User, 'createdAt' | 'updatedAt'> & {
    createdAt: FieldValue;
    updatedAt: FieldValue;
  } = {
    displayName,
    defaultCurrency: 'PKR',
    timezone: 'Asia/Karachi',
    bankSenders: [],
    emailFilters: [],
    settings: { autoCategorize: true },
    createdAt: now,
    updatedAt: now,
  };

  await userRef.set(user);
}

/** Resolve Auth user and upsert profile; used by ensureUserProfile callable. */
export async function ensureUserProfileForUid(uid: string): Promise<void> {
  const userRecord = await auth.getUser(uid);
  await ensureUserDocument(uid, {
    displayName: userRecord.displayName,
    email: userRecord.email,
  });
}
