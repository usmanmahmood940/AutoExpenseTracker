/**
 * Shared Firestore schema types for Auto Expense Tracker.
 * Used by Cloud Functions (Phase 1+) and future client apps.
 */

export type TransactionType = 'debit' | 'credit';

export type CategorySource = 'ai' | 'user' | 'rule';

export type TransactionStatus = 'active' | 'deleted' | 'needs_review';

export type IngestionSource = 'ios_shortcut' | 'gmail' | 'manual';

export type IngestionStatus =
  | 'received'
  | 'parsed'
  | 'duplicate'
  | 'needs_parse'
  | 'failed';

export type ExternalIdType = 'tid' | 'ref' | 'stan' | 'unknown';

/** Firestore collection: users/{userId} */
export interface User {
  displayName: string;
  defaultCurrency: string;
  timezone: string;
  bankSenders: string[];
  emailFilters: string[];
  createdAt: FirebaseTimestamp;
  updatedAt: FirebaseTimestamp;
  settings: UserSettings;
}

export interface UserSettings {
  autoCategorize: boolean;
}

/** Nested object on transactions */
export interface SmsSource {
  raw: string;
  source: IngestionSource;
  receivedAt: FirebaseTimestamp;
  messageId?: string;
  idempotencyKey?: string;
}

/** Firestore collection: transactions/{transactionId} */
export interface Transaction {
  userId: string;
  amount: number;
  currency: string;
  type: TransactionType;
  merchant: string;
  merchantDetails: string | null;
  category: string;
  categorySource: CategorySource;
  paymentMethod: string;
  bank: string;
  accountId: string;
  accountIdMasked: string;
  branch: string | null;
  transactionTime: string;
  transactionDate: string;
  externalId: string | null;
  externalIdType: ExternalIdType;
  dedupKey: string;
  smsSource: SmsSource;
  parseConfidence: number;
  isAutoDetected: boolean;
  isEdited: boolean;
  isDuplicate: boolean;
  status: TransactionStatus;
  createdAt: FirebaseTimestamp;
  updatedAt: FirebaseTimestamp;
}

/** Firestore collection: raw_ingestions/{ingestionId} */
export interface RawIngestion {
  userId: string;
  raw: string;
  source: IngestionSource;
  receivedAt: FirebaseTimestamp;
  messageId?: string;
  idempotencyKey?: string;
  status: IngestionStatus;
  transactionId?: string;
  error?: string;
  createdAt: FirebaseTimestamp;
  updatedAt: FirebaseTimestamp;
}

/** Webhook request body from iOS Shortcut or Gmail Apps Script */
export interface IngestWebhookRequest {
  raw: string;
  source: IngestionSource;
  receivedAt: string;
  /** Optional — set once in Shortcut; overrides AI-detected bank name */
  bank?: string;
  messageId?: string;
  idempotencyKey?: string;
}

/** Webhook response from ingestTransaction Cloud Function */
export interface IngestWebhookResponse {
  success: boolean;
  transactionId?: string;
  ingestionId?: string;
  duplicate?: boolean;
  error?: string;
}

/** Gemini structured output — parsed transaction fields before enrichment */
export interface ParsedTransaction {
  amount: number;
  currency: string;
  type: TransactionType;
  merchant: string;
  merchantDetails: string | null;
  category: string;
  paymentMethod: string;
  bank: string;
  accountId: string;
  branch: string | null;
  transactionTime: string;
  transactionDate: string;
  externalId: string | null;
  externalIdType: ExternalIdType;
  parseConfidence: number;
}

/** Firestore Timestamp — compatible with admin and client SDKs */
export type FirebaseTimestamp =
  | { seconds: number; nanoseconds: number }
  | import('firebase-admin/firestore').Timestamp;

/** Collection path constants */
export const COLLECTIONS = {
  users: 'users',
  transactions: 'transactions',
  rawIngestions: 'raw_ingestions',
} as const;

/** Default user ID for single-user mode until Firebase Auth (Phase 5) */
export const DEFAULT_USER_ID = 'me';
