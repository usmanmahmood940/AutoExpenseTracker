import {
  AggregateField,
  Timestamp,
  type Query,
  type QueryDocumentSnapshot,
} from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from './admin';
import { COLLECTIONS } from './schema';

const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 100;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

type SortBy = 'date' | 'amount';
type OrderBy = 'asc' | 'desc';

interface ListTransactionsInput {
  pageSize?: unknown;
  cursor?: unknown;
  includeAggregates?: unknown;
  /** Optional inclusive start date (YYYY-MM-DD). */
  dateFrom?: unknown;
  /** Optional inclusive end date (YYYY-MM-DD). */
  dateTo?: unknown;
  /** Sort field. Defaults to date. Accepts Date/date or Amount/amount. */
  sortBy?: unknown;
  /** Sort direction. Defaults to desc. Accepts Asc/asc or Desc/desc. */
  orderBy?: unknown;
}

function parseDateField(
  value: unknown,
  fieldName: string,
): string | null {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string' || !DATE_RE.test(value.trim())) {
    throw new HttpsError(
      'invalid-argument',
      `${fieldName} must be a YYYY-MM-DD date.`,
    );
  }
  return value.trim();
}

function parseSortBy(value: unknown): SortBy {
  if (value === undefined || value === null || value === '') return 'date';
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'sortBy must be a string.');
  }
  const normalized = value.trim().toLowerCase();
  if (normalized === 'date') return 'date';
  if (normalized === 'amount') return 'amount';
  throw new HttpsError(
    'invalid-argument',
    'sortBy must be "date" or "amount".',
  );
}

function parseOrderBy(value: unknown): OrderBy {
  if (value === undefined || value === null || value === '') return 'desc';
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'orderBy must be a string.');
  }
  const normalized = value.trim().toLowerCase();
  if (normalized === 'desc') return 'desc';
  if (normalized === 'asc') return 'asc';
  throw new HttpsError(
    'invalid-argument',
    'orderBy must be "asc" or "desc".',
  );
}

function parseInput(data: unknown): {
  pageSize: number;
  cursor: string | null;
  includeAggregates: boolean;
  dateFrom: string | null;
  dateTo: string | null;
  sortBy: SortBy;
  orderBy: OrderBy;
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
  if (
    input.includeAggregates !== undefined &&
    typeof input.includeAggregates !== 'boolean'
  ) {
    throw new HttpsError(
      'invalid-argument',
      'includeAggregates must be a boolean.',
    );
  }

  const dateFrom = parseDateField(input.dateFrom, 'dateFrom');
  const dateTo = parseDateField(input.dateTo, 'dateTo');
  if (dateFrom && dateTo && dateFrom > dateTo) {
    throw new HttpsError(
      'invalid-argument',
      'dateFrom must be on or before dateTo.',
    );
  }

  const sortBy = parseSortBy(input.sortBy);
  const orderBy = parseOrderBy(input.orderBy);

  // Firestore requires the inequality field to be the first orderBy.
  if (sortBy === 'amount' && (dateFrom || dateTo)) {
    throw new HttpsError(
      'invalid-argument',
      'sortBy "amount" cannot be combined with a date range.',
    );
  }

  return {
    pageSize: requestedPageSize,
    cursor: input.cursor?.trim() || null,
    includeAggregates: input.includeAggregates ?? false,
    dateFrom,
    dateTo,
    sortBy,
    orderBy,
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

function sortField(sortBy: SortBy): string {
  return sortBy === 'amount' ? 'amount' : 'transactionDate';
}

function applyDateRange(
  query: Query,
  dateFrom: string | null,
  dateTo: string | null,
): Query {
  let next = query;
  if (dateFrom) {
    next = next.where('transactionDate', '>=', dateFrom);
  }
  if (dateTo) {
    next = next.where('transactionDate', '<=', dateTo);
  }
  return next;
}

/**
 * Returns a transaction page and, when requested, server-side aggregate totals.
 * The request UID is derived exclusively from the verified Firebase ID token.
 *
 * Optional: dateFrom / dateTo (YYYY-MM-DD).
 * sortBy defaults to "date"; orderBy defaults to "desc".
 */
export const listTransactions = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const {
    pageSize,
    cursor,
    includeAggregates,
    dateFrom,
    dateTo,
    sortBy,
    orderBy,
  } = parseInput(request.data);

  const field = sortField(sortBy);
  let baseQuery = applyDateRange(activeTransactions(uid), dateFrom, dateTo);
  let pageQuery = baseQuery.orderBy(field, orderBy);

  // Tie-breaker for stable paging when sorting by amount.
  if (sortBy === 'amount') {
    pageQuery = pageQuery.orderBy('transactionDate', orderBy);
  }

  if (cursor) {
    const cursorSnapshot = await db
      .collection(COLLECTIONS.users)
      .doc(uid)
      .collection(COLLECTIONS.transactions)
      .doc(cursor)
      .get();
    if (!cursorSnapshot.exists) {
      throw new HttpsError(
        'invalid-argument',
        'The page cursor is no longer valid.',
      );
    }
    pageQuery = pageQuery.startAfter(
      cursorSnapshot as QueryDocumentSnapshot,
    );
  }

  // Fetch the page first so a missing aggregate index cannot blank the home feed.
  const pageSnapshot = await pageQuery.limit(pageSize + 1).get();

  const documents = pageSnapshot.docs;
  const hasMore = documents.length > pageSize;
  const pageDocuments = hasMore ? documents.slice(0, pageSize) : documents;

  let totalCount = pageDocuments.length;
  let totalAmount = 0;
  if (includeAggregates) {
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
      console.warn(
        'listTransactions aggregates unavailable; returning page only',
        error,
      );
    }
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
    sortBy,
    orderBy,
    dateFrom,
    dateTo,
  };
});
