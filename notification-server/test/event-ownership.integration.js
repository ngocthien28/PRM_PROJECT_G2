import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {test, before, beforeEach, after} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, collection, query, where, getDoc, getDocs, setDoc, updateDoc, deleteDoc,
  writeBatch, runTransaction, increment, serverTimestamp, Timestamp} from 'firebase/firestore';

let env;
const dbFor = (uid) => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const event = (owner = 'o1', extra = {}) => ({
  organizerId: owner, clubId: null, title: 'Campus workshop', titleLower: 'campus workshop',
  description: 'A practical workshop for CampusHub students.', category: 'technology', locationName: 'Hall A',
  latitude: null, longitude: null, startAt: Timestamp.fromMillis(Date.now() + 86400000),
  endAt: Timestamp.fromMillis(Date.now() + 90000000), capacity: 3, registeredCount: 0,
  checkedInCount: 0, posterUrl: null, status: 'published', createdAt: Timestamp.now(), updatedAt: Timestamp.now(), ...extra,
});
const registration = (eid, uid, extra = {}) => ({eventId: eid, userId: uid, status: 'registered',
  qrToken: `token-${eid}-${uid}`, registeredAt: Timestamp.now(), cancelledAt: null, checkedInAt: null, ...extra});
const createPayload = (owner) => event(owner, {createdAt: serverTimestamp(), updatedAt: serverTimestamp()});
const edit = (db, patch = {}) => updateDoc(doc(db, 'events/e1'), {title: 'Edited workshop', titleLower: 'edited workshop', updatedAt: serverTimestamp(), ...patch});

before(async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8087') {
    throw new Error('Run with the local Firestore Emulator at 127.0.0.1:8087. Production is forbidden.');
  }
  const projectId = process.env.CAMPUSHUB_RULES_TEST_PROJECT || 'demo-campushub';
  if (!projectId.startsWith('demo-')) throw new Error('Rules tests require a demo project.');
  env = await initializeTestEnvironment({projectId, firestore: {
    host: '127.0.0.1', port: 8087, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const batch = writeBatch(db);
    for (const [uid, role] of [['s1', 'student'], ['s2', 'student'], ['s3', 'student'], ['o1', 'organizer'], ['o2', 'organizer'], ['admin', 'admin'], ['disabled', 'organizer']]) {
      batch.set(doc(db, 'users', uid), {uid, role, status: uid === 'disabled' ? 'disabled' : 'active'});
    }
    batch.set(doc(db, 'events/e1'), event('o1', {registeredCount: 1}));
    batch.set(doc(db, 'events/e2'), event('o2', {registeredCount: 1}));
    batch.set(doc(db, 'events/last-slot'), event('o1', {capacity: 1}));
    batch.set(doc(db, 'events/draft'), event('o1', {status: 'draft'}));
    batch.set(doc(db, 'events/cancelled'), event('o1', {status: 'cancelled'}));
    batch.set(doc(db, 'events/full'), event('o1', {capacity: 1, registeredCount: 1}));
    batch.set(doc(db, 'events/past'), event('o1', {startAt: Timestamp.fromMillis(Date.now() - 60000)}));
    batch.set(doc(db, 'registrations/e1_s1'), registration('e1', 's1'));
    batch.set(doc(db, 'registrations/e2_s2'), registration('e2', 's2'));
    await batch.commit();
  });
});

// SDK transactions intentionally perform the same reads/writes as the Dart
// repository. Client-side validation is omitted here to challenge Rules.
async function join(db, eid = 'e1', uid = 's2', patch = {}) {
  return runTransaction(db, async (tx) => {
    const er = doc(db, 'events', eid), rr = doc(db, 'registrations', `${eid}_${uid}`);
    await tx.get(er); await tx.get(rr);
    tx.set(rr, registration(eid, uid, {registeredAt: serverTimestamp()}));
    tx.update(er, {registeredCount: increment(1), updatedAt: serverTimestamp(), ...patch});
  });
}
async function cancel(db, eid = 'e1', uid = 's1') {
  return runTransaction(db, async (tx) => {
    const er = doc(db, 'events', eid), rr = doc(db, 'registrations', `${eid}_${uid}`);
    await tx.get(rr); await tx.get(er);
    tx.update(rr, {status: 'cancelled', cancelledAt: serverTimestamp()});
    tx.update(er, {registeredCount: increment(-1), updatedAt: serverTimestamp()});
  });
}
async function checkIn(db, eid = 'e1', uid = 's1', patch = {}) {
  return runTransaction(db, async (tx) => {
    const rid = `${eid}_${uid}`, rr = doc(db, 'registrations', rid), er = doc(db, 'events', eid);
    await tx.get(rr); await tx.get(er);
    tx.update(rr, {status: 'checkedIn', checkedInAt: serverTimestamp()});
    tx.update(er, {checkedInCount: increment(1), updatedAt: serverTimestamp(), lastCheckInRegistrationId: rid, ...patch});
  });
}

