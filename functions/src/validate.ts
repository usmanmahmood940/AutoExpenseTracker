import type {
  IngestionSource,
  IngestWebhookRequest,
  ParsedTransaction,
  TransactionType,
} from './schema';

const INGESTION_SOURCES: IngestionSource[] = [
  'ios_shortcut',
  'gmail',
  'manual',
];

const TRANSACTION_TYPES: TransactionType[] = ['debit', 'credit'];

const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export function validateWebhookRequest(
  body: unknown,
): { ok: true; data: IngestWebhookRequest } | { ok: false; error: string } {
  if (!body || typeof body !== 'object') {
    return { ok: false, error: 'Request body must be a JSON object' };
  }

  const record = body as Record<string, unknown>;
  const raw = record.raw;
  const source = record.source;
  const receivedAt = record.receivedAt;

  if (typeof raw !== 'string' || raw.trim().length === 0) {
    return { ok: false, error: 'raw is required and must be a non-empty string' };
  }

  if (
    typeof source !== 'string' ||
    !INGESTION_SOURCES.includes(source as IngestionSource)
  ) {
    return {
      ok: false,
      error: 'source must be one of: ios_shortcut, gmail, manual',
    };
  }

  if (typeof receivedAt !== 'string' || Number.isNaN(Date.parse(receivedAt))) {
    return {
      ok: false,
      error: 'receivedAt is required and must be a valid ISO date string',
    };
  }

  const messageId =
    record.messageId === undefined
      ? undefined
      : typeof record.messageId === 'string'
        ? record.messageId
        : null;

  if (messageId === null) {
    return { ok: false, error: 'messageId must be a string when provided' };
  }

  const idempotencyKey =
    record.idempotencyKey === undefined
      ? undefined
      : typeof record.idempotencyKey === 'string'
        ? record.idempotencyKey
        : null;

  if (idempotencyKey === null) {
    return {
      ok: false,
      error: 'idempotencyKey must be a string when provided',
    };
  }

  return {
    ok: true,
    data: {
      raw: raw.trim(),
      source: source as IngestionSource,
      receivedAt,
      messageId,
      idempotencyKey,
    },
  };
}

export function validateParsedTransaction(
  parsed: ParsedTransaction,
): { ok: true } | { ok: false; error: string } {
  if (!Number.isFinite(parsed.amount) || parsed.amount <= 0) {
    return { ok: false, error: 'amount must be a positive number' };
  }

  if (!parsed.currency || typeof parsed.currency !== 'string') {
    return { ok: false, error: 'currency is required' };
  }

  if (!TRANSACTION_TYPES.includes(parsed.type)) {
    return { ok: false, error: 'type must be debit or credit' };
  }

  if (!parsed.merchant || typeof parsed.merchant !== 'string') {
    return { ok: false, error: 'merchant is required' };
  }

  if (!ISO_DATE_RE.test(parsed.transactionDate)) {
    return {
      ok: false,
      error: 'transactionDate must be in YYYY-MM-DD format',
    };
  }

  if (
    !Number.isFinite(parsed.parseConfidence) ||
    parsed.parseConfidence < 0 ||
    parsed.parseConfidence > 1
  ) {
    return {
      ok: false,
      error: 'parseConfidence must be a number between 0 and 1',
    };
  }

  return { ok: true };
}
