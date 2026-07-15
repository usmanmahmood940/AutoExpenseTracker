import { FieldValue } from 'firebase-admin/firestore';
import {
  onDocumentWritten,
  type FirestoreEvent,
  type Change,
  type DocumentSnapshot,
} from 'firebase-functions/v2/firestore';

import { db } from './admin';
import { COLLECTIONS, type Transaction } from './schema';

type TxLike = Pick<
  Transaction,
  'amount' | 'type' | 'category' | 'merchant' | 'currency' | 'transactionDate' | 'status'
>;

function yearMonthFromDate(transactionDate: string): string | null {
  const match = /^(\d{4}-\d{2})/.exec(transactionDate);
  return match ? match[1] : null;
}

function isActive(tx: TxLike | undefined | null): boolean {
  return Boolean(tx && tx.status !== 'deleted');
}

function applyDelta(
  summary: {
    totalDebit: number;
    totalCredit: number;
    transactionCount: number;
    byCategory: Record<string, number>;
    byMerchant: Record<string, number>;
  },
  tx: TxLike,
  sign: 1 | -1,
): void {
  const amount = Number(tx.amount) || 0;
  if (tx.type === 'debit') {
    summary.totalDebit += sign * amount;
    const cat = tx.category || 'Uncategorized';
    summary.byCategory[cat] = (summary.byCategory[cat] ?? 0) + sign * amount;
    const merchant = tx.merchant || 'Unknown';
    summary.byMerchant[merchant] =
      (summary.byMerchant[merchant] ?? 0) + sign * amount;
  } else if (tx.type === 'credit') {
    summary.totalCredit += sign * amount;
  }
  summary.transactionCount += sign;
}

function pruneZeros(map: Record<string, number>): Record<string, number> {
  const next: Record<string, number> = {};
  for (const [key, value] of Object.entries(map)) {
    if (Math.abs(value) > 0.0001) {
      next[key] = Math.round(value * 100) / 100;
    }
  }
  return next;
}

async function updateMonthlySummary(
  uid: string,
  yearMonth: string,
  mutate: (summary: {
    totalDebit: number;
    totalCredit: number;
    transactionCount: number;
    byCategory: Record<string, number>;
    byMerchant: Record<string, number>;
    currency: string;
  }) => void,
  currencyHint: string,
): Promise<void> {
  const ref = db
    .collection(COLLECTIONS.users)
    .doc(uid)
    .collection(COLLECTIONS.monthlySummaries)
    .doc(yearMonth);

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    const existing = snap.exists ? snap.data() : null;
    const summary = {
      totalDebit: Number(existing?.totalDebit ?? 0),
      totalCredit: Number(existing?.totalCredit ?? 0),
      transactionCount: Number(existing?.transactionCount ?? 0),
      byCategory: {
        ...((existing?.byCategory as Record<string, number> | undefined) ?? {}),
      },
      byMerchant: {
        ...((existing?.byMerchant as Record<string, number> | undefined) ?? {}),
      },
      currency:
        typeof existing?.currency === 'string' && existing.currency
          ? existing.currency
          : currencyHint,
    };

    mutate(summary);

    txn.set(
      ref,
      {
        yearMonth,
        currency: summary.currency,
        totalDebit: Math.round(summary.totalDebit * 100) / 100,
        totalCredit: Math.round(summary.totalCredit * 100) / 100,
        net:
          Math.round((summary.totalCredit - summary.totalDebit) * 100) / 100,
        transactionCount: Math.max(0, summary.transactionCount),
        byCategory: pruneZeros(summary.byCategory),
        byMerchant: pruneZeros(summary.byMerchant),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

/**
 * Maintains users/{uid}/monthlySummaries/{YYYY-MM} on transaction writes.
 */
export const onUserTransactionWritten = onDocumentWritten(
  {
    document: 'users/{userId}/transactions/{transactionId}',
    region: 'asia-south1',
  },
  async (
    event: FirestoreEvent<
      Change<DocumentSnapshot> | undefined,
      { userId: string; transactionId: string }
    >,
  ) => {
    const uid = event.params.userId;
    const before = event.data?.before?.exists
      ? (event.data.before.data() as TxLike)
      : null;
    const after = event.data?.after?.exists
      ? (event.data.after.data() as TxLike)
      : null;

    const beforeActive = isActive(before);
    const afterActive = isActive(after);

    const beforeYm =
      before && beforeActive ? yearMonthFromDate(before.transactionDate) : null;
    const afterYm =
      after && afterActive ? yearMonthFromDate(after.transactionDate) : null;

    // Same month create/update/delete: apply -before +after in one pass
    if (beforeYm && afterYm && beforeYm === afterYm && before && after) {
      await updateMonthlySummary(
        uid,
        beforeYm,
        (summary) => {
          if (beforeActive) applyDelta(summary, before, -1);
          if (afterActive) applyDelta(summary, after, 1);
        },
        after.currency || before.currency || 'PKR',
      );
      return;
    }

    if (beforeYm && before && beforeActive) {
      await updateMonthlySummary(
        uid,
        beforeYm,
        (summary) => applyDelta(summary, before, -1),
        before.currency || 'PKR',
      );
    }

    if (afterYm && after && afterActive) {
      await updateMonthlySummary(
        uid,
        afterYm,
        (summary) => applyDelta(summary, after, 1),
        after.currency || 'PKR',
      );
    }
  },
);
