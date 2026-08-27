/**
 * GENERATED FILE — DO NOT EDIT DIRECTLY.
 *
 * Mirrors `functions/src/schema.ts` (the deployed source of truth) for
 * future client apps that cannot import across the Cloud Functions
 * deploy boundary. Edit the source file, then run:
 *
 *   node scripts/sync-shared-schema.mjs
 */

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

export type {
  PaymentMethod,
} from './payment_methods';

export {
  DEFAULT_PAYMENT_METHOD,
  PAYMENT_METHODS,
  normalizePaymentMethod,
} from './payment_methods';

export type { CurrencyCode } from './currencies';

export {
  CURRENCIES,
  DEFAULT_CURRENCY,
  normalizeCurrency,
} from './currencies';

/**
 * Firestore: categories/{categoryId} (global defaults)
 * Firestore: users/{userId}/categories/{categoryId} (user-created)
 */
export interface Category {
  name: string;
  type: CategoryType;
  icon: string;
  /**
   * Psychology-based hex (`#RRGGBB`) for category icons in the client.
   * Icon glyph uses this color; icon background uses the same hue at 20% alpha.
   */
  color: string;
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
  /** Psychology-based hex (`#RRGGBB`) — see Category.color. */
  color: string;
  sortOrder: number;
  isDefault: boolean;
}

/** Fallback when the model returns an unknown category */
export const FALLBACK_CATEGORY_NAME = 'Uncategorized';

/**
 * Default categories stored in Firestore `categories/{id}`.
 * Webhook / Gemini categorization must use only these names.
 *
 * `color` is a psychology-based hex used by NovaSpend for the category
 * icon glyph (full opacity) and icon background (same hue, 20% alpha):
 * warm oranges for appetite/energy, greens for growth/freshness, blues
 * for movement, purple for leisure, reds for care/caution, etc.
 */
