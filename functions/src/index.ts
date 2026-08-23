/**
 * Cloud Functions entry point.
 *
 * Phase F dual-run: these stay deployed as a rollback target. Flutter and
 * Shortcuts now hit FastAPI. Firestore triggers go idle once ingest writes
 * Postgres only. Do not delete until §6 step 12.
 */

import { setGlobalOptions } from 'firebase-functions/v2';

setGlobalOptions({
  region: 'asia-south1',
  maxInstances: 10,
});

export { ingestTransactionForUser } from './ingest';
export { listTransactions } from './transactions';
export { getPeriodStats } from './period_stats';
export { onUserTransactionWritten } from './aggregates';
export { onUserTransactionCreatedNotify } from './notify';
export {
  sendEmailOtp,
  completeEmailOtpSignup,
  sendPasswordResetOtp,
  verifyPasswordResetOtp,
  completePasswordReset,
  ensureUserProfile,
} from './auth';
export { cleanupExpiredAuthDocs } from './auth_cleanup';
