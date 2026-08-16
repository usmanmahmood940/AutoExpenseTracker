/**
 * Cloud Functions entry point.
 */

import { setGlobalOptions } from 'firebase-functions/v2';

setGlobalOptions({
  region: 'asia-south1',
  maxInstances: 10,
});

export { ingestTransactionForUser } from './ingest';
export { listTransactions } from './transactions';
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
