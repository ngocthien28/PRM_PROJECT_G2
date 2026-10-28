import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {before, after, test} from 'node:test';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {createMockUserToken} from '@firebase/util';
import {doc, setDoc, deleteDoc} from 'firebase/firestore';
import {event} from './helpers/event-flow.mjs';

// Storage Emulator resolves firestore.get against its CLI project. Use unique
// fixture IDs there; never clear the user's running demo or existing objects.
const projectId = 'demo-campushub', prefix = `windows-poster-test-${randomUUID()}`;
const owner = `${prefix}-owner`, other = `${prefix}-other`, eid = `${prefix}-event`;
let env;
before(async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8087'
    || process.env.FIREBASE_STORAGE_EMULATOR_HOST !== '127.0.0.1:9199') throw new Error('Local emulators required.');
  env = await initializeTestEnvironment({projectId, firestore: {host: '127.0.0.1', port: 8087,
    rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')},
    storage: {host: '127.0.0.1', port: 9199, rules: readFileSync(new URL('../../storage.rules', import.meta.url), 'utf8')}});
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const uid of [owner, other]) await setDoc(doc(ctx.firestore(), 'users', uid), {uid, role: 'organizer', status: 'active'});
    await setDoc(doc(ctx.firestore(), 'events', eid), event(owner));
  });
});
after(async () => {
  if (!env) return;
  await env.withSecurityRulesDisabled(async (ctx) => {
    await deleteDoc(doc(ctx.firestore(), 'events', eid));
    for (const uid of [owner, other]) await deleteDoc(doc(ctx.firestore(), 'users', uid));
  });
  await env.cleanup();
});
test('Windows media HTTP upload, download and delete enforce real owner Rules', async () => {
  const bucket = `${projectId}.appspot.com`, path = `events/${eid}/windows-test.png`;
  const endpoint = `http://127.0.0.1:9199/v0/b/${bucket}/o`;
  const bytes = readFileSync(new URL('../../firebase/fixtures/organizer-poster.png', import.meta.url));
  const auth = (uid) => `Bearer ${createMockUserToken({sub: uid, user_id: uid}, projectId)}`;
  const upload = (uid) => fetch(`${endpoint}?name=${encodeURIComponent(path)}`, {
    method: 'POST', headers: {'Authorization': auth(uid), 'Content-Type': 'image/png'}, body: bytes,
  });
  const objectEndpoint = `${endpoint}/${encodeURIComponent(path)}`;
  try {
    assert.equal((await upload(other)).status, 403);
    const uploaded = await upload(owner); assert.equal(uploaded.status, 200);
    const metadata = await uploaded.json(); assert.equal(metadata.name, path);
    const url = `${objectEndpoint}?alt=media&token=${metadata.downloadTokens}`;
    const downloaded = await fetch(url); assert.equal(downloaded.status, 200);
    assert.deepEqual(Buffer.from(await downloaded.arrayBuffer()), bytes);
    assert.equal((await fetch(objectEndpoint, {method: 'DELETE', headers: {Authorization: auth(other)}})).status, 403);
  } finally {
    assert.equal((await fetch(objectEndpoint, {method: 'DELETE', headers: {Authorization: auth(owner)}})).status, 204);
  }
});
