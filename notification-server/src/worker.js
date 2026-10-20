import {Timestamp, FieldValue} from 'firebase-admin/firestore';
import {buildMessage} from './message.js';

export function createDispatcher(db, send) {
  return async function deliver(document) {
    const now = Date.now();
    const claimed = await db.runTransaction(async (tx) => {
      const fresh = await tx.get(document.ref);
      const item = fresh.data();
      if (!item || !['pending', 'processing'].includes(item.pushStatus)) return null;
      if ((item.nextAttemptAt?.toMillis() ?? 0) > now) return null;
      tx.update(document.ref, {
        pushStatus: 'processing', nextAttemptAt: Timestamp.fromMillis(now + 120000),
        pushAttempts: FieldValue.increment(1),
      });
      return item;
    });
    if (!claimed) return;
    const finish = (pushStatus, extra = {}) => document.ref.update({
      pushStatus, ...extra, nextAttemptAt: FieldValue.delete(),
    });
    try {
      const user = await db.collection('users').doc(claimed.userId).get();
      if (user.data()?.status !== 'active') { await finish('skipped'); return; }
      if (Date.now() - claimed.createdAt.toMillis() > 86400000) {
        await finish('expired'); return;
      }
      const tokens = await user.ref.collection('device_tokens').get();
      if (tokens.empty) {
        await document.ref.update({pushStatus: 'pending',
          nextAttemptAt: Timestamp.fromMillis(Date.now() + 30000)});
        return;
      }
      for (const device of tokens.docs) {
        const receipt = document.ref.collection('deliveries').doc(device.id);
        if ((await receipt.get()).exists) continue;
        try {
          await send(buildMessage(document.id, claimed, device.data().token));
          await receipt.set({sentAt: FieldValue.serverTimestamp()});
        } catch (error) {
          if (['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(error.code)) {
            await device.ref.delete();
          } else { throw error; }
        }
      }
      await finish('sent', {sentAt: FieldValue.serverTimestamp()});
      console.info(`Delivered notification ${document.id}`);
    } catch (error) {
      console.error(`Delivery failed (${document.id}): ${error.code || error.name}`);
      await document.ref.update({pushStatus: 'pending',
        nextAttemptAt: Timestamp.fromMillis(Date.now() + 30000)});
    }
  };
}
