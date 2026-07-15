/**
 * Shared Firestore schema types for Auto Expense Tracker.
 * Used by Cloud Functions (Phase 1+) and future client apps.
 */

export type TransactionType = 'debit' | 'credit';

/** 'user', 'rule', or the Gemini model id that categorized the transaction */
export type CategorySource = 'user' | 'rule' | string;

export type TransactionStatus = 'active' | 'deleted' | 'needs_review';

export type IngestionSource = 'ios_shortcut' | 'gmail' | 'manual';

export type IngestionStatus =
  | 'received'
  | 'parsed'
  | 'duplicate'
  | 'needs_parse'
  | 'failed';

export type ExternalIdType = 'tid' | 'ref' | 'stan' | 'unknown';

export type CategoryType = 'expense' | 'income' | 'other';

/**
 * Firestore: categories/{categoryId} (global defaults)
 * Firestore: users/{userId}/categories/{categoryId} (user-created)
 */
export interface Category {
  name: string;
  type: CategoryType;
  icon: string;
  sortOrder: number;
  /** true for docs under top-level `categories/` */
  isDefault: boolean;
  createdAt: FirebaseTimestamp;
  updatedAt: FirebaseTimestamp;
}

/** Seed payload without timestamps (Admin SDK sets server timestamps). */
export interface CategorySeed {
  id: string;
  name: string;
  type: CategoryType;
  icon: string;
  sortOrder: number;
  isDefault: boolean;
}

/** Fallback when the model returns an unknown category */
export const FALLBACK_CATEGORY_NAME = 'Uncategorized';

/**
 * Default categories stored in Firestore `categories/{id}`.
 * Webhook / Gemini categorization must use only these names.
 */
export const DEFAULT_CATEGORIES: readonly CategorySeed[] = [
  {
    id: 'food_dining',
    name: 'Food & Dining',
    type: 'expense',
    icon: 'restaurant',
    sortOrder: 1,
    isDefault: true,
  },
  {
    id: 'groceries',
    name: 'Groceries',
    type: 'expense',
    icon: 'cart',
    sortOrder: 2,
    isDefault: true,
  },
  {
    id: 'fuel',
    name: 'Fuel',
    type: 'expense',
    icon: 'local_gas_station',
    sortOrder: 3,
    isDefault: true,
  },
  {
    id: 'transport',
    name: 'Transport',
    type: 'expense',
    icon: 'directions_car',
    sortOrder: 4,
    isDefault: true,
  },
  {
    id: 'shopping',
    name: 'Shopping',
    type: 'expense',
    icon: 'shopping_bag',
    sortOrder: 5,
    isDefault: true,
  },
  {
    id: 'entertainment',
    name: 'Entertainment',
    type: 'expense',
    icon: 'movie',
    sortOrder: 6,
    isDefault: true,
  },
  {
    id: 'bills_utilities',
    name: 'Bills & Utilities',
    type: 'expense',
    icon: 'bolt',
    sortOrder: 7,
    isDefault: true,
  },
  {
    id: 'healthcare',
    name: 'Healthcare',
    type: 'expense',
    icon: 'medical_services',
    sortOrder: 8,
    isDefault: true,
  },
  {
    id: 'education',
    name: 'Education',
    type: 'expense',
    icon: 'school',
    sortOrder: 9,
    isDefault: true,
  },
  {
    id: 'travel',
    name: 'Travel',
    type: 'expense',
    icon: 'flight',
    sortOrder: 10,
    isDefault: true,
  },
  {
    id: 'personal_care',
    name: 'Personal Care',
    type: 'expense',
    icon: 'spa',
    sortOrder: 11,
    isDefault: true,
  },
  {
    id: 'subscriptions',
    name: 'Subscriptions',
    type: 'expense',
    icon: 'replay',
    sortOrder: 12,
    isDefault: true,
  },
  {
    id: 'rent_housing',
    name: 'Rent & Housing',
    type: 'expense',
    icon: 'home',
    sortOrder: 13,
    isDefault: true,
  },
  {
    id: 'cash_withdrawal',
    name: 'Cash Withdrawal',
    type: 'expense',
    icon: 'atm',
    sortOrder: 14,
    isDefault: true,
  },
  {
    id: 'transfer',
    name: 'Transfer',
    type: 'expense',
    icon: 'swap_horiz',
    sortOrder: 15,
    isDefault: true,
  },
  {
    id: 'fees_charges',
    name: 'Fees & Charges',
    type: 'expense',
    icon: 'receipt',
    sortOrder: 16,
    isDefault: true,
  },
  {
    id: 'donations_zakat',
    name: 'Donations & Zakat',
    type: 'expense',
    icon: 'volunteer_activism',
    sortOrder: 17,
    isDefault: true,
  },
  {
    id: 'income',
    name: 'Income',
    type: 'income',
    icon: 'payments',
    sortOrder: 18,
    isDefault: true,
  },
  {
    id: 'refund',
    name: 'Refund',
    type: 'income',
    icon: 'undo',
    sortOrder: 19,
    isDefault: true,
  },
  {
    id: 'uncategorized',
    name: 'Uncategorized',
    type: 'other',
    icon: 'help_outline',
    sortOrder: 20,
    isDefault: true,
  },
] as const;

