import {initializeApp, applicationDefault} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {createDispatcher} from './worker.js';

const projectId = process.env.GOOGLE_CLOUD_PROJECT || 'campushub-prm-g2';
initializeApp({credential: applicationDefault(), projectId});
const db = getFirestore();
const deliver = createDispatcher(db, (message) => getMessaging().send(message));
let stopped = false;
process.on('SIGINT', () => { stopped = true; });
process.on('SIGTERM', () => { stopped = true; });

console.info(`CampusHub notification worker: ${projectId}`);
while (!stopped) {
  try {
    const pending = await db.collection('notifications')
      .where('pushStatus', 'in', ['pending', 'processing']).get();
    for (const document of pending.docs) {
      if (stopped) break;
      await deliver(document);
    }
  } catch (error) {
    console.error(`Worker error: ${error.code || error.name}. Check credentials and setup.`);
  }
  if (!stopped) await new Promise((resolve) => setTimeout(resolve, 5000));
}
