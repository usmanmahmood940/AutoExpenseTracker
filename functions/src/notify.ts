import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { db } from './admin';
import { COLLECTIONS, type Transaction } from './schema';

/**
 * Sends an FCM data+notification push when a new transaction is created,
 * if the user has registered fcmTokens on their user document.
 */
export const onUserTransactionCreatedNotify = onDocumentCreated(
  {
    document: 'users/{userId}/transactions/{transactionId}',
    region: 'asia-south1',
  },
  async (event) => {
    const uid = event.params.userId;
    const data = event.data?.data() as Transaction | undefined;
    if (!data || data.status === 'deleted') {
      return;
    }

    const userSnap = await db.collection(COLLECTIONS.users).doc(uid).get();
    const tokens = (userSnap.data()?.fcmTokens as string[] | undefined) ?? [];
    if (tokens.length === 0) {
      return;
    }

    const amount = Number(data.amount) || 0;
    const sign = data.type === 'credit' ? '+' : '-';
    const title = data.merchant || 'New transaction';
    const body = `${sign}${data.currency || 'PKR'} ${amount.toFixed(2)} · ${data.category}`;

    const messaging = getMessaging();
    await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: {
        transactionId: event.params.transactionId,
        type: 'transaction_created',
      },
    });
  },
);
