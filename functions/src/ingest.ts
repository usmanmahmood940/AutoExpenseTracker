import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { onRequest } from 'firebase-functions/v2/https';
import type { Request, Response } from 'express';

import { db, auth } from './admin';
import { loadAllowedCategoryNamesForUser } from './categories';
import { dayNameFromDate, parseReceivedAt } from './dates';
import { computeDedupKey, maskAccountId } from './dedup';
import { parseTransaction } from './gemini';
import {
  COLLECTIONS,
  normalizeMerchant,
  normalizeMerchantKey,
  resolveMerchant,
  type IngestWebhookRequest,
  type IngestWebhookResponse,
  type MerchantCategoryOverride,
  type RawIngestion,
  type Transaction,
} from './schema';
import { validateParsedTransaction, validateWebhookRequest } from './validate';
import { ensureUserDocument } from './user_profile';

const geminiApiKey = defineSecret('GEMINI_API_KEY');

const USER_ID_HEADER = 'x-user-id';

/** Firebase Auth UIDs / safe path segment: letters, digits, _ and - */
const UID_RE = /^[a-zA-Z0-9_-]{1,128}$/;

function toTimestamp(receivedAt: string): Timestamp {
  const date = parseReceivedAt(receivedAt);
  if (!date) {
    throw new Error(`Invalid receivedAt: ${receivedAt}`);
  }
  return Timestamp.fromDate(date);
}

function rawIngestionsCollection(uid: string) {
  return db
    .collection(COLLECTIONS.users)
    .doc(uid)
    .collection(COLLECTIONS.rawIngestions);
}

function transactionsCollection(uid: string) {
  return db
    .collection(COLLECTIONS.users)
    .doc(uid)
    .collection(COLLECTIONS.transactions);
}

