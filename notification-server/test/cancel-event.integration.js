import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {after, before, beforeEach, test} from 'node:test';
import {initializeTestEnvironment, assertFails} from '@firebase/rules-unit-testing';
import {collection, deleteDoc, doc, getDoc, getDocs, increment, query, runTransaction,
  serverTimestamp, Timestamp, updateDoc, where, writeBatch} from 'firebase/firestore';

// Exercises the cancel-only SDK transaction and real Rules in an isolated demo
// project. Dart repository/viewmodel/widget behavior is tested separately.
let env;
const dbFor = (uid) => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const event = (extra = {}) => ({
  organizerId: 'owner', clubId: null, title: 'Cancel verification workshop', titleLower: 'cancel verification workshop',
  description: 'A practical campus workshop used only by emulator tests.', category: 'technology', locationName: 'Hall A',
  latitude: null, longitude: null, startAt: Timestamp.fromMillis(Date.now() + 86400000),
  endAt: Timestamp.fromMillis(Date.now() + 90000000), capacity: 20, registeredCount: 2,
  checkedInCount: 1, posterUrl: 'https://example.invalid/poster.png', status: 'published',
  createdAt: Timestamp.fromMillis(1700000000000), updatedAt: Timestamp.fromMillis(1700000000000), ...extra,
});
const registration = (uid, status = 'registered') => ({eventId: 'event-1', userId: uid, status,
  qrToken: `keep-${uid}`, registeredAt: Timestamp.now(), cancelledAt: null,
  checkedInAt: status === 'checkedIn' ? Timestamp.now() : null});

before(async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8087') {
    throw new Error('Cancel tests require the local Firestore Emulator at 127.0.0.1:8087. Production is forbidden.');
  }
  env = await initializeTestEnvironment({projectId: 'demo-campushub-uc039', firestore: {
    host: '127.0.0.1', port: 8087, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore(), batch = writeBatch(db);
    for (const [uid, role] of [['owner', 'organizer'], ['other', 'organizer'], ['student', 'student'],
      ['checked', 'student'], ['new-student', 'student'], ['admin', 'admin'], ['disabled', 'organizer']]) {
      batch.set(doc(db, 'users', uid), {uid, role, status: uid === 'disabled' ? 'disabled' : 'active'});
    }
    batch.set(doc(db, 'events/event-1'), event());
    batch.set(doc(db, 'registrations/event-1_student'), registration('student'));
    batch.set(doc(db, 'registrations/event-1_checked'), registration('checked', 'checkedIn'));
    await batch.commit();
  });
});

async function cancel(db, eventId = 'event-1', onFirstRead) {
  const ref = doc(db, 'events', eventId);
  let attempts = 0, writes = 0;
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    attempts++;
    if (!snap.exists()) throw new Error('event-not-found');
    if (attempts === 1 && onFirstRead) await onFirstRead();
    if (snap.data().status === 'cancelled') return;
    tx.update(ref, {status: 'cancelled', updatedAt: serverTimestamp()});
    writes++;
  });
  return {attempts, writes};
}

