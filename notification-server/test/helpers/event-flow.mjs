import {randomUUID} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {collection, doc, getDoc, getDocs, increment, query, runTransaction,
  serverTimestamp, Timestamp, where} from 'firebase/firestore';

export async function environment(storage = false) {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8087'
    || (storage && process.env.FIREBASE_STORAGE_EMULATOR_HOST !== '127.0.0.1:9199')) {
    throw new Error('Local Firestore/Storage emulators are required. Production is forbidden.');
  }
  return initializeTestEnvironment({projectId: 'demo-campushub', firestore: {
    host: '127.0.0.1', port: 8087, rules: readFileSync(new URL('../../../firestore.rules', import.meta.url), 'utf8'),
  }, ...(storage ? {storage: {host: '127.0.0.1', port: 9199,
    rules: readFileSync(new URL('../../../storage.rules', import.meta.url), 'utf8')}} : {})});
}
export const event = (owner, patch = {}) => ({
  organizerId: owner, clubId: null, title: 'Campus integration workshop', titleLower: 'campus integration workshop',
  description: 'A practical campus workshop for integration and demo verification.',
  category: 'technology', locationName: 'Hall A', latitude: null, longitude: null,
  startAt: Timestamp.fromMillis(Date.now() + 86400000), endAt: Timestamp.fromMillis(Date.now() + 93600000),
  capacity: 2, registeredCount: 0, checkedInCount: 0, posterUrl: null,
  status: 'published', createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...patch,
});
export const feed = (db) => getDocs(query(collection(db, 'events'), where('status', '==', 'published'),
  where('startAt', '>=', Timestamp.now())));
export const summary = async (db, eid) => {
  const data = (await getDoc(doc(db, 'events', eid))).data();
  const participants = await getDocs(query(collection(db, 'registrations'), where('eventId', '==', eid)));
  return {...data, participants: participants.docs.map((entry) => entry.data()),
    notYetCheckedIn: data.registeredCount - data.checkedInCount,
    rate: data.registeredCount ? data.checkedInCount / data.registeredCount * 100 : 0};
};
// SDK transaction shapes mirror RegistrationRepository; Dart invocation and QR
// validation are exercised in event_flow_uc046_test.dart, not by these helpers.
export async function join(db, eid, uid) {
  const qrToken = randomUUID();
  return runTransaction(db, async (tx) => {
    const er = doc(db, 'events', eid), rr = doc(db, 'registrations', `${eid}_${uid}`);
    const e = await tx.get(er); const r = await tx.get(rr);
    if (r.exists() && r.data().status !== 'cancelled') throw new Error('duplicate-registration');
    if (e.data().status !== 'published' || e.data().registeredCount >= e.data().capacity) throw new Error('closed-or-full');
    tx.set(rr, {eventId: eid, userId: uid, status: 'registered', qrToken,
      registeredAt: serverTimestamp(), cancelledAt: null, checkedInAt: null});
    tx.update(er, {registeredCount: increment(1), updatedAt: serverTimestamp()});
    return `${eid}_${uid}`;
  });
}
export async function checkIn(db, eid, uid) {
  return runTransaction(db, async (tx) => {
    const rid = `${eid}_${uid}`, rr = doc(db, 'registrations', rid), er = doc(db, 'events', eid);
    const r = await tx.get(rr); await tx.get(er);
    if (r.data().status !== 'registered') throw new Error('duplicate-check-in');
    tx.update(rr, {status: 'checkedIn', checkedInAt: serverTimestamp()});
    tx.update(er, {checkedInCount: increment(1), updatedAt: serverTimestamp(), lastCheckInRegistrationId: rid});
  });
}