/**
 * Firestore collection: users/{userId}
 * Multi-user data also lives under:
 *   users/{userId}/transactions/{transactionId}
 *   users/{userId}/raw_ingestions/{ingestionId}
 *   users/{userId}/categories/{categoryId}
 */
export interface User {
  displayName: string;
  defaultCurrency: string;
  timezone: string;
  bankSenders: string[];
  emailFilters: string[];
  /** FCM device tokens registered by NovaSpend for push alerts */
  fcmTokens?: string[];
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

/**
 * Firestore collection (legacy single-user): transactions/{transactionId}
 * Multi-user: users/{userId}/transactions/{transactionId}
 */
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
  /** Full weekday name derived from transactionDate (e.g. Friday) */
  day: string;
  externalId: string | null;
  externalIdType: ExternalIdType;
  dedupKey: string;
  smsSource: SmsSource;
  parseConfidence: number;
  isAutoDetected: boolean;
  isEdited: boolean;
  isDuplicate: boolean;
  status: TransactionStatus;
  /** Set when user confirms / dismisses a low-confidence parse in Review */
  reviewedAt?: FirebaseTimestamp | null;
  createdAt: FirebaseTimestamp;
  updatedAt: FirebaseTimestamp;
}

/**
 * Firestore: users/{userId}/merchantCategoryOverrides/{normalizedMerchantKey}
 * Applied on ingest after Gemini parse so user corrections compound.
 */
export interface MerchantCategoryOverride {
  merchantKey: string;
  displayName: string;
  category: string;
  createdAt: FirebaseTimestamp;
  updatedAt: FirebaseTimestamp;
}

/**
 * Firestore: users/{userId}/monthlySummaries/{YYYY-MM}
 * Maintained by Cloud Function on transaction write.
 */
export interface MonthlySummary {
  yearMonth: string;
  currency: string;
  totalDebit: number;
  totalCredit: number;
  net: number;
  transactionCount: number;
  /** Debit totals keyed by category name */
  byCategory: Record<string, number>;
  /** Debit totals keyed by merchant */
  byMerchant: Record<string, number>;
  updatedAt: FirebaseTimestamp;
}

/**
 * Firestore: users/{userId}/budgets/{budgetId}
 */
export interface Budget {
  category: string;
  limit: number;
  period: 'monthly';
  currency: string;
  createdAt: FirebaseTimestamp;
  updatedAt: FirebaseTimestamp;
}

/**
 * Firestore: users/{userId}/meta/sync
 * Updated on each successful transaction ingest.
 */
export interface SyncMeta {
  lastSyncedAt: FirebaseTimestamp;
  lastMerchant?: string;
  lastAmount?: number;
  lastTransactionId?: string;
}

/**
 * Firestore collection (legacy single-user): raw_ingestions/{ingestionId}
 * Multi-user: users/{userId}/raw_ingestions/{ingestionId}
 */
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

/** Collection path constants (legacy top-level + multi-user nested) */
export const COLLECTIONS = {
  users: 'users',
  transactions: 'transactions',
  rawIngestions: 'raw_ingestions',
  categories: 'categories',
  merchantCategoryOverrides: 'merchantCategoryOverrides',
  monthlySummaries: 'monthlySummaries',
  budgets: 'budgets',
  meta: 'meta',
  emailVerificationOtps: 'emailVerificationOtps',
  passwordResetOtps: 'passwordResetOtps',
  passwordResetSessions: 'passwordResetSessions',
  authRateLimits: 'authRateLimits',
} as const;

/** Nested collection helpers: users/{uid}/raw_ingestions|transactions|categories */
export function userRawIngestionsPath(uid: string): string {
  return `${COLLECTIONS.users}/${uid}/${COLLECTIONS.rawIngestions}`;
}

export function userTransactionsPath(uid: string): string {
  return `${COLLECTIONS.users}/${uid}/${COLLECTIONS.transactions}`;
}

export function userCategoriesPath(uid: string): string {
  return `${COLLECTIONS.users}/${uid}/${COLLECTIONS.categories}`;
}

export function userMerchantOverridesPath(uid: string): string {
  return `${COLLECTIONS.users}/${uid}/${COLLECTIONS.merchantCategoryOverrides}`;
}

export function userMonthlySummariesPath(uid: string): string {
  return `${COLLECTIONS.users}/${uid}/${COLLECTIONS.monthlySummaries}`;
}

export function userBudgetsPath(uid: string): string {
  return `${COLLECTIONS.users}/${uid}/${COLLECTIONS.budgets}`;
}

/** Normalize merchant name for override document ids / lookups */
export function normalizeMerchantKey(merchant: string): string {
  return merchant.trim().toLowerCase().replace(/\s+/g, ' ');
}

/** Default user ID for legacy single-user webhook (top-level collections) */
export const DEFAULT_USER_ID = 'me';