export const DEFAULT_CATEGORIES: readonly CategorySeed[] = [
  {
    id: 'food_dining',
    name: 'Food & Dining',
    type: 'expense',
    icon: 'restaurant',
    color: '#F57C00', // appetite, warmth, social dining
    sortOrder: 1,
    isDefault: true,
  },
  {
    id: 'groceries',
    name: 'Groceries',
    type: 'expense',
    icon: 'cart',
    color: '#43A047', // freshness, nature, produce
    sortOrder: 2,
    isDefault: true,
  },
  {
    id: 'fuel',
    name: 'Fuel',
    type: 'expense',
    icon: 'local_gas_station',
    color: '#BF360C', // heat, energy, petroleum
    sortOrder: 3,
    isDefault: true,
  },
  {
    id: 'transport',
    name: 'Transport',
    type: 'expense',
    icon: 'directions_car',
    color: '#1E88E5', // movement, reliability, transit
    sortOrder: 4,
    isDefault: true,
  },
  {
    id: 'shopping',
    name: 'Shopping',
    type: 'expense',
    icon: 'shopping_bag',
    color: '#D81B60', // desire, retail, impulse
    sortOrder: 5,
    isDefault: true,
  },
  {
    id: 'entertainment',
    name: 'Entertainment',
    type: 'expense',
    icon: 'movie',
    color: '#8E24AA', // fun, creativity, leisure
    sortOrder: 6,
    isDefault: true,
  },
  {
    id: 'bills_utilities',
    name: 'Bills & Utilities',
    type: 'expense',
    icon: 'bolt',
    color: '#FB8C00', // energy, electricity, essential services
    sortOrder: 7,
    isDefault: true,
  },
  {
    id: 'healthcare',
    name: 'Healthcare',
    type: 'expense',
    icon: 'medical_services',
    color: '#E53935', // care, urgency, medical
    sortOrder: 8,
    isDefault: true,
  },
  {
    id: 'education',
    name: 'Education',
    type: 'expense',
    icon: 'school',
    color: '#3949AB', // knowledge, wisdom, trust
    sortOrder: 9,
    isDefault: true,
  },
  {
    id: 'travel',
    name: 'Travel',
    type: 'expense',
    icon: 'flight',
    color: '#00838F', // horizon, adventure, sky/sea
    sortOrder: 10,
    isDefault: true,
  },
  {
    id: 'personal_care',
    name: 'Personal Care',
    type: 'expense',
    icon: 'spa',
    color: '#EC407A', // self-care, beauty
    sortOrder: 11,
    isDefault: true,
  },
  {
    id: 'subscriptions',
    name: 'Subscriptions',
    type: 'expense',
    icon: 'replay',
    color: '#5E35B1', // digital, premium, recurring
    sortOrder: 12,
    isDefault: true,
  },
  {
    id: 'rent_housing',
    name: 'Rent & Housing',
    type: 'expense',
    icon: 'home',
    color: '#6D4C41', // earth, home, stability
    sortOrder: 13,
    isDefault: true,
  },
  {
    id: 'cash_withdrawal',
    name: 'Cash Withdrawal',
    type: 'expense',
    icon: 'atm',
    color: '#F9A825', // money, cash, value
    sortOrder: 14,
    isDefault: true,
  },
  {
    id: 'transfer',
    name: 'Transfer',
    type: 'expense',
    icon: 'swap_horiz',
    color: '#039BE5', // flow, movement of money
    sortOrder: 15,
    isDefault: true,
  },
  {
    id: 'fees_charges',
    name: 'Fees & Charges',
    type: 'expense',
    icon: 'receipt',
    color: '#C62828', // caution, loss, warning
    sortOrder: 16,
    isDefault: true,
  },
  {
    id: 'donations_zakat',
    name: 'Donations & Zakat',
    type: 'expense',
    icon: 'volunteer_activism',
    color: '#00695C', // generosity, growth, faith
    sortOrder: 17,
    isDefault: true,
  },
  {
    id: 'income',
    name: 'Income',
    type: 'income',
    icon: 'payments',
    color: '#2E7D32', // prosperity, growth
    sortOrder: 18,
    isDefault: true,
  },
  {
    id: 'refund',
    name: 'Refund',
    type: 'income',
    icon: 'undo',
    color: '#26A69A', // return, recovery, relief
    sortOrder: 19,
    isDefault: true,
  },
  {
    id: 'uncategorized',
    name: 'Uncategorized',
    type: 'other',
    icon: 'help_outline',
    color: '#757575', // neutral, unknown
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
  /** Normalized merchant key for grouping / search (e.g. "kfc") */
  merchantNormalized: string;
  /** True when recurring detector has marked this as a subscription-like txn */
  isRecurring: boolean;
  /** Links related recurring transactions when detected */
  recurringGroupId?: string;
  category: string;
  categorySource: CategorySource;
  /** Canonical payment rail — see PAYMENT_METHODS */
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
 * Firestore: users/{userId}/aiSummaries/{periodId}
 * Written by scheduled Cloud Functions (weekly / monthly narrative).
 */
export interface AiSummary {
  type: 'weekly' | 'monthly';
  periodStart: FirebaseTimestamp;
  periodEnd: FirebaseTimestamp;
  narrative: string;
  generatedAt: FirebaseTimestamp;
  model: string;
}

/**
 * Firestore: users/{userId}/recurringPatterns/{merchantKey}
 * Written by recurring-detection Cloud Function; client read-only.
 */
export interface RecurringPattern {
  merchantDisplay: string;
  averageAmount: number;
  currency: string;
  /** Typical interval between charges (e.g. ~30 for monthly) */
  intervalDays: number;
  lastTransactionId: string;
  lastDate: FirebaseTimestamp;
  transactionCount: number;
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
  aiSummaries: 'aiSummaries',
  recurringPatterns: 'recurringPatterns',
  meta: 'meta',
  /** Short-lived OTPs + password-reset sessions (`type`: otp | reset_session). */
  authTemp: 'authTemp',
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

export function userAiSummariesPath(uid: string): string {
  return `${COLLECTIONS.users}/${uid}/${COLLECTIONS.aiSummaries}`;
}

export function userRecurringPatternsPath(uid: string): string {
  return `${COLLECTIONS.users}/${uid}/${COLLECTIONS.recurringPatterns}`;
}

export const DEFAULT_MERCHANT = 'Unknown';
export const ATM_MERCHANT = 'ATM';

/**
 * Normalize merchant name for indexing, overrides, and merchant pages.
 * Keep in sync with Flutter `normalizeMerchantKey`.
 */
export function normalizeMerchant(merchant: string): string {
  return normalizeMerchantKey(merchant);
}

/** Normalize merchant name for override document ids / lookups */
export function normalizeMerchantKey(merchant: string): string {
  return merchant.trim().toLowerCase().replace(/\s+/g, ' ');
}

/**
 * Stored/display name. Cash withdrawals with no merchant become ATM.
 * Keep in sync with Flutter `resolveMerchant` and Python `resolve_merchant`.
 */
export function resolveMerchant(
  merchant: string,
  category: string,
  paymentMethod: string,
): string {
  const trimmed = merchant.trim();
  const missing = trimmed === '' || trimmed.toLowerCase() === 'unknown';
  if (missing && isCashWithdrawal(category, paymentMethod)) {
    return ATM_MERCHANT;
  }
  return trimmed || DEFAULT_MERCHANT;
}

function isCashWithdrawal(category: string, paymentMethod: string): boolean {
  const cat = category.trim().toLowerCase();
  return (
    cat === 'cash withdrawal' ||
    cat === 'cash_withdrawal' ||
    paymentMethod.trim().toLowerCase() === 'atm_withdrawal'
  );
}

/** Default user ID for legacy single-user webhook (top-level collections) */
export const DEFAULT_USER_ID = 'me';
