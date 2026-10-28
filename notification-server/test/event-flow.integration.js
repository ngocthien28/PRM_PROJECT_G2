import assert from 'node:assert/strict';
import {after, before, beforeEach, test} from 'node:test';
import {assertFails} from '@firebase/rules-unit-testing';
import {doc, setDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp, writeBatch,
  disableNetwork, enableNetwork, getDocsFromServer, collection} from 'firebase/firestore';
import {environment, event, feed, join, checkIn, summary} from './helpers/event-flow.mjs';

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
before(async () => { env = await environment(); });
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const batch = writeBatch(ctx.firestore());
    for (const [uid, role] of [['owner','organizer'],['other','organizer'],['s1','student'],['s2','student'],['s3','student']]) {
      batch.set(doc(ctx.firestore(), 'users', uid), {uid, role, status: 'active'});
    }
    batch.set(doc(ctx.firestore(), 'events/draft'), event('owner', {status: 'draft'}));
    batch.set(doc(ctx.firestore(), 'events/cancelled'), event('owner', {status: 'cancelled'}));
    batch.set(doc(ctx.firestore(), 'events/past'), event('owner', {
      startAt: Timestamp.fromMillis(Date.now() - 7200000), endAt: Timestamp.fromMillis(Date.now() - 3600000)}));
    await batch.commit();
  });
});
async function create(patch = {}) { await setDoc(doc(db('owner'), 'events/flow'), event('owner', patch)); }

test('UC-046 create/edit feed, registration, check-in, summary and soft cancel persist under real Rules', async () => {
  await create();
  assert.deepEqual((await feed(db('s1'))).docs.map((e) => e.id), ['flow']);
  await updateDoc(doc(db('owner'), 'events/flow'), {title: 'Updated campus workshop', titleLower: 'updated campus workshop',
    locationName: 'Hall B', category: 'workshop', updatedAt: serverTimestamp()});
  const refreshed = (await feed(db('s1'))).docs[0].data();
  assert.equal(refreshed.title, 'Updated campus workshop'); assert.equal(refreshed.locationName, 'Hall B');
  await join(db('s1'), 'flow', 's1');
  await assert.rejects(join(db('s1'), 'flow', 's1'), /duplicate-registration/);
  let s = await summary(db('owner'), 'flow');
  assert.equal(s.registeredCount, 1); assert.equal(s.participants.length, 1); assert.equal(s.notYetCheckedIn, 1);
  await checkIn(db('owner'), 'flow', 's1');
  await assert.rejects(checkIn(db('owner'), 'flow', 's1'), /duplicate-check-in/);
  s = await summary(db('owner'), 'flow');
  assert.equal(s.checkedInCount, 1); assert.equal(s.rate, 100); assert.equal(s.notYetCheckedIn, 0);
  assert.equal(s.participants[0].status, 'checkedIn'); assert.ok(s.participants[0].checkedInAt);
  await updateDoc(doc(db('owner'), 'events/flow'), {status: 'cancelled', updatedAt: serverTimestamp()});
  assert.equal((await feed(db('s2'))).size, 0);
  // A non-participant cannot even read a cancelled event under the existing
  // Rules. The server rejects this attempt before the client status guard.
  await assert.rejects(join(db('s2'), 'flow', 's2'), {code: 'permission-denied'});
  assert.equal((await summary(db('owner'), 'flow')).participants.length, 1);
});
test('UC-046 owner-only participant access; students cannot edit counters or check in', async () => {
  await create(); await join(db('s1'), 'flow', 's1');
  await assertFails(updateDoc(doc(db('other'), 'events/flow'), {locationName: 'Spoof', updatedAt: serverTimestamp()}));
  await assertFails(summary(db('other'), 'flow'));
  await assertFails(updateDoc(doc(db('s1'), 'events/flow'), {checkedInCount: 1, updatedAt: serverTimestamp()}));
  await assertFails(checkIn(db('s1'), 'flow', 's1'));
  await assertFails(deleteDoc(doc(db('owner'), 'events/flow')));
  const s = await summary(db('owner'), 'flow'); assert.equal(s.checkedInCount, 0);
});
test('UC-046 concurrent last-slot registration admits exactly one student', async () => {
  await create({capacity: 1});
  const results = await Promise.allSettled([join(db('s1'), 'flow', 's1'), join(db('s2'), 'flow', 's2')]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  const s = await summary(db('owner'), 'flow');
  assert.equal(s.registeredCount, 1); assert.equal(s.participants.length, 1); assert.equal(s.checkedInCount, 0);
});
test('UC-046 concurrent editable-field update and join preserve counters', async () => {
  await create();
  await Promise.all([join(db('s1'), 'flow', 's1'), updateDoc(doc(db('owner'), 'events/flow'), {
    locationName: 'Concurrent Hall', updatedAt: serverTimestamp()})]);
  const s = await summary(db('owner'), 'flow');
  assert.equal(s.locationName, 'Concurrent Hall'); assert.equal(s.registeredCount, 1);
  assert.equal(s.participants.length, 1); assert.equal(s.checkedInCount, 0);
});
test('UC-046 server-only feed reports network failure instead of false success', async () => {
  await create();
  const offline = db('s1');
  await disableNetwork(offline);
  try {
    await assert.rejects(getDocsFromServer(collection(offline, 'events')), {code: 'unavailable'});
  } finally { await enableNetwork(offline); }
  assert.equal((await feed(offline)).docs.length, 1);
});
