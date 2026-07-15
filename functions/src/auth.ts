/**
 * Auth OTP flows: email signup verification + password reset.
 * Public HTTP endpoints (CORS enabled) consumed by NovaSpend via CloudFunctionsHttpClient.
 */

import { createHmac, randomBytes, randomInt, timingSafeEqual } from 'crypto';
import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { logger } from 'firebase-functions';

import { auth, db } from './admin';
import { COLLECTIONS } from './schema';
import { ensureUserDocument, ensureUserProfileForUid } from './user_profile';

const otpHashSecret = defineSecret('OTP_HASH_SECRET');
const resendApiKey = defineSecret('RESEND_API_KEY');
const resendFromEmail = defineSecret('RESEND_FROM_EMAIL');

const OTP_EXPIRY_MS = 10 * 60 * 1000;
const RESET_SESSION_EXPIRY_MS = 10 * 60 * 1000;
const MAX_OTP_ATTEMPTS = 5;
const OTP_REGEX = /^\d{6}$/;
const SEND_LIMIT_PER_EMAIL = 5;
const SEND_LIMIT_PER_IP = 20;
const VERIFY_LIMIT_PER_EMAIL = 10;
const RATE_WINDOW_MS = 15 * 60 * 1000;

type OtpPurpose = 'email_verification' | 'password_reset';

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function hashOtp(code: string): string {
  return createHmac('sha256', otpHashSecret.value()).update(code).digest('hex');
}

function safeEqualHex(a: string, b: string): boolean {
  try {
    const ba = Buffer.from(a, 'hex');
    const bb = Buffer.from(b, 'hex');
    if (ba.length !== bb.length) return false;
    return timingSafeEqual(ba, bb);
  } catch {
    return false;
  }
}

function generateOtp(): string {
  return String(randomInt(0, 1_000_000)).padStart(6, '0');
}

function clientIp(raw?: string | string[]): string {
  if (!raw) return 'unknown';
  const value = Array.isArray(raw) ? raw[0] : raw;
  return value.split(',')[0]?.trim() || 'unknown';
}

function rateDocId(kind: string, key: string): string {
  return `${kind}_${Buffer.from(key).toString('base64url').slice(0, 200)}`;
}

