import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {before, after, test} from 'node:test';
import {initializeTestEnvironment, assertFails} from '@firebase/rules-unit-testing';
import {collection, doc, setDoc, getDoc, getDocs, query, where, documentId, orderBy, limit} from 'firebase/firestore';
import {event} from './helpers/event-flow.mjs';

let env;
const projectId = 'demo-campushub-create-recovery';
before(async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8087') throw new Error('Local emulator required.');
  // Isolated from the user's running demo and its drafts/events.
  env = await initializeTestEnvironment({projectId, firestore: {
    host: '127.0.0.1', port: 8087,
    rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/owner'), {uid: 'owner', role: 'organizer', status: 'active'});
    await setDoc(doc(ctx.firestore(), 'users/other'), {uid: 'other', role: 'organizer', status: 'active'});
    await setDoc(doc(ctx.firestore(), 'events/owner_z-existing'), event('owner'));
    await setDoc(doc(ctx.firestore(), 'events/other_z-existing'), event('other'));
  });
});
after(async () => { await env?.cleanup(); });

test('regression: exact ID lookup of a missing event is denied under existing Rules', async () => {
  const db = env.authenticatedContext('owner').firestore();
  await assertFails(getDocs(query(collection(db, 'events'), where('organizerId', '==', 'owner'),
    where(documentId(), '==', 'owner_a-missing'))));
});
const lookup = async (db, id) => (await getDocs(query(collection(db, 'events'),
  where('organizerId', '==', 'owner'), where(documentId(), '>=', id), orderBy(documentId()), limit(1))))
  .docs.find((d) => d.id === id);

test('bounded owner lookup allows missing ID even when a later event exists', async () => {
  const db = env.authenticatedContext('owner').firestore();
  assert.equal(await lookup(db, 'owner_a-missing'), undefined);
  assert.equal(await lookup(db, 'owner_zz-missing'), undefined);
});
test('bounded lookup recovers an existing event and does not allow another organizer', async () => {
  assert.equal((await lookup(env.authenticatedContext('owner').firestore(), 'owner_z-existing')).id, 'owner_z-existing');
  await assertFails(lookup(env.authenticatedContext('other').firestore(), 'owner_z-existing'));
});
test('missing request creates once, then recovery preserves the same document', async () => {
  const db = env.authenticatedContext('owner').firestore(), id = 'owner_new-request';
  const create = async () => {
    if (!(await lookup(db, id))) await setDoc(doc(db, 'events', id), event('owner'));
    return getDoc(doc(db, 'events', id));
  };
  const first = (await create()).data(); const second = (await create()).data();
  assert.deepEqual(second, first);
});