for (const uid of ['owner', 'admin']) {
  test(`${uid} cancellation is allowed and preserves all protected fields and registrations`, async () => {
    const db = dbFor(uid), ref = doc(db, 'events/event-1');
    const before = (await getDoc(ref)).data();
    const registrations = (await getDocs(query(collection(db, 'registrations'), where('eventId', '==', 'event-1'))))
      .docs.map((entry) => [entry.id, entry.data()]);
    await cancel(db);
    const after = (await getDoc(ref)).data();
    assert.equal(after.status, 'cancelled');
    assert.ok(after.updatedAt.toMillis() > before.updatedAt.toMillis());
    for (const key of Object.keys(before).filter((key) => !['status', 'updatedAt'].includes(key))) {
      assert.deepEqual(after[key], before[key], key);
    }
    assert.deepEqual((await getDocs(query(collection(db, 'registrations'), where('eventId', '==', 'event-1'))))
      .docs.map((entry) => [entry.id, entry.data()]), registrations);
  });
}
for (const uid of ['other', 'student', 'disabled', null]) {
  test(`${uid ?? 'guest'} cancellation is denied`, async () => {
    await assertFails(cancel(dbFor(uid)));
    assert.equal((await getDoc(doc(dbFor('owner'), 'events/event-1'))).data().status, 'published');
  });
}
for (const uid of ['owner', 'admin', 'student', 'other', null]) {
  test(`${uid ?? 'guest'} hard delete is denied`, async () => {
    await assertFails(deleteDoc(doc(dbFor(uid), 'events/event-1')));
    assert.ok((await getDoc(doc(dbFor('owner'), 'events/event-1'))).exists());
  });
}
for (const uid of ['owner', 'admin']) {
  test(`${uid} cannot combine cancellation with protected or editable field changes`, async () => {
    const ref = doc(dbFor(uid), 'events/event-1');
    for (const patch of [{organizerId: 'other'}, {registeredCount: 0}, {checkedInCount: 0},
      {posterUrl: null}, {createdAt: serverTimestamp()}, {clubId: 'spoof'},
      {title: 'Changed workshop', titleLower: 'changed workshop'}]) {
      await assertFails(updateDoc(ref, {status: 'cancelled', updatedAt: serverTimestamp(), ...patch}));
    }
  });
}
test('repeat cancel does not issue a write or change the cancellation timestamp', async () => {
  const db = dbFor('owner');
  await cancel(db);
  const before = (await getDoc(doc(db, 'events/event-1'))).data();
  assert.equal((await cancel(db)).writes, 0);
  assert.deepEqual((await getDoc(doc(db, 'events/event-1'))).data(), before);
});
for (const status of ['draft', 'finished']) {
  test(`existing policy permits ${status} cancellation`, async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'events/event-1'), {status});
    });
    await cancel(dbFor('owner'));
    assert.equal((await getDoc(doc(dbFor('owner'), 'events/event-1'))).data().status, 'cancelled');
  });
}
test('a missing event is not successful cancellation', async () => {
  await assert.rejects(cancel(dbFor('owner'), 'missing'));
  await env.withSecurityRulesDisabled(async (context) => {
    assert.equal((await getDoc(doc(context.firestore(), 'events/missing'))).exists(), false);
  });
});
test('cancelled event remains in owner history but disappears from Student discovery', async () => {
  await cancel(dbFor('owner'));
  const history = await getDocs(query(collection(dbFor('owner'), 'events'), where('organizerId', '==', 'owner')));
  assert.equal(history.size, 1);
  assert.equal(history.docs[0].data().status, 'cancelled');
  const discovery = await getDocs(query(collection(dbFor('student'), 'events'), where('status', '==', 'published')));
  assert.equal(discovery.size, 0);
});
test('Student cannot register after cancellation; existing registrations survive', async () => {
  // Positive control: the same authenticated student and atomic join payload
  // work on a published event. The negative case below is not a blanket deny.
  await env.withSecurityRulesDisabled(async (context) => {
    const batch = writeBatch(context.firestore());
    batch.set(doc(context.firestore(), 'events/join-control'), event({registeredCount: 0, checkedInCount: 0}));
    await batch.commit();
  });
  const controlDb = dbFor('new-student'), controlJoin = writeBatch(controlDb);
  controlJoin.set(doc(controlDb, 'registrations/join-control_new-student'), {
    ...registration('new-student'), eventId: 'join-control', registeredAt: serverTimestamp(),
  });
  controlJoin.update(doc(controlDb, 'events/join-control'), {registeredCount: increment(1), updatedAt: serverTimestamp()});
  await controlJoin.commit();
  await cancel(dbFor('owner'));
  const db = dbFor('new-student'), er = doc(db, 'events/event-1'), rr = doc(db, 'registrations/event-1_new-student');
  // Same atomic field changes used by the existing RegistrationRepository;
  // skip client preconditions to verify Rules enforce the cancelled status.
  const batch = writeBatch(db);
  batch.set(rr, {...registration('new-student'), registeredAt: serverTimestamp()});
  batch.update(er, {registeredCount: increment(1), updatedAt: serverTimestamp()});
  await assertFails(batch.commit());
  assert.equal((await getDoc(rr)).exists(), false);
  assert.ok((await getDoc(doc(dbFor('student'), 'registrations/event-1_student'))).exists());
  assert.ok((await getDoc(doc(dbFor('checked'), 'registrations/event-1_checked'))).exists());
});
test('transaction retries after a concurrent cancel and preserves the concurrent timestamp and counters', async () => {
  const db = dbFor('owner');
  const result = await cancel(db, 'event-1', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'events/event-1'), {status: 'cancelled',
        updatedAt: Timestamp.fromMillis(1800000000000), registeredCount: 3});
    });
  });
  assert.ok(result.attempts >= 2);
  const after = (await getDoc(doc(db, 'events/event-1'))).data();
  assert.equal(after.updatedAt.toMillis(), 1800000000000);
  assert.equal(after.registeredCount, 3);
});