for (const [uid, allowed] of [['s1', false], ['o1', true], ['admin', true], [null, false], ['disabled', false]]) {
  test(`create ${uid ?? 'guest'}: ${allowed ? 'ALLOW' : 'DENY'}`, async () => {
    const op = setDoc(doc(dbFor(uid), 'events/new'), createPayload(uid ?? 'o1'));
    await (allowed ? assertSucceeds(op) : assertFails(op));
  });
}
test('organizer cannot spoof the creator', async () => { await assertFails(setDoc(doc(dbFor('o1'), 'events/new'), createPayload('o2'))); });
test('create rejects protected fields, past start and invalid schema', async () => {
  for (const patch of [{registeredCount: 1}, {checkedInCount: 1}, {unexpected: true}, {title: '  '}, {titleLower: 'wrong'}, {startAt: Timestamp.fromMillis(Date.now() - 1000)}, {lastCheckInRegistrationId: 'e1_s1'}]) {
    await assertFails(setDoc(doc(dbFor('o1'), 'events/new'), {...createPayload('o1'), ...patch}));
  }
});
for (const [uid, allowed] of [['o1', true], ['o2', false], ['s1', false], ['admin', true], [null, false], ['disabled', false]]) {
  test(`management update ${uid ?? 'guest'}: ${allowed ? 'ALLOW' : 'DENY'}`, async () => {
    await (allowed ? assertSucceeds(edit(dbFor(uid))) : assertFails(edit(dbFor(uid))));
  });
  test(`event cancel ${uid ?? 'guest'}: ${allowed ? 'ALLOW' : 'DENY'}`, async () => {
    const op = updateDoc(doc(dbFor(uid), 'events/e1'), {status: 'cancelled', updatedAt: serverTimestamp()});
    await (allowed ? assertSucceeds(op) : assertFails(op));
  });
}
for (const uid of ['s1', 'o1', 'o2', 'admin', null]) {
  test(`hard delete ${uid ?? 'guest'}: DENY`, async () => { await assertFails(deleteDoc(doc(dbFor(uid), 'events/e1'))); });
}
for (const uid of ['o1', 'admin']) {
  test(`${uid} cannot transfer ownership or directly alter protected data`, async () => {
    for (const patch of [{organizerId: 'o2'}, {createdAt: serverTimestamp()}, {registeredCount: 2}, {checkedInCount: 1},
      {posterUrl: 'file:///spoof.png'}, {lastCheckInRegistrationId: 'e1_s1'}, {capacity: 0}, {status: 'draft'}]) {
      await assertFails(edit(dbFor(uid), patch));
    }
  });
}
test('Student claim admin cannot override the trusted student profile', async () => {
  const db = env.authenticatedContext('s1', {role: 'admin', admin: true}).firestore();
  await assertFails(edit(db));
});
test('role escalation and privileged profile creation are denied', async () => {
  await assertFails(updateDoc(doc(dbFor('s1'), 'users/s1'), {role: 'organizer'}));
  await assertFails(updateDoc(doc(dbFor('o1'), 'users/o1'), {role: 'admin'}));
  await assertFails(deleteDoc(doc(dbFor('o1'), 'users/o1')));
  const data = {uid: 'new', email: 'new@example.invalid', displayName: 'New User', avatarUrl: null,
    role: 'admin', status: 'active', createdAt: serverTimestamp(), updatedAt: serverTimestamp()};
  await assertFails(setDoc(doc(dbFor('new'), 'users/new'), data));
  await assertSucceeds(setDoc(doc(dbFor('new'), 'users/new'), {...data, role: 'student'}));
});
test('published discovery and owner-scoped management queries remain usable', async () => {
  await assertSucceeds(getDocs(query(collection(dbFor('s1'), 'events'), where('status', '==', 'published'))));
  await assertFails(getDocs(collection(dbFor('s1'), 'events')));
  await assertSucceeds(getDocs(query(collection(dbFor('o1'), 'events'), where('organizerId', '==', 'o1'))));
  await assertSucceeds(getDocs(collection(dbFor('admin'), 'events')));
});
test('draft remains private to owner/admin', async () => {
  await assertFails(getDoc(doc(dbFor('s1'), 'events/draft')));
  await assertFails(getDoc(doc(dbFor('o2'), 'events/draft')));
  await assertSucceeds(getDoc(doc(dbFor('o1'), 'events/draft')));
  await assertSucceeds(getDoc(doc(dbFor('admin'), 'events/draft')));
});
for (const [uid, allowed] of [['s1', true], ['s2', false], ['o1', true], ['o2', false], ['admin', true], [null, false]]) {
  test(`participant e1_s1 read ${uid ?? 'guest'}: ${allowed ? 'ALLOW' : 'DENY'}`, async () => {
    const op = getDoc(doc(dbFor(uid), 'registrations/e1_s1'));
    await (allowed ? assertSucceeds(op) : assertFails(op));
  });
}
test('participant query is owner-scoped; all-registration query requires admin', async () => {
  const own = query(collection(dbFor('o1'), 'registrations'), where('eventId', '==', 'e1'), where('status', '==', 'registered'));
  await assertSucceeds(getDocs(own));
  await assertFails(getDocs(query(collection(dbFor('o1'), 'registrations'), where('eventId', '==', 'e2'))));
  await assertFails(getDocs(collection(dbFor('o1'), 'registrations')));
  await assertFails(getDocs(collection(dbFor('s1'), 'registrations')));
  await assertSucceeds(getDocs(query(collection(dbFor('s1'), 'registrations'), where('userId', '==', 's1'))));
  await assertSucceeds(getDocs(collection(dbFor('admin'), 'registrations')));
});
test('join transaction commits registration and exactly one counter increment', async () => {
  await assertSucceeds(join(dbFor('s2')));
  assert.equal((await getDoc(doc(dbFor('s2'), 'events/e1'))).data().registeredCount, 2);
  assert.equal((await getDoc(doc(dbFor('s2'), 'registrations/e1_s2'))).data().status, 'registered');
});
for (const eid of ['full', 'past', 'cancelled', 'draft']) {
  test(`join ${eid}: DENY`, async () => { await assertFails(join(dbFor('s2'), eid)); });
}
test('duplicate join and checked-in rejoin are denied', async () => {
  await assertFails(join(dbFor('s1'), 'e1', 's1'));
  await assertSucceeds(checkIn(dbFor('o1')));
  await assertFails(join(dbFor('s1'), 'e1', 's1'));
});
test('counter alone, registration alone and join+title edits are denied', async () => {
  await assertFails(updateDoc(doc(dbFor('s2'), 'events/e1'), {registeredCount: increment(1), updatedAt: serverTimestamp()}));
  await assertFails(setDoc(doc(dbFor('s2'), 'registrations/e1_s2'), registration('e1', 's2', {registeredAt: serverTimestamp()})));
  await assertFails(join(dbFor('s2'), 'e1', 's2', {title: 'Forged', titleLower: 'forged'}));
  await assertFails(join(dbFor('s2'), 'e1', 's2', {registeredCount: increment(2)}));
});
test('cannot forge registration user/event/ID or reuse another user ticket', async () => {
  const db = dbFor('s2');
  for (const [rid, data] of [['e1_s1', registration('e1', 's1')], ['arbitrary', registration('e1', 's2')], ['e1_s2', registration('e2', 's2')]]) {
    const batch = writeBatch(db);
    batch.set(doc(db, 'registrations', rid), {...data, registeredAt: serverTimestamp()});
    batch.update(doc(db, 'events/e1'), {registeredCount: increment(1), updatedAt: serverTimestamp()});
    await assertFails(batch.commit());
  }
});
test('cancel and rejoin preserve correct counter and reject duplicate cancellation', async () => {
  await assertSucceeds(cancel(dbFor('s1')));
  assert.equal((await getDoc(doc(dbFor('s1'), 'events/e1'))).data().registeredCount, 0);
  await assertFails(cancel(dbFor('s1')));
  await assertSucceeds(join(dbFor('s1'), 'e1', 's1'));
  assert.equal((await getDoc(doc(dbFor('s1'), 'events/e1'))).data().registeredCount, 1);
});

