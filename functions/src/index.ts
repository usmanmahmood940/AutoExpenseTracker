/**
 * Cloud Functions entry point.
 * Phase 1 will add ingestTransaction HTTP function here.
 */

import { setGlobalOptions } from 'firebase-functions/v2';

setGlobalOptions({
  region: 'asia-south1',
  maxInstances: 10,
});

export { ingestTransaction, ingestTransactionForUser } from './ingest';
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