async function findIdempotentIngestion(
  uid: string,
  idempotencyKey: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot | null> {
  const snapshot = await rawIngestionsCollection(uid)
    .where('idempotencyKey', '==', idempotencyKey)
    .limit(1)
    .get();
  return snapshot.empty ? null : snapshot.docs[0];
}

async function findDuplicateTransaction(
  uid: string,
  dedupKey: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot | null> {
  const snapshot = await transactionsCollection(uid)
    .where('dedupKey', '==', dedupKey)
    .limit(1)
    .get();
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
  uid: string,
  request: IngestWebhookRequest,
): Promise<string> {
  const now = FieldValue.serverTimestamp();
  const docRef = rawIngestionsCollection(uid).doc();

  const ingestion: Omit<RawIngestion, 'createdAt' | 'updatedAt'> & {
    createdAt: FirebaseFirestore.FieldValue;
    updatedAt: FirebaseFirestore.FieldValue;
  } = {
    userId: uid,
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
  uid: string,
  ingestionId: string,
  patch: Partial<Pick<RawIngestion, 'status' | 'transactionId' | 'error'>>,
): Promise<void> {
  await rawIngestionsCollection(uid)
    .doc(ingestionId)
    .update({
      ...patch,
      updatedAt: FieldValue.serverTimestamp(),
    });
}

async function processIngest(
  uid: string,
  request: IngestWebhookRequest,
  geminiKey: string,
): Promise<IngestWebhookResponse> {
  await ensureUserDocument(uid);

  if (request.idempotencyKey) {
    const existing = await findIdempotentIngestion(uid, request.idempotencyKey);
    if (existing) {
      const ingestion = existing.data() as RawIngestion;
      return buildIngestionResponse(ingestion, existing.id);
    }
  }

  const ingestionId = await createRawIngestion(uid, request);

  const allowedCategories = await loadAllowedCategoryNamesForUser(uid);
  const parseResult = await parseTransaction(
    geminiKey,
    request.raw,
    allowedCategories,
    new Date(),
  );

  if (!parseResult.ok) {
    await updateRawIngestion(uid, ingestionId, {
      status: 'needs_parse',
      error: parseResult.error,
    });

    return {
      success: false,
      ingestionId,
      error: parseResult.error,
    };
  }

  const parsed = {
    ...parseResult.parsed,
    merchant: resolveMerchant(
      parseResult.parsed.merchant,
      parseResult.parsed.category,
      parseResult.parsed.paymentMethod,
    ),
  };

  const fieldValidation = validateParsedTransaction(
    parsed,
    allowedCategories,
  );
  if (!fieldValidation.ok) {
    await updateRawIngestion(uid, ingestionId, {
      status: 'needs_parse',
      error: fieldValidation.error,
    });

    return {
      success: false,
      ingestionId,
      error: fieldValidation.error,
    };
  }

  const dedupKey = computeDedupKey(parsed);
  const duplicate = await findDuplicateTransaction(uid, dedupKey);

  if (duplicate) {
    await updateRawIngestion(uid, ingestionId, {
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

  let category = parsed.category;
  let categorySource: Transaction['categorySource'] = parseResult.model;

  const override = await loadMerchantOverride(uid, parsed.merchant);
  if (override) {
    category = override.category;
    categorySource = 'rule';
  }

  const now = FieldValue.serverTimestamp();
  const transactionRef = transactionsCollection(uid).doc();
  const transaction: Omit<Transaction, 'createdAt' | 'updatedAt'> & {
    createdAt: FirebaseFirestore.FieldValue;
    updatedAt: FirebaseFirestore.FieldValue;
  } = {
    userId: uid,
    amount: parsed.amount,
    currency: parsed.currency,
    type: parsed.type,
    merchant: parsed.merchant,
    merchantDetails: parsed.merchantDetails,
    merchantNormalized: normalizeMerchant(parsed.merchant),
    isRecurring: false,
    category,
    categorySource,
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
    status: parsed.parseConfidence < 0.8 ? 'needs_review' : 'active',
    createdAt: now,
    updatedAt: now,
  };

  await transactionRef.set(transaction);
  await updateRawIngestion(uid, ingestionId, {
    status: 'parsed',
    transactionId: transactionRef.id,
  });

  await updateSyncMeta(uid, {
    lastMerchant: parsed.merchant,
    lastAmount: parsed.amount,
    lastTransactionId: transactionRef.id,
  });

  return {
    success: true,
    ingestionId,
    transactionId: transactionRef.id,
  };
}

async function loadMerchantOverride(
  uid: string,
  merchant: string,
): Promise<MerchantCategoryOverride | null> {
  const key = normalizeMerchantKey(merchant);
  if (!key) {
    return null;
  }

  const doc = await db
    .collection(COLLECTIONS.users)
    .doc(uid)
    .collection(COLLECTIONS.merchantCategoryOverrides)
    .doc(key)
    .get();

  if (!doc.exists) {
    return null;
  }

  return doc.data() as MerchantCategoryOverride;
}

async function updateSyncMeta(
  uid: string,
  patch: {
    lastMerchant: string;
    lastAmount: number;
    lastTransactionId: string;
  },
): Promise<void> {
  await db
    .collection(COLLECTIONS.users)
    .doc(uid)
    .collection(COLLECTIONS.meta)
    .doc('sync')
    .set(
      {
        lastSyncedAt: FieldValue.serverTimestamp(),
        ...patch,
      },
      { merge: true },
    );
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

async function resolveUid(
  req: Request,
  res: Response,
): Promise<string | null> {
  const uid = extractUid(req);
  if (!uid) {
    res.status(400).json({
      success: false,
      error: 'uid is required (X-User-Id header or ?uid= query parameter)',
    });
    return null;
  }
  if (!isValidUid(uid)) {
    res.status(400).json({
      success: false,
      error:
        'uid must be 1–128 characters: letters, digits, underscore, or hyphen',
    });
    return null;
  }

  const lookup = await lookupAuthUid(uid);
  if (lookup.status === 'not_found') {
    res.status(404).json({
      success: false,
      error: 'uid does not exist in Firebase Auth',
    });
    return null;
  }
  if (lookup.status === 'invalid_uid') {
    res.status(400).json({
      success: false,
      error: 'uid is not a valid Firebase Auth user id',
    });
    return null;
  }
  if (lookup.status === 'auth_not_configured') {
    res.status(503).json({
      success: false,
      error:
        'Firebase Authentication is not configured for this project. Enable Authentication in the Firebase Console, then run: firebase deploy --only auth',
    });
    return null;
  }
  if (lookup.status === 'error') {
    res.status(500).json({
      success: false,
      error: 'Failed to verify uid with Firebase Auth',
    });
    return null;
  }

  return uid;
}

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
    try {
      if (req.method !== 'POST') {
        res.status(405).json({ success: false, error: 'Method not allowed' });
        return;
      }

      const uid = await resolveUid(req, res);
      if (!uid) {
        return;
      }

      const validation = validateWebhookRequest(req.body);
      if (!validation.ok) {
        res.status(400).json({ success: false, error: validation.error });
        return;
      }

      const result = await processIngest(
        uid,
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
  },
);
