import {readFileSync} from 'node:fs';
import {test, before, after, beforeEach} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {ref, uploadBytes, deleteObject, getBytes} from 'firebase/storage';
import {doc, setDoc} from 'firebase/firestore';

let env;
const storageFor = (uid, role = 'student') => {
  if (!uid) return env.unauthenticatedContext().storage();
  return env.authenticatedContext(uid, {role}).storage();
};

const samplePng = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]); // PNG header
const sampleJpeg = new Uint8Array([255, 216, 255, 224]); // JPEG header
const samplePdf = new Uint8Array([37, 80, 68, 70]); // %PDF
const oversizeBytes = new Uint8Array(6 * 1024 * 1024); // 6MB > 5MB limit

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-campushub',
    firestore: {
      host: '127.0.0.1',
      port: 8087,
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
    storage: {
      host: '127.0.0.1',
      port: 9199,
      rules: readFileSync(new URL('../../storage.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/s1'), {uid: 's1', role: 'student', status: 'active'});
    await setDoc(doc(db, 'users/o1'), {uid: 'o1', role: 'organizer', status: 'active'});
    await setDoc(doc(db, 'users/o2'), {uid: 'o2', role: 'organizer', status: 'active'});
    await setDoc(doc(db, 'users/admin'), {uid: 'admin', role: 'admin', status: 'active'});
    await setDoc(doc(db, 'events/e1'), {organizerId: 'o1', status: 'published'});
  });
});

test('unauthenticated guest cannot upload poster', async () => {
  const storage = storageFor(null);
  const fileRef = ref(storage, 'posters/o1/poster.png');
  await assertFails(uploadBytes(fileRef, samplePng, {contentType: 'image/png'}));
});

test('public read is allowed for posters', async () => {
  // First upload as organizer
  const oStorage = storageFor('o1', 'organizer');
  const fileRef = ref(oStorage, 'posters/o1/public.png');
  await assertSucceeds(uploadBytes(fileRef, samplePng, {contentType: 'image/png'}));

  // Then read as unauthenticated guest
  const guestStorage = storageFor(null);
  const guestRef = ref(guestStorage, 'posters/o1/public.png');
  await assertSucceeds(getBytes(guestRef));
});

test('student cannot upload event poster', async () => {
  const storage = storageFor('s1', 'student');
  const ownRef = ref(storage, 'posters/s1/poster.png');
  await assertFails(uploadBytes(ownRef, samplePng, {contentType: 'image/png'}));

  const otherRef = ref(storage, 'posters/o1/poster.png');
  await assertFails(uploadBytes(otherRef, samplePng, {contentType: 'image/png'}));
});

test('organizer can upload valid poster to own folder', async () => {
  const storage = storageFor('o1', 'organizer');
  const fileRef = ref(storage, 'posters/o1/poster.png');
  await assertSucceeds(uploadBytes(fileRef, samplePng, {contentType: 'image/png'}));

  const jpegRef = ref(storage, 'posters/o1/poster.jpg');
  await assertSucceeds(uploadBytes(jpegRef, sampleJpeg, {contentType: 'image/jpeg'}));
});

test('organizer cannot overwrite another organizer poster', async () => {
  const storage = storageFor('o2', 'organizer');
  const fileRef = ref(storage, 'posters/o1/poster.png');
  await assertFails(uploadBytes(fileRef, samplePng, {contentType: 'image/png'}));
});

test('invalid MIME type is rejected', async () => {
  const storage = storageFor('o1', 'organizer');
  const fileRef = ref(storage, 'posters/o1/document.pdf');
  await assertFails(uploadBytes(fileRef, samplePdf, {contentType: 'application/pdf'}));

  const txtRef = ref(storage, 'posters/o1/note.txt');
  await assertFails(uploadBytes(txtRef, new Uint8Array([65, 66, 67]), {contentType: 'text/plain'}));
});

test('file larger than 5MB is rejected', async () => {
  const storage = storageFor('o1', 'organizer');
  const fileRef = ref(storage, 'posters/o1/huge.png');
  await assertFails(uploadBytes(fileRef, oversizeBytes, {contentType: 'image/png'}));
});

test('organizer can delete own poster but not another organizer poster', async () => {
  const o1Storage = storageFor('o1', 'organizer');
  const o1File = ref(o1Storage, 'posters/o1/to_delete.png');
  await assertSucceeds(uploadBytes(o1File, samplePng, {contentType: 'image/png'}));

  const o2Storage = storageFor('o2', 'organizer');
  const o2Attempt = ref(o2Storage, 'posters/o1/to_delete.png');
  await assertFails(deleteObject(o2Attempt));

  await assertSucceeds(deleteObject(o1File));
});

test('admin can upload and delete posters across folders', async () => {
  const adminStorage = storageFor('admin', 'admin');
  const fileRef = ref(adminStorage, 'posters/o1/admin_created.png');
  await assertSucceeds(uploadBytes(fileRef, samplePng, {contentType: 'image/png'}));
  await assertSucceeds(deleteObject(fileRef));
});

test('event-scoped path requires event ownership regardless of filename prefix', async () => {
  const o1Storage = storageFor('o1', 'organizer');
  const allowedRef = ref(o1Storage, 'events/e1/o1_banner.png');
  await assertSucceeds(uploadBytes(allowedRef, samplePng, {contentType: 'image/png'}));

  const spoofedRef = ref(storageFor('o2', 'organizer'), 'events/e1/o2_banner.png');
  await assertFails(uploadBytes(spoofedRef, samplePng, {contentType: 'image/png'}));
});