test('demo ticket cancellation stays within the rules expression budget', async () => {
  const eid = 'demo_event_outdoor_badminton_04', uid = 'demo_student_01';
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', uid), {uid, role: 'student', status: 'active'});
    await setDoc(doc(db, 'events', eid), event('o1', {registeredCount: 1}));
    await setDoc(doc(db, 'registrations', `${eid}_${uid}`), registration(eid, uid));
  });
  await assertSucceeds(cancel(dbFor(uid), eid, uid));
  assert.equal((await getDoc(doc(dbFor(uid), 'events', eid))).data().registeredCount, 0);
});

test('ticket history uses get permission without exposing unpublished event lists', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'events/finished'), event('o1', {status: 'finished', registeredCount: 1, checkedInCount: 1}));
    await setDoc(doc(db, 'registrations/finished_s1'), registration('finished', 's1', {status: 'checkedIn', checkedInAt: Timestamp.now()}));
  });
  await assertSucceeds(getDoc(doc(dbFor('s1'), 'events/finished')));
  await assertFails(getDoc(doc(dbFor('s2'), 'events/finished')));
  await assertFails(getDocs(query(collection(dbFor('s1'), 'events'), where('status', '==', 'finished'))));
});
test('cancel without counter, wrong-user cancel and late cancel are denied', async () => {
  await assertFails(updateDoc(doc(dbFor('s1'), 'registrations/e1_s1'), {status: 'cancelled', cancelledAt: serverTimestamp()}));
  await assertFails(cancel(dbFor('s2')));
  await env.withSecurityRulesDisabled(async (c) => updateDoc(doc(c.firestore(), 'events/e1'), {startAt: Timestamp.fromMillis(Date.now() + 3600000)}));
  await assertFails(cancel(dbFor('s1')));
});
for (const [uid, allowed] of [['o1', true], ['admin', true], ['o2', false], ['s1', false], [null, false]]) {
  test(`check-in ${uid ?? 'guest'}: ${allowed ? 'ALLOW' : 'DENY'}`, async () => {
    await (allowed ? assertSucceeds(checkIn(dbFor(uid))) : assertFails(checkIn(dbFor(uid))));
  });
}
test('check-in increments once; duplicate, arbitrary count and detached check-in denied', async () => {
  const db = dbFor('o1');
  await assertFails(updateDoc(doc(db, 'registrations/e1_s1'), {status: 'checkedIn', checkedInAt: serverTimestamp()}));
  await assertFails(checkIn(db, 'e1', 's1', {checkedInCount: increment(2)}));
  await assertFails(checkIn(db, 'e1', 's1', {lastCheckInRegistrationId: 'e2_s2'}));
  await assertSucceeds(checkIn(db));
  assert.equal((await getDoc(doc(db, 'events/e1'))).data().checkedInCount, 1);
  await assertFails(checkIn(db));
  await assertFails(cancel(dbFor('s1')));
  await assertSucceeds(edit(db));
  assert.equal((await getDoc(doc(db, 'events/e1'))).data().lastCheckInRegistrationId, 'e1_s1');
});
test('two check-ins cannot share one marker or one counter increment', async () => {
  await assertSucceeds(join(dbFor('s2')));
  const db = dbFor('o1'), batch = writeBatch(db);
  for (const rid of ['e1_s1', 'e1_s2']) batch.update(doc(db, 'registrations', rid), {status: 'checkedIn', checkedInAt: serverTimestamp()});
  batch.update(doc(db, 'events/e1'), {checkedInCount: increment(1), updatedAt: serverTimestamp(), lastCheckInRegistrationId: 'e1_s1'});
  await assertFails(batch.commit());
});
test('concurrent joins compete for last slot without overbooking', async () => {
  const results = await Promise.allSettled([join(dbFor('s2'), 'last-slot', 's2'), join(dbFor('s3'), 'last-slot', 's3')]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal(results.filter((r) => r.status === 'rejected').length, 1);
  assert.equal((await getDoc(doc(dbFor('s2'), 'events/last-slot'))).data().registeredCount, 1);
});