async function assertRateLimit(
  kind: 'send_email' | 'send_ip' | 'verify_email',
  key: string,
  limit: number,
): Promise<void> {
  const ref = db.collection(COLLECTIONS.authRateLimits).doc(rateDocId(kind, key));
  const now = Date.now();

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    let windowStart = now;
    let count = 0;

    if (data?.windowStartMs && typeof data.windowStartMs === 'number') {
      if (now - data.windowStartMs < RATE_WINDOW_MS) {
        windowStart = data.windowStartMs;
        count = typeof data.count === 'number' ? data.count : 0;
      }
    }

    if (count >= limit) {
      throw new HttpsError(
        'resource-exhausted',
        'Too many requests. Please try again later.',
      );
    }

    tx.set(
      ref,
      {
        kind,
        key,
        windowStartMs: windowStart,
        count: count + 1,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

async function sendResendEmail(params: {
  to: string;
  subject: string;
  html: string;
}): Promise<void> {
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${resendApiKey.value()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: resendFromEmail.value(),
      to: [params.to],
      subject: params.subject,
      html: params.html,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    logger.error('Resend email failed', { status: response.status, body });
    throw new HttpsError('internal', 'Failed to send email. Please try again.');
  }
}

async function storeAndSendOtp(params: {
  email: string;
  purpose: OtpPurpose;
  ip: string;
  subject: string;
  htmlBody: (code: string) => string;
}): Promise<void> {
  const email = normalizeEmail(params.email);
  if (!email.includes('@')) {
    throw new HttpsError('invalid-argument', 'Enter a valid email address.');
  }

  await assertRateLimit('send_email', email, SEND_LIMIT_PER_EMAIL);
  await assertRateLimit('send_ip', params.ip, SEND_LIMIT_PER_IP);

  const code = generateOtp();
  const codeHash = hashOtp(code);
  const now = Date.now();
  const collection =
    params.purpose === 'email_verification'
      ? COLLECTIONS.emailVerificationOtps
      : COLLECTIONS.passwordResetOtps;

  await db.collection(collection).doc(email).set({
    email,
    codeHash,
    attempts: 0,
    createdAtMs: now,
    expiresAtMs: now + OTP_EXPIRY_MS,
    createdAt: FieldValue.serverTimestamp(),
  });

  await sendResendEmail({
    to: email,
    subject: params.subject,
    html: params.htmlBody(code),
  });
}

async function verifyOtpDocument(params: {
  email: string;
  code: string;
  collection: string;
}): Promise<void> {
  const email = normalizeEmail(params.email);
  const code = params.code.trim();

  if (!OTP_REGEX.test(code)) {
    throw new HttpsError('invalid-argument', 'Enter a valid 6-digit code.');
  }

  await assertRateLimit('verify_email', email, VERIFY_LIMIT_PER_EMAIL);

  const ref = db.collection(params.collection).doc(email);
  const codeHash = hashOtp(code);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Invalid or expired code.');
    }

    const data = snap.data()!;
    const now = Date.now();
    if (typeof data.expiresAtMs !== 'number' || data.expiresAtMs < now) {
      tx.delete(ref);
      throw new HttpsError('deadline-exceeded', 'Code expired. Request a new one.');
    }

    const attempts = typeof data.attempts === 'number' ? data.attempts : 0;
    if (attempts >= MAX_OTP_ATTEMPTS) {
      tx.delete(ref);
      throw new HttpsError(
        'resource-exhausted',
        'Too many incorrect attempts. Request a new code.',
      );
    }

    if (!safeEqualHex(String(data.codeHash ?? ''), codeHash)) {
      tx.update(ref, { attempts: attempts + 1 });
      throw new HttpsError('invalid-argument', 'Invalid or expired code.');
    }

    tx.delete(ref);
  });
}

function requireAuthUid(request: { auth?: { uid: string } | null }): string {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  return request.auth.uid;
}

const authSecrets = {
  secrets: [otpHashSecret, resendApiKey, resendFromEmail],
  invoker: 'public' as const,
  cors: true,
};

export const sendEmailOtp = onCall(authSecrets, async (request) => {
  const email = normalizeEmail(String(request.data?.email ?? ''));
  const ip = clientIp(request.rawRequest?.headers?.['x-forwarded-for']);

  if (!email.includes('@')) {
    throw new HttpsError('invalid-argument', 'Enter a valid email address.');
  }

  // Fail on Sign Up before sending any code (authoritative Auth check).
  try {
    await auth.getUserByEmail(email);
    throw new HttpsError('already-exists', 'This email is already in use.');
  } catch (err: unknown) {
    if (err instanceof HttpsError) throw err;
    const codeName =
      err && typeof err === 'object' && 'code' in err
        ? String((err as { code: string }).code)
        : '';
    if (codeName !== 'auth/user-not-found') {
      logger.error('getUserByEmail failed during sendEmailOtp', err);
      throw new HttpsError('internal', 'Could not verify email. Please try again.');
    }
  }

  await storeAndSendOtp({
    email,
    purpose: 'email_verification',
    ip,
    subject: 'Your NovaSpend verification code',
    htmlBody: (code) =>
      `<p>Your NovaSpend verification code is <strong>${code}</strong>.</p>` +
      `<p>This code expires in 10 minutes.</p>`,
  });

  return { ok: true };
});

