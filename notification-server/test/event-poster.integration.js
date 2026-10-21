import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test, before, beforeEach, after} from 'node:test';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, setDoc, getDoc, updateDoc, serverTimestamp, Timestamp} from 'firebase/firestore';
import {ref, uploadBytes, getDownloadURL, getBytes, deleteObject} from 'firebase/storage';

let env;
const png = Uint8Array.from(Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAALSURBVBhXY2BABwAAEgABp3qZbgAAAABJRU5ErkJggg==', 'base64'));
const context = (uid, claims = {}) => uid ? env.authenticatedContext(uid, claims) : env.unauthenticatedContext();
const event = (owner = 'o1', overrides = {}) => ({
  organizerId: owner, clubId: null, title: 'Campus workshop', titleLower: 'campus workshop',
  description: 'A practical workshop for CampusHub students.', category: 'technology', locationName: 'Hall A',
  latitude: null, longitude: null, startAt: Timestamp.fromMillis(Date.now() + 86400000),
  endAt: Timestamp.fromMillis(Date.now() + 90000000), capacity: 80, registeredCount: 2,
  checkedInCount: 1, posterUrl: null, status: 'published', createdAt: Timestamp.now(), updatedAt: Timestamp.now(), ...overrides,
});
const upload = (uid, eventId = 'e1', name = 'new.png', bytes = png, contentType = 'image/png') =>
  uploadBytes(ref(context(uid).storage(), `events/${eventId}/${name}`), bytes, {contentType});
const attach = (uid, url, patch = {}) => updateDoc(doc(context(uid).firestore(), 'events/e1'), {
  posterUrl: url, updatedAt: serverTimestamp(), ...patch,
});

before(async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8087'
      || process.env.FIREBASE_STORAGE_EMULATOR_HOST !== '127.0.0.1:9199') {
    throw new Error('UC-040 tests require local Firestore/Storage emulators. Production is forbidden.');
  }
  env = await initializeTestEnvironment({
    projectId: 'demo-campushub',
    firestore: {host: '127.0.0.1', port: 8087, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')},
    storage: {host: '127.0.0.1', port: 9199, rules: readFileSync(new URL('../../storage.rules', import.meta.url), 'utf8')},
  });
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore(); await env.clearStorage();
  await env.withSecurityRulesDisabled(async (c) => {
    for (const [uid, role, status] of [['o1','organizer','active'],['o2','organizer','active'],
      ['s1','student','active'],['admin','admin','active'],['disabled','organizer','disabled']]) {
      await setDoc(doc(c.firestore(), 'users', uid), {uid, role, status});
    }
    await setDoc(doc(c.firestore(), 'events/e1'), event());
    await setDoc(doc(c.firestore(), 'events/e2'), event('o2'));
    await setDoc(doc(c.firestore(), 'events/cancelled'), event('o1', {status: 'cancelled'}));
  });
});

test('owner uploads, persists the actual download URL, and Student reads the poster', async () => {
  const before = (await getDoc(doc(context('o1').firestore(), 'events/e1'))).data();
  const uploaded = await assertSucceeds(upload('o1'));
  const url = await getDownloadURL(uploaded.ref);
  await assertSucceeds(attach('o1', url));
  const after = (await getDoc(doc(context('s1').firestore(), 'events/e1'))).data();
  assert.equal(after.posterUrl, url);
  for (const key of ['organizerId','registeredCount','checkedInCount','createdAt']) {
    assert.deepEqual(after[key], before[key]);
  }
  assert.deepEqual(await getBytes(ref(context('s1').storage(), 'events/e1/new.png')), png.buffer);
});

test('create event first, upload, then attach URL to the same document', async () => {
  const db = context('o1').firestore();
  await assertSucceeds(setDoc(doc(db, 'events/new-event'), event('o1', {
    registeredCount: 0, checkedInCount: 0, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  })));
  const uploaded = await assertSucceeds(upload('o1', 'new-event'));
  const url = await getDownloadURL(uploaded.ref);
  await assertSucceeds(updateDoc(doc(db, 'events/new-event'), {posterUrl: url, updatedAt: serverTimestamp()}));
  assert.equal((await getDoc(doc(db, 'events/new-event'))).data().posterUrl, url);
});

