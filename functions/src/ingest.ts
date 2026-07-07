import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { onRequest } from 'firebase-functions/v2/https';

import { db } from './admin';
import { computeDedupKey, maskAccountId } from './dedup';
import { parseTransaction } from './gemini';
import {
  COLLECTIONS,
  DEFAULT_USER_ID,
  type IngestWebhookRequest,
  type IngestWebhookResponse,
  type RawIngestion,
  type Transaction,
} from './schema';
import { validateParsedTransaction, validateWebhookRequest } from './validate';

const webhookApiKey = defineSecret('WEBHOOK_API_KEY');
const geminiApiKey = defineSecret('GEMINI_API_KEY');

const API_KEY_HEADER = 'x-api-key';

function unauthorized(): IngestWebhookResponse {
  return { success: false, error: 'Unauthorized' };
}

function toTimestamp(isoDate: string): Timestamp {
  return Timestamp.fromDate(new Date(isoDate));
}

async function findIdempotentIngestion(
  idempotencyKey: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot | null> {
  const snapshot = await db
    .collection(COLLECTIONS.rawIngestions)
    .where('userId', '==', DEFAULT_USER_ID)
    .where('idempotencyKey', '==', idempotencyKey)
    .limit(1)
    .get();

  return snapshot.empty ? null : snapshot.docs[0];
}

async function findDuplicateTransaction(
  dedupKey: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot | null> {
  const snapshot = await db
    .collection(COLLECTIONS.transactions)
    .where('userId', '==', DEFAULT_USER_ID)
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
      success: true,
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
  request: IngestWebhookRequest,
): Promise<string> {
  const now = FieldValue.serverTimestamp();
  const docRef = db.collection(COLLECTIONS.rawIngestions).doc();

  const ingestion: Omit<RawIngestion, 'createdAt' | 'updatedAt'> & {
    createdAt: FirebaseFirestore.FieldValue;
    updatedAt: FirebaseFirestore.FieldValue;
  } = {
    userId: DEFAULT_USER_ID,
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
  ingestionId: string,
  patch: Partial<
    Pick<RawIngestion, 'status' | 'transactionId' | 'error'>
  >,
): Promise<void> {
  await db
    .collection(COLLECTIONS.rawIngestions)
    .doc(ingestionId)
    .update({
      ...patch,
      updatedAt: FieldValue.serverTimestamp(),
    });
}

export const ingestTransaction = onRequest(
  {
    secrets: [webhookApiKey, geminiApiKey],
    cors: false,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ success: false, error: 'Method not allowed' });
      return;
    }

    const providedKey = req.header(API_KEY_HEADER);
    if (!providedKey || providedKey !== webhookApiKey.value()) {
      res.status(401).json(unauthorized());
      return;
    }

    const validation = validateWebhookRequest(req.body);
    if (!validation.ok) {
      res.status(400).json({ success: false, error: validation.error });
      return;
    }

    const request = validation.data;

    if (request.idempotencyKey) {
      const existing = await findIdempotentIngestion(request.idempotencyKey);
      if (existing) {
        const ingestion = existing.data() as RawIngestion;
        res.status(200).json(buildIngestionResponse(ingestion, existing.id));
        return;
      }
    }

    const ingestionId = await createRawIngestion(request);

    const parseResult = await parseTransaction(
      geminiApiKey.value(),
      request.raw,
    );

    if (!parseResult.ok) {
      await updateRawIngestion(ingestionId, {
        status: 'needs_parse',
        error: parseResult.error,
      });

      res.status(200).json({
        success: true,
        ingestionId,
        error: parseResult.error,
      });
      return;
    }

    const fieldValidation = validateParsedTransaction(parseResult.parsed);
    if (!fieldValidation.ok) {
      await updateRawIngestion(ingestionId, {
        status: 'needs_parse',
        error: fieldValidation.error,
      });

      res.status(200).json({
        success: true,
        ingestionId,
        error: fieldValidation.error,
      });
      return;
    }

    const parsed = parseResult.parsed;
    const dedupKey = computeDedupKey(parsed);
    const duplicate = await findDuplicateTransaction(dedupKey);

    if (duplicate) {
      await updateRawIngestion(ingestionId, {
        status: 'duplicate',
        transactionId: duplicate.id,
      });

      res.status(200).json({
        success: true,
        duplicate: true,
        ingestionId,
        transactionId: duplicate.id,
      });
      return;
    }

    const now = FieldValue.serverTimestamp();
    const transactionRef = db.collection(COLLECTIONS.transactions).doc();
    const transaction: Omit<Transaction, 'createdAt' | 'updatedAt'> & {
      createdAt: FirebaseFirestore.FieldValue;
      updatedAt: FirebaseFirestore.FieldValue;
    } = {
      userId: DEFAULT_USER_ID,
      amount: parsed.amount,
      currency: parsed.currency,
      type: parsed.type,
      merchant: parsed.merchant,
      merchantDetails: parsed.merchantDetails,
      category: parsed.category,
      categorySource: 'ai',
      paymentMethod: parsed.paymentMethod,
      bank: parsed.bank,
      accountId: parsed.accountId,
      accountIdMasked: maskAccountId(parsed.accountId),
      branch: parsed.branch,
      transactionTime: parsed.transactionTime,
      transactionDate: parsed.transactionDate,
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
    await updateRawIngestion(ingestionId, {
      status: 'parsed',
      transactionId: transactionRef.id,
    });

    res.status(200).json({
      success: true,
      ingestionId,
      transactionId: transactionRef.id,
    });
  },
);
