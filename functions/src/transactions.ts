import {
  AggregateField,
  Timestamp,
  type Query,
} from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from './admin';
import { COLLECTIONS } from './schema';

const DEFAULT_PAGE_SIZE = 50;
const MAX_PAGE_SIZE = 100;

interface ListTransactionsInput {
  pageSize?: unknown;
  cursor?: unknown;
}

function parseInput(data: unknown): {
  pageSize: number;
  cursor: string | null;
} {
  if (data != null && (typeof data !== 'object' || Array.isArray(data))) {
    throw new HttpsError('invalid-argument', 'Request data must be an object.');
  }

  const input = (data ?? {}) as ListTransactionsInput;
  const requestedPageSize = input.pageSize ?? DEFAULT_PAGE_SIZE;
  if (
    typeof requestedPageSize !== 'number' ||
    !Number.isInteger(requestedPageSize) ||
    requestedPageSize < 1 ||
    requestedPageSize > MAX_PAGE_SIZE
  ) {
    throw new HttpsError(
      'invalid-argument',
      `pageSize must be an integer from 1 to ${MAX_PAGE_SIZE}.`,
    );
  }

  if (
    input.cursor !== undefined &&
    (typeof input.cursor !== 'string' || input.cursor.trim().length === 0)
  ) {
    throw new HttpsError('invalid-argument', 'cursor must be a transaction id.');
  }

  return {
    pageSize: requestedPageSize,
    cursor: input.cursor?.trim() || null,
  };
}

function serializeValue(value: unknown): unknown {
  if (value instanceof Timestamp) {
    return value.toDate().toISOString();
  }
  if (Array.isArray(value)) {
    return value.map(serializeValue);
  }
  if (value != null && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([key, item]) => [
        key,
        serializeValue(item),
      ]),
    );
  }
  return value;
}

function activeTransactions(uid: string): Query {
  return db
    .collection(COLLECTIONS.users)
    .doc(uid)
    .collection(COLLECTIONS.transactions)
    .where('status', 'in', ['active', 'needs_review']);
}

/**
 * Returns a transaction page plus server-side aggregate totals for the user.
 * The request UID is derived exclusively from the verified Firebase ID token.
 */
export const listTransactions = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const { pageSize, cursor } = parseInput(request.data);
  const baseQuery = activeTransactions(uid);
  let pageQuery = baseQuery.orderBy('transactionDate', 'desc');

  if (cursor) {
    const cursorSnapshot = await db
      .collection(COLLECTIONS.users)
      .doc(uid)
      .collection(COLLECTIONS.transactions)
      .doc(cursor)
      .get();
    if (!cursorSnapshot.exists) {
      throw new HttpsError('invalid-argument', 'The page cursor is no longer valid.');
    }
    pageQuery = pageQuery.startAfter(cursorSnapshot);
  }

  // Fetch the page first so a missing aggregate index cannot blank the home feed.
  const pageSnapshot = await pageQuery.limit(pageSize + 1).get();

  const documents = pageSnapshot.docs;
  const hasMore = documents.length > pageSize;
  const pageDocuments = hasMore ? documents.slice(0, pageSize) : documents;

  let totalCount = pageDocuments.length;
  let totalAmount = 0;
  try {
    const aggregateSnapshot = await baseQuery
      .aggregate({
        totalCount: AggregateField.count(),
        totalAmount: AggregateField.sum('amount'),
      })
      .get();
    const aggregate = aggregateSnapshot.data();
    totalCount = aggregate.totalCount;
    totalAmount = aggregate.totalAmount ?? 0;
  } catch (error) {
    console.warn('listTransactions aggregates unavailable; returning page only', error);
  }

  return {
    items: pageDocuments.map((doc) => ({
      id: doc.id,
      data: serializeValue(doc.data()),
    })),
    nextCursor: hasMore ? pageDocuments.at(-1)?.id ?? null : null,
    hasMore,
    totalCount,
    totalAmount,
  };
});
