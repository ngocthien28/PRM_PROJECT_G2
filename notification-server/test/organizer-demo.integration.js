import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {after, before, test} from 'node:test';
import {initializeApp, deleteApp} from 'firebase/app';
import {getAuth, connectAuthEmulator, signInWithEmailAndPassword} from 'firebase/auth';
import {getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc, updateDoc, deleteDoc,
  serverTimestamp, collection, getDocs, query, where} from 'firebase/firestore';
import {getStorage, connectStorageEmulator, ref, uploadBytes, getDownloadURL, getBytes} from 'firebase/storage';
import {runSeed} from '../../firebase/seed/seed.mjs';
import {getSeedData} from '../../firebase/seed/seed_data.mjs';
import {environment, event, feed, join, checkIn, summary} from './helpers/event-flow.mjs';

let env;
const clients = new Map();
const fixture = new Uint8Array(readFileSync(new URL('../../firebase/fixtures/organizer-poster.png', import.meta.url)));
before(async () => {
  if (process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099') throw new Error('Auth Emulator required.');
  env = await environment(true);
  await env.clearFirestore(); await env.clearStorage();
});
after(async () => {
  await Promise.all([...clients.values()].map(({app}) => deleteApp(app)));
  await env?.cleanup();
});
async function login(user) {
  const app = initializeApp({apiKey: 'demo-api-key', projectId: 'demo-campushub',
    storageBucket: 'demo-campushub.appspot.com'}, `uc047-${user.uid}`);
  const auth = getAuth(app); connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  const firestore = getFirestore(app); connectFirestoreEmulator(firestore, '127.0.0.1', 8087);
  const storage = getStorage(app); connectStorageEmulator(storage, '127.0.0.1', 9199);
  const client = {app, auth, firestore, storage}; clients.set(user.uid, client);
  const credential = await signInWithEmailAndPassword(auth, user.email, user.password);
  assert.equal(credential.user.uid, user.uid);
  const profile = (await getDoc(doc(firestore, 'users', user.uid))).data();
  assert.equal(profile.uid, user.uid); assert.equal(profile.role, user.role);
  return client;
}

test('UC-047 seeded accounts, rerun consistency and complete authenticated poster demo', async () => {
  const fixedNow = new Date();
  const first = await runSeed({now: fixedNow});
  assert.equal(first.usersCount, 5); assert.equal(first.eventsCount, 10);
  assert.equal(first.registrationsCount, 9); assert.equal(first.posterCount, 1);
  const second = await runSeed({now: fixedNow}); assert.deepEqual(second, first);
  const users = getSeedData(fixedNow).users;
  for (const user of users) await login(user);
  const owner = clients.get('demo_organizer_01'), other = clients.get('demo_organizer_02');
  const student = clients.get('demo_student_01'), student2 = clients.get('demo_student_02');
  const admin = clients.get('demo_admin_01');
  assert.equal((await getDocs(collection(admin.firestore, 'events'))).size, 10);
  assert.equal((await getDocs(collection(admin.firestore, 'registrations'))).size, 9);
  for (const snapshot of (await getDocs(collection(admin.firestore, 'events'))).docs) {
    const data = snapshot.data();
    const registrations = (await getDocs(query(collection(admin.firestore, 'registrations'), where('eventId', '==', snapshot.id))))
      .docs.map((r) => r.data());
    assert.equal(data.registeredCount, registrations.filter((r) => r.status !== 'cancelled').length);
    assert.equal(data.checkedInCount, registrations.filter((r) => r.status === 'checkedIn').length);
    assert.ok(data.checkedInCount <= data.registeredCount && data.registeredCount <= data.capacity);
  }
  const seeded = (await getDoc(doc(student.firestore, 'events/demo_event_tech_flutter_01'))).data();
  const downloadedSeed = await fetch(seeded.posterUrl);
  assert.equal(downloadedSeed.status, 200); assert.deepEqual(new Uint8Array(await downloadedSeed.arrayBuffer()), fixture);

  const managed = await getDocs(query(collection(owner.firestore, 'events'), where('organizerId', '==', 'demo_organizer_01')));
  assert.ok(managed.size > 0); assert.ok(managed.docs.every((d) => d.data().organizerId === 'demo_organizer_01'));
  const eid = 'uc047-created-poster-event', er = doc(owner.firestore, 'events', eid);
  await setDoc(er, event('demo_organizer_01'));
  const object = ref(owner.storage, `events/${eid}/demo-poster.png`);
  await uploadBytes(object, fixture, {contentType: 'image/png'});
  const url = await getDownloadURL(object);
  await updateDoc(er, {posterUrl: url, updatedAt: serverTimestamp()});
  await updateDoc(er, {title: 'GH final organizer demo', titleLower: 'gh final organizer demo',
    locationName: 'Demo Hall B', updatedAt: serverTimestamp()});
  const visible = (await feed(student.firestore)).docs.find((d) => d.id === eid);
  assert.ok(visible); assert.equal(visible.data().title, 'GH final organizer demo');
  assert.equal(visible.data().locationName, 'Demo Hall B'); assert.equal(visible.data().posterUrl, url);
  assert.deepEqual(new Uint8Array(await getBytes(ref(student.storage, `events/${eid}/demo-poster.png`))), fixture);
  await join(student.firestore, eid, 'demo_student_01');
  await assert.rejects(join(student.firestore, eid, 'demo_student_01'), /duplicate-registration/);
  await checkIn(owner.firestore, eid, 'demo_student_01');
  await assert.rejects(checkIn(owner.firestore, eid, 'demo_student_01'), /duplicate-check-in/);
  const s = await summary(owner.firestore, eid);
  assert.equal(s.registeredCount, 1); assert.equal(s.checkedInCount, 1);
  assert.equal(s.notYetCheckedIn, 0); assert.equal(s.rate, 100);
  await assert.rejects(summary(other.firestore, eid), /permission/i);
  await assert.rejects(updateDoc(doc(other.firestore, 'events', eid), {locationName: 'Spoof', updatedAt: serverTimestamp()}), /permission/i);
  await assert.rejects(setDoc(doc(student.firestore, 'events/illegal'), event('demo_student_01')), /permission/i);
  await assert.rejects(updateDoc(doc(student.firestore, 'events', eid), {registeredCount: 0, updatedAt: serverTimestamp()}), /permission/i);
  await assert.rejects(deleteDoc(er), /permission/i);
  await updateDoc(er, {status: 'cancelled', updatedAt: serverTimestamp()});
  assert.ok(!(await feed(student2.firestore)).docs.some((d) => d.id === eid));
  await assert.rejects(join(student2.firestore, eid, 'demo_student_02'), {code: 'permission-denied'});
  const history = await summary(owner.firestore, eid);
  assert.equal(history.status, 'cancelled'); assert.equal(history.participants.length, 1);
});