export const completeEmailOtpSignup = onCall(authSecrets, async (request) => {
  const email = normalizeEmail(String(request.data?.email ?? ''));
  const password = String(request.data?.password ?? '');
  const code = String(request.data?.code ?? '');

  if (password.length < 6) {
    throw new HttpsError('invalid-argument', 'Password must be at least 6 characters.');
  }

  // Check before consuming OTP so a taken email does not burn the code.
  try {
    await auth.getUserByEmail(email);
    throw new HttpsError('already-exists', 'This email is already in use.');
  } catch (err: unknown) {
    if (err instanceof HttpsError) throw err;
    const codeName =
      err && typeof err === 'object' && 'code' in err
        ? String((err as { code: string }).code)
        : '';
    if (codeName !== 'auth/user-not-found') {
      logger.error('getUserByEmail failed during completeEmailOtpSignup', err);
      throw new HttpsError('internal', 'Could not verify email. Please try again.');
    }
  }

  await verifyOtpDocument({
    email,
    code,
    collection: COLLECTIONS.emailVerificationOtps,
  });

  let user;
  try {
    user = await auth.createUser({
      email,
      password,
      emailVerified: true,
    });
  } catch (err: unknown) {
    const codeName =
      err && typeof err === 'object' && 'code' in err
        ? String((err as { code: string }).code)
        : '';
    if (codeName === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'This email is already in use.');
    }
    logger.error('createUser failed', err);
    throw new HttpsError('internal', 'Could not create account.');
  }

  await auth.setCustomUserClaims(user.uid, { emailOtpVerified: true });
  await ensureUserDocument(user.uid, { email, displayName: email.split('@')[0] });

  return { ok: true, uid: user.uid };
});

export const sendPasswordResetOtp = onCall(authSecrets, async (request) => {
  const email = normalizeEmail(String(request.data?.email ?? ''));
  const ip = clientIp(request.rawRequest?.headers?.['x-forwarded-for']);

  if (!email.includes('@')) {
    throw new HttpsError('invalid-argument', 'Enter a valid email address.');
  }

  // Always appear successful to avoid account enumeration, but only send if user exists.
  try {
    await auth.getUserByEmail(email);
  } catch {
    logger.info('Password reset OTP requested for unknown email');
    return { ok: true };
  }

  await storeAndSendOtp({
    email,
    purpose: 'password_reset',
    ip,
    subject: 'Your NovaSpend password reset code',
    htmlBody: (code) =>
      `<p>Your NovaSpend password reset code is <strong>${code}</strong>.</p>` +
      `<p>This code expires in 10 minutes.</p>`,
  });

  return { ok: true };
});

export const verifyPasswordResetOtp = onCall(authSecrets, async (request) => {
  const email = normalizeEmail(String(request.data?.email ?? ''));
  const code = String(request.data?.code ?? '');

  await verifyOtpDocument({
    email,
    code,
    collection: COLLECTIONS.passwordResetOtps,
  });

  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch {
    throw new HttpsError('not-found', 'No account found for this email.');
  }

  const resetToken = randomBytes(32).toString('hex');
  const now = Date.now();

  await db.collection(COLLECTIONS.passwordResetSessions).doc(resetToken).set({
    email,
    uid: user.uid,
    createdAtMs: now,
    expiresAtMs: now + RESET_SESSION_EXPIRY_MS,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { resetToken };
});

export const completePasswordReset = onCall(authSecrets, async (request) => {
  const resetToken = String(request.data?.resetToken ?? '');
  const newPassword = String(request.data?.newPassword ?? '');

  if (!resetToken) {
    throw new HttpsError('invalid-argument', 'Reset session expired.');
  }
  if (newPassword.length < 6) {
    throw new HttpsError('invalid-argument', 'Password must be at least 6 characters.');
  }

  const ref = db.collection(COLLECTIONS.passwordResetSessions).doc(resetToken);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Reset session expired. Start again.');
  }

  const data = snap.data()!;
  const now = Date.now();
  if (typeof data.expiresAtMs !== 'number' || data.expiresAtMs < now) {
    await ref.delete();
    throw new HttpsError('deadline-exceeded', 'Reset session expired. Start again.');
  }

  const uid = String(data.uid ?? '');
  if (!uid) {
    await ref.delete();
    throw new HttpsError('internal', 'Invalid reset session.');
  }

  await auth.updateUser(uid, { password: newPassword });
  await auth.revokeRefreshTokens(uid);
  await ref.delete();

  return { ok: true };
});

export const ensureUserProfile = onCall(
  { invoker: 'public', cors: true },
  async (request) => {
    const uid = requireAuthUid(request);
    await ensureUserProfileForUid(uid);
    return { ok: true };
  },
);