for (const uid of ['o2','s1','disabled', null]) {
  test(`${uid ?? 'guest'} cannot upload, overwrite, delete or attach another event poster`, async () => {
    const uploaded = await upload('o1');
    const url = await getDownloadURL(uploaded.ref);
    await assertFails(upload(uid));
    await assertFails(upload(uid, 'e1', `${uid ?? 'guest'}_spoof.png`));
    await assertFails(deleteObject(ref(context(uid).storage(), 'events/e1/new.png')));
    await assertFails(attach(uid, url));
  });
}
test('student forged admin claim cannot bypass the trusted profile', async () => {
  await assertFails(uploadBytes(ref(context('s1', {role: 'admin'}).storage(), 'events/e1/forged.png'), png, {contentType:'image/png'}));
});
test('admin can upload and attach a poster while preserving event owner', async () => {
  const uploaded = await assertSucceeds(upload('admin'));
  await assertSucceeds(attach('admin', await getDownloadURL(uploaded.ref)));
  assert.equal((await getDoc(doc(context('admin').firestore(), 'events/e1'))).data().organizerId, 'o1');
});
test('missing and cancelled events do not accept uploads', async () => {
  await assertFails(upload('o1','missing'));
  await assertFails(upload('o1','cancelled'));
});
test('invalid MIME, zero bytes and more than 5 MiB are denied', async () => {
  await assertFails(upload('o1','e1','bad.png', png, 'application/pdf'));
  await assertFails(upload('o1','e1','bad.gif', png, 'image/gif'));
  await assertFails(upload('o1','e1','empty.png', new Uint8Array()));
  await assertFails(upload('o1','e1','huge.png', new Uint8Array(5*1024*1024 + 1)));
});
test('PNG, JPEG and WebP MIME metadata are allowed by Storage rules', async () => {
  for (const [extension, mime] of [['png','image/png'],['jpg','image/jpeg'],['webp','image/webp']]) {
    await assertSucceeds(upload('o1','e1',`valid.${extension}`, png, mime));
  }
});
test('owner cannot combine a poster replacement with changes to protected fields', async () => {
  const url = await getDownloadURL((await upload('o1')).ref);
  for (const patch of [{organizerId:'o2'},{registeredCount:3},{checkedInCount:0},{createdAt:serverTimestamp()}]) {
    await assertFails(attach('o1',url,patch));
  }
});
test('rejects local paths, external URLs and a different event Storage path', async () => {
  const otherUrl = await getDownloadURL((await upload('o2','e2')).ref);
  for (const url of ['file:///poster.png','https://example.com/poster.png',otherUrl]) {
    await assertFails(attach('o1',url));
  }
});
test('ordinary edits preserve poster and rejected replacement leaves its reference intact', async () => {
  const url = await getDownloadURL((await upload('o1')).ref);
  await assertSucceeds(attach('o1',url));
  const db = context('o1').firestore();
  await assertSucceeds(updateDoc(doc(db,'events/e1'), {locationName:'Hall B',updatedAt:serverTimestamp()}));
  await assertFails(attach('o2',url));
  assert.equal((await getDoc(doc(db,'events/e1'))).data().posterUrl,url);
});
test('local emulator URLs support the configured bucket namespace with the same event restriction', async () => {
  const url = 'http://127.0.0.1:9199/v0/b/configured-campus.appspot.com/o/events%2Fe1%2Fnew.png?alt=media&token=local-test';
  await assertSucceeds(attach('o1', url));
  await assertFails(attach('o2', url));
  await assertFails(attach('o1', url.replace('events%2Fe1', 'events%2Fe2')));
});

const cloudinaryUrl = (eventId = 'e1', prefix = '') =>
  `https://res.cloudinary.com/djznx3z7o/image/upload/v123/${prefix}campushub/event_posters/${eventId}/new-poster.png`;
for (const [uid, allowed] of [['o1',true],['admin',true],['o2',false],['s1',false],['disabled',false],[null,false]]) {
  test(`Cloudinary poster attachment ${uid ?? 'guest'}: ${allowed ? 'ALLOW' : 'DENY'}`, async () => {
    await (allowed ? assertSucceeds(attach(uid,cloudinaryUrl())) : assertFails(attach(uid,cloudinaryUrl())));
  });
}
test('Cloudinary URL persists and is readable by Student without Firebase Storage', async () => {
  const before = (await getDoc(doc(context('o1').firestore(),'events/e1'))).data();
  await assertSucceeds(attach('o1',cloudinaryUrl()));
  const after = (await getDoc(doc(context('s1').firestore(),'events/e1'))).data();
  assert.equal(after.posterUrl,cloudinaryUrl());
  for (const key of ['organizerId','createdAt','registeredCount','checkedInCount']) assert.deepEqual(after[key],before[key]);
});
test('Cloudinary supports the existing preset fixed folder prefix', async () => {
  await assertSucceeds(attach('o1',cloudinaryUrl('e1','campushub/club_logos/')));
});
test('Cloudinary rejects another account, event, raw delivery, extension and URL spoofing', async () => {
  for (const url of [cloudinaryUrl('e2'),cloudinaryUrl().replace('/djznx3z7o/','/other-cloud/'),
    cloudinaryUrl().replace('/image/upload/','/raw/upload/'),cloudinaryUrl().replace('.png','.svg'),
    cloudinaryUrl().replace('res.cloudinary.com','res.cloudinary.com.evil.example'),
    `${cloudinaryUrl()}?event=e1`, cloudinaryUrl().replace('/v123/','/v123/../')]) {
    await assertFails(attach('o1',url));
  }
});
test('Cloudinary poster update cannot bypass protected fields or cancelled event policy', async () => {
  for (const patch of [{organizerId:'o2'},{registeredCount:3},{checkedInCount:0},{createdAt:serverTimestamp()}]) {
    await assertFails(attach('o1',cloudinaryUrl(),patch));
  }
  await assertFails(updateDoc(doc(context('o1').firestore(),'events/cancelled'), {
    posterUrl:cloudinaryUrl('cancelled'),updatedAt:serverTimestamp(),
  }));
});
