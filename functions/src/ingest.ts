import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { onRequest } from 'firebase-functions/v2/https';
import type { Request, Response } from 'express';

import { db, auth } from './admin';
import { dayNameFromDate, parseReceivedAt } from './dates';
import { computeDedupKey, maskAccountId } from './dedup';
import { parseTransaction } from './gemini';
import {
  COLLECTIONS,
  DEFAULT_USER_ID,
  type IngestWebhookRequest,
  type IngestWebhookResponse,
  type RawIngestion,
  type Transaction,
  type User,
} from './schema';
import { validateParsedTransaction, validateWebhookRequest } from './validate';

const webhookApiKey = defineSecret('WEBHOOK_API_KEY');
const geminiApiKey = defineSecret('GEMINI_API_KEY');

const API_KEY_HEADER = 'x-api-key';
const USER_ID_HEADER = 'x-user-id';

/** Firebase Auth UIDs / safe path segment: letters, digits, _ and - */
const UID_RE = /^[a-zA-Z0-9_-]{1,128}$/;

type IngestScope =
  | { mode: 'legacy' }
  | { mode: 'user'; uid: string };

function unauthorized(): IngestWebhookResponse {
  return { success: false, error: 'Unauthorized' };
}

function toTimestamp(receivedAt: string): Timestamp {
  const date = parseReceivedAt(receivedAt);
  if (!date) {
    throw new Error(`Invalid receivedAt: ${receivedAt}`);
  }
  return Timestamp.fromDate(date);
}

function resolveUserId(scope: IngestScope): string {
  return scope.mode === 'user' ? scope.uid : DEFAULT_USER_ID;
}

function rawIngestionsCollection(scope: IngestScope) {
  if (scope.mode === 'user') {
    return db
      .collection(COLLECTIONS.users)
      .doc(scope.uid)
      .collection(COLLECTIONS.rawIngestions);
  }
  return db.collection(COLLECTIONS.rawIngestions);
}

function transactionsCollection(scope: IngestScope) {
  if (scope.mode === 'user') {
    return db
      .collection(COLLECTIONS.users)
      .doc(scope.uid)
      .collection(COLLECTIONS.transactions);
  }
  return db.collection(COLLECTIONS.transactions);
}

