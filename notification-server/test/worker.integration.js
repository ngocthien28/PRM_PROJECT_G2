import {test, before, beforeEach, after} from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {createDispatcher} from '../src/worker.js';

let app, db;
before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Emulator is required');
  app = initializeApp({projectId: 'demo-campushub'}, 'worker-test');
  db = getFirestore(app);
});
after(async () => { await deleteApp(app); });
beforeEach(async () => {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-campushub/databases/(default)/documents`, {method: 'DELETE'});
  await db.doc('users/u1').set({status: 'active'});
  await db.doc('users/u1/device_tokens/device1').set({token: 'token1'});
  await db.doc('notifications/n1').set({
    userId: 'u1', title: 'Club joined', body: 'You joined Sport.',
    type: 'club_membership', membershipStatus: 'active', referenceId: 'c1',
    createdAt: Timestamp.now(), isRead: false, pushStatus: 'pending',
  });
});

test('persisted receipt prevents sending twice across worker restarts', async () => {
  const sent = [];
  const deliver = createDispatcher(db, async (message) => { sent.push(message); });
  await deliver(await db.doc('notifications/n1').get());
  assert.equal(sent.length, 1);
  assert.equal((await db.doc('notifications/n1').get()).data().pushStatus, 'sent');
  // Simulate restart after saving receipt but before final outbox status.
  await db.doc('notifications/n1').update({pushStatus: 'pending'});
  await createDispatcher(db, async (message) => { sent.push(message); })(await db.doc('notifications/n1').get());
  assert.equal(sent.length, 1);
  assert.equal((await db.doc('notifications/n1').get()).data().isRead, false);
});

test('transient send error stays queued and succeeds on retry', async () => {
  await createDispatcher(db, async () => { throw new Error('temporary'); })(await db.doc('notifications/n1').get());
  const failed = (await db.doc('notifications/n1').get()).data();
  assert.equal(failed.pushStatus, 'pending');
  assert.ok(failed.nextAttemptAt.toMillis() > Date.now());
  await db.doc('notifications/n1').update({nextAttemptAt: Timestamp.fromMillis(0)});
  let count = 0;
  await createDispatcher(db, async () => { count++; })(await db.doc('notifications/n1').get());
  assert.equal(count, 1);
  assert.equal((await db.doc('notifications/n1').get()).data().pushStatus, 'sent');
});

test('invalid token is removed without deleting inbox', async () => {
  await createDispatcher(db, async () => {
    throw Object.assign(new Error('unregistered'), {code: 'messaging/registration-token-not-registered'});
  })(await db.doc('notifications/n1').get());
  assert.equal((await db.doc('users/u1/device_tokens/device1').get()).exists, false);
  assert.equal((await db.doc('notifications/n1').get()).exists, true);
});

test('no tokens defers push until a device registers', async () => {
  await db.doc('users/u1/device_tokens/device1').delete();
  let sends = 0;
  await createDispatcher(db, async () => { sends++; })(await db.doc('notifications/n1').get());
  assert.equal(sends, 0);
  assert.equal((await db.doc('notifications/n1').get()).data().pushStatus, 'pending');
});
