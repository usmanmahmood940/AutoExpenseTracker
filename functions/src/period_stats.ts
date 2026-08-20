import type { QueryDocumentSnapshot } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from './admin';
import { COLLECTIONS, normalizeMerchantKey } from './schema';

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const BATCH_SIZE = 300;

type PeriodKind = 'today' | 'week' | 'month';

interface PeriodStatsInput {
  period?: unknown;
  from?: unknown;
  to?: unknown;
}

interface HighlightTx {
  id: string;
  amount: number;
  merchant: string;
  merchantNormalized: string;
  category: string;
  transactionDate: string;
  type: string;
  currency: string;
}

interface RangeTotals {
  spent: number;
  received: number;
  currency: string;
  highestSpend: HighlightTx | null;
  highestReceive: HighlightTx | null;
}

function parseInput(data: unknown): {
  period: PeriodKind;
  from: string;
  to: string;
} {
  if (data != null && (typeof data !== 'object' || Array.isArray(data))) {
    throw new HttpsError('invalid-argument', 'Request data must be an object.');
  }

  const input = (data ?? {}) as PeriodStatsInput;
  const period = input.period;
  if (period !== 'today' && period !== 'week' && period !== 'month') {
    throw new HttpsError(
      'invalid-argument',
      'period must be "today", "week", or "month".',
    );
  }

  const from = typeof input.from === 'string' ? input.from.trim() : '';
  const to = typeof input.to === 'string' ? input.to.trim() : '';
  if (!DATE_RE.test(from) || !DATE_RE.test(to)) {
    throw new HttpsError(
      'invalid-argument',
      'from and to must be YYYY-MM-DD dates.',
    );
  }
  if (from > to) {
    throw new HttpsError('invalid-argument', 'from must be on or before to.');
  }

  return { period, from, to };
}

function parseYmd(value: string): Date {
  const [y, m, d] = value.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function formatYmd(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  next.setDate(next.getDate() + days);
  return next;
}

/** Previous comparable range — mirrors HomeProvider comparison windows. */
function previousRange(
  period: PeriodKind,
  from: string,
  to: string,
): { from: string; to: string } | null {
  if (period === 'today') return null;

  const fromDate = parseYmd(from);
  const toDate = parseYmd(to);

  if (period === 'week') {
    const daysElapsed = Math.round(
      (toDate.getTime() - fromDate.getTime()) / 86_400_000,
    );
    const prevFrom = addDays(fromDate, -7);
    const prevTo = addDays(prevFrom, daysElapsed);
    return { from: formatYmd(prevFrom), to: formatYmd(prevTo) };
  }

  // month: previous calendar month, start → same day-of-month (clamped)
  const prevMonthStart = new Date(fromDate.getFullYear(), fromDate.getMonth() - 1, 1);
  const lastDayPrevMonth = new Date(
    toDate.getFullYear(),
    toDate.getMonth(),
    0,
  ).getDate();
  const prevEndDay = Math.min(toDate.getDate(), lastDayPrevMonth);
  const prevTo = new Date(
    prevMonthStart.getFullYear(),
    prevMonthStart.getMonth(),
    prevEndDay,
  );
  return { from: formatYmd(prevMonthStart), to: formatYmd(prevTo) };
}

function percentChange(previous: number, current: number): number {
  if (previous === 0) {
    if (current === 0) return 0;
    return 100;
  }
  return ((current - previous) / Math.abs(previous)) * 100;
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

function isCountable(status: unknown): boolean {
  return status !== 'deleted';
}

async function computeRangeTotals(
  uid: string,
  from: string,
  to: string,
): Promise<RangeTotals> {
  let spent = 0;
  let received = 0;
  let currency = 'PKR';
  let highestSpend: HighlightTx | null = null;
  let highestReceive: HighlightTx | null = null;
  let cursor: QueryDocumentSnapshot | undefined;

  for (;;) {
    let pageQuery = db
      .collection(COLLECTIONS.users)
      .doc(uid)
      .collection(COLLECTIONS.transactions)
      .where('transactionDate', '>=', from)
      .where('transactionDate', '<=', to)
      .orderBy('transactionDate', 'desc')
      .limit(BATCH_SIZE);

    if (cursor) {
      pageQuery = pageQuery.startAfter(cursor);
    }

    const snap = await pageQuery.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      const data = doc.data();
      if (!isCountable(data.status)) continue;

      const amount = Number(data.amount) || 0;
      const type = data.type === 'credit' ? 'credit' : 'debit';
      if (typeof data.currency === 'string' && data.currency) {
        currency = data.currency;
      }

      const merchant =
        typeof data.merchant === 'string' ? data.merchant : '';
      const storedNormalized =
        typeof data.merchantNormalized === 'string'
          ? data.merchantNormalized
          : '';
      const highlight: HighlightTx = {
        id: doc.id,
        amount,
        merchant,
        merchantNormalized: storedNormalized || normalizeMerchantKey(merchant),
        category:
          typeof data.category === 'string' ? data.category : 'Uncategorized',
        transactionDate:
          typeof data.transactionDate === 'string' ? data.transactionDate : '',
        type,
        currency,
      };

      if (type === 'credit') {
        received += amount;
        if (!highestReceive || amount > highestReceive.amount) {
          highestReceive = highlight;
        }
      } else {
        spent += amount;
        if (!highestSpend || amount > highestSpend.amount) {
          highestSpend = highlight;
        }
      }
    }

    cursor = snap.docs.at(-1);
    if (snap.size < BATCH_SIZE) break;
  }

  return {
    spent: roundMoney(spent),
    received: roundMoney(received),
    currency,
    highestSpend,
    highestReceive,
  };
}

/**
 * Period overview + highlights for Home (today / week / month).
 * Comparison percents are returned only for week and month.
 */
export const getPeriodStats = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const { period, from, to } = parseInput(request.data);
  const current = await computeRangeTotals(uid, from, to);

  let comparison: {
    spentChangePercent: number;
    receivedChangePercent: number;
    netChangePercent: number;
  } | null = null;

  const prev = previousRange(period, from, to);
  if (prev) {
    const previous = await computeRangeTotals(uid, prev.from, prev.to);
    const currentNet = current.received - current.spent;
    const previousNet = previous.received - previous.spent;
    comparison = {
      spentChangePercent: roundMoney(
        percentChange(previous.spent, current.spent),
      ),
      receivedChangePercent: roundMoney(
        percentChange(previous.received, current.received),
      ),
      netChangePercent: roundMoney(percentChange(previousNet, currentNet)),
    };
  }

  const net = roundMoney(current.received - current.spent);

  return {
    period,
    from,
    to,
    currency: current.currency,
    spent: current.spent,
    received: current.received,
    net,
    highestSpend: current.highestSpend,
    highestReceive: current.highestReceive,
    comparison,
  };
});