async function ensureUserDocument(uid: string): Promise<void> {
  const userRef = db.collection(COLLECTIONS.users).doc(uid);
  const existing = await userRef.get();
  if (existing.exists) {
    return;
  }

  const now = FieldValue.serverTimestamp();
  const user: Omit<User, 'createdAt' | 'updatedAt'> & {
    createdAt: FirebaseFirestore.FieldValue;
    updatedAt: FirebaseFirestore.FieldValue;
  } = {
    displayName: '',
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

async function findIdempotentIngestion(
  scope: IngestScope,
  idempotencyKey: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot | null> {
  const col = rawIngestionsCollection(scope);

  // Legacy top-level collections still filter by userId field
  const query =
    scope.mode === 'legacy'
      ? col
          .where('userId', '==', DEFAULT_USER_ID)
          .where('idempotencyKey', '==', idempotencyKey)
      : col.where('idempotencyKey', '==', idempotencyKey);

  const snapshot = await query.limit(1).get();
  return snapshot.empty ? null : snapshot.docs[0];
}

async function findDuplicateTransaction(
  scope: IngestScope,
  dedupKey: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot | null> {
  const col = transactionsCollection(scope);

  const query =
    scope.mode === 'legacy'
      ? col
          .where('userId', '==', DEFAULT_USER_ID)
          .where('dedupKey', '==', dedupKey)
      : col.where('dedupKey', '==', dedupKey);

  const snapshot = await query.limit(1).get();
  return snapshot.empty ? null : snapshot.docs[0];
}

function buildIngestionResponse(
  ingestion: RawIngestion,
  ingestionId: string,
): IngestWebhookResponse {
  if (ingestion.status === 'duplicate') {
    return {
      success: true,
      duplicate: true,
      ingestionId,
      transactionId: ingestion.transactionId,
    };
  }

  if (ingestion.status === 'parsed') {
    return {
      success: true,
      ingestionId,
      transactionId: ingestion.transactionId,
    };
  }

  if (ingestion.status === 'needs_parse') {
    return {
      success: false,
      ingestionId,
      error: ingestion.error ?? 'Parsing needs manual review',
    };
  }

  if (ingestion.status === 'failed') {
    return {
      success: false,
      ingestionId,
      error: ingestion.error ?? 'Ingestion failed',
    };
  }

  return {
    success: true,
    ingestionId,
  };
}

async function createRawIngestion(
  scope: IngestScope,
  request: IngestWebhookRequest,
): Promise<string> {
  const now = FieldValue.serverTimestamp();
  const docRef = rawIngestionsCollection(scope).doc();

  const ingestion: Omit<RawIngestion, 'createdAt' | 'updatedAt'> & {
    createdAt: FirebaseFirestore.FieldValue;
    updatedAt: FirebaseFirestore.FieldValue;
  } = {
    userId: resolveUserId(scope),
    raw: request.raw,
    source: request.source,
    receivedAt: toTimestamp(request.receivedAt),
    status: 'received',
    createdAt: now,
    updatedAt: now,
  };

  if (request.messageId) {
    ingestion.messageId = request.messageId;
  }

  if (request.idempotencyKey) {
    ingestion.idempotencyKey = request.idempotencyKey;
  }

  await docRef.set(ingestion);
  return docRef.id;
}

async function updateRawIngestion(
  scope: IngestScope,
  ingestionId: string,
  patch: Partial<Pick<RawIngestion, 'status' | 'transactionId' | 'error'>>,
): Promise<void> {
  await rawIngestionsCollection(scope)
    .doc(ingestionId)
    .update({
      ...patch,
      updatedAt: FieldValue.serverTimestamp(),
    });
}

async function processIngest(
  scope: IngestScope,
  request: IngestWebhookRequest,
  geminiKey: string,
): Promise<IngestWebhookResponse> {
  if (scope.mode === 'user') {
    await ensureUserDocument(scope.uid);
  }

  if (request.idempotencyKey) {
    const existing = await findIdempotentIngestion(
      scope,
      request.idempotencyKey,
    );
    if (existing) {
      const ingestion = existing.data() as RawIngestion;
      return buildIngestionResponse(ingestion, existing.id);
    }
  }

  const ingestionId = await createRawIngestion(scope, request);

  const parseResult = await parseTransaction(geminiKey, request.raw);

  if (!parseResult.ok) {
    await updateRawIngestion(scope, ingestionId, {
      status: 'needs_parse',
      error: parseResult.error,
    });

    return {
      success: false,
      ingestionId,
      error: parseResult.error,
    };
  }

  const fieldValidation = validateParsedTransaction(parseResult.parsed);
  if (!fieldValidation.ok) {
    await updateRawIngestion(scope, ingestionId, {
      status: 'needs_parse',
      error: fieldValidation.error,
    });

    return {
      success: false,
      ingestionId,
      error: fieldValidation.error,
    };
  }

  const parsed = parseResult.parsed;
  const dedupKey = computeDedupKey(parsed);
  const duplicate = await findDuplicateTransaction(scope, dedupKey);

  if (duplicate) {
    await updateRawIngestion(scope, ingestionId, {
      status: 'duplicate',
      transactionId: duplicate.id,
    });

    return {
      success: true,
      duplicate: true,
      ingestionId,
      transactionId: duplicate.id,
    };
  }

  const now = FieldValue.serverTimestamp();
  const transactionRef = transactionsCollection(scope).doc();
  const transaction: Omit<Transaction, 'createdAt' | 'updatedAt'> & {
    createdAt: FirebaseFirestore.FieldValue;
    updatedAt: FirebaseFirestore.FieldValue;
  } = {
    userId: resolveUserId(scope),
    amount: parsed.amount,
    currency: parsed.currency,
    type: parsed.type,
    merchant: parsed.merchant,
    merchantDetails: parsed.merchantDetails,
    category: parsed.category,
    categorySource: parseResult.model,
    paymentMethod: parsed.paymentMethod,
    bank: request.bank ?? parsed.bank,
    accountId: parsed.accountId,
    accountIdMasked: maskAccountId(parsed.accountId),
    branch: parsed.branch,
    transactionTime: parsed.transactionTime,
    transactionDate: parsed.transactionDate,
    day: dayNameFromDate(parsed.transactionDate) ?? 'Unknown',
    externalId: parsed.externalId,
    externalIdType: parsed.externalIdType,
    dedupKey,
    smsSource: {
      raw: request.raw,
      source: request.source,
      receivedAt: toTimestamp(request.receivedAt),
      ...(request.messageId ? { messageId: request.messageId } : {}),
      ...(request.idempotencyKey
        ? { idempotencyKey: request.idempotencyKey }
        : {}),
    },
    parseConfidence: parsed.parseConfidence,
    isAutoDetected: true,
    isEdited: false,
    isDuplicate: false,
    status: 'active',
    createdAt: now,
    updatedAt: now,
  };

  await transactionRef.set(transaction);
  await updateRawIngestion(scope, ingestionId, {
    status: 'parsed',
    transactionId: transactionRef.id,
  });

  return {
    success: true,
    ingestionId,
    transactionId: transactionRef.id,
  };
}

function extractUid(req: Request): string | null {
  const fromHeader = req.header(USER_ID_HEADER)?.trim();
  if (fromHeader) {
    return fromHeader;
  }

  const fromQuery = req.query.uid;
  if (typeof fromQuery === 'string' && fromQuery.trim()) {
    return fromQuery.trim();
  }

  return null;
}

function isValidUid(uid: string): boolean {
  return UID_RE.test(uid);
}

function getAuthErrorCode(error: unknown): string | undefined {
  if (!error || typeof error !== 'object' || !('code' in error)) {
    return undefined;
  }
  const code = (error as { code: unknown }).code;
  return typeof code === 'string' ? code : undefined;
}

type AuthUidLookupResult =
  | { status: 'exists' }
  | { status: 'not_found' }
  | { status: 'invalid_uid' }
  | { status: 'auth_not_configured' }
  | { status: 'error'; message: string };

async function lookupAuthUid(uid: string): Promise<AuthUidLookupResult> {
  try {
    await auth.getUser(uid);
    return { status: 'exists' };
  } catch (error: unknown) {
    const code = getAuthErrorCode(error);

    if (code === 'auth/user-not-found') {
      return { status: 'not_found' };
    }
    if (code === 'auth/invalid-uid') {
      return { status: 'invalid_uid' };
    }
    if (code === 'auth/configuration-not-found') {
      return { status: 'auth_not_configured' };
    }

    const message =
      error instanceof Error ? error.message : 'Auth lookup failed';
    console.error('Auth UID lookup failed', { uid, code, message });
    return { status: 'error', message };
  }
}

async function handleIngestRequest(
  req: Request,
  res: Response,
  options: {
    authenticate: (req: Request) => boolean;
    resolveScope: (
      req: Request,
      res: Response,
    ) => Promise<IngestScope | null> | IngestScope | null;
  },
): Promise<void> {
  try {
    if (req.method !== 'POST') {
      res.status(405).json({ success: false, error: 'Method not allowed' });
      return;
    }

    if (!options.authenticate(req)) {
      res.status(401).json(unauthorized());
      return;
    }

    const scope = await options.resolveScope(req, res);
    if (!scope) {
      return;
    }

    const validation = validateWebhookRequest(req.body);
    if (!validation.ok) {
      res.status(400).json({ success: false, error: validation.error });
      return;
    }

    const result = await processIngest(
      scope,
      validation.data,
      geminiApiKey.value(),
    );
    res.status(200).json(result);
  } catch (error: unknown) {
    const message =
      error instanceof Error ? error.message : 'Internal server error';
    console.error('Ingest request failed', message, error);
    if (!res.headersSent) {
      res.status(500).json({ success: false, error: 'Internal server error' });
    }
  }
}

/** Legacy webhook: X-API-Key auth → top-level raw_ingestions + transactions */
export const ingestTransaction = onRequest(
  {
    secrets: [webhookApiKey, geminiApiKey],
    cors: false,
  },
  async (req, res) => {
    await handleIngestRequest(req, res, {
      authenticate: (r) => {
        const providedKey = r.header(API_KEY_HEADER);
        return Boolean(providedKey && providedKey === webhookApiKey.value());
      },
      resolveScope: () => ({ mode: 'legacy' }),
    });
  },
);

/**
 * Multi-user webhook: identifies the user via X-User-Id (or ?uid=)
 * and writes to users/{uid}/raw_ingestions + users/{uid}/transactions.
 * Rejects UIDs that do not exist in Firebase Auth.
 */
export const ingestTransactionForUser = onRequest(
  {
    secrets: [geminiApiKey],
    cors: false,
  },
  async (req, res) => {
    await handleIngestRequest(req, res, {
      authenticate: () => true,
      resolveScope: async (r, response) => {
        const uid = extractUid(r);
        if (!uid) {
          response.status(400).json({
            success: false,
            error:
              'uid is required (X-User-Id header or ?uid= query parameter)',
          });
          return null;
        }
        if (!isValidUid(uid)) {
          response.status(400).json({
            success: false,
            error:
              'uid must be 1–128 characters: letters, digits, underscore, or hyphen',
          });
          return null;
        }

        const lookup = await lookupAuthUid(uid);
        if (lookup.status === 'not_found') {
          response.status(404).json({
            success: false,
            error: 'uid does not exist in Firebase Auth',
          });
          return null;
        }
        if (lookup.status === 'invalid_uid') {
          response.status(400).json({
            success: false,
            error: 'uid is not a valid Firebase Auth user id',
          });
          return null;
        }
        if (lookup.status === 'auth_not_configured') {
          response.status(503).json({
            success: false,
            error:
              'Firebase Authentication is not configured for this project. Enable Authentication in the Firebase Console, then run: firebase deploy --only auth',
          });
          return null;
        }
        if (lookup.status === 'error') {
          response.status(500).json({
            success: false,
            error: 'Failed to verify uid with Firebase Auth',
          });
          return null;
        }

        return { mode: 'user', uid };
      },
    });
  },
);
