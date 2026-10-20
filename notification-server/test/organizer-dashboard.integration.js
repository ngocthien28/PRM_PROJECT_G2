import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {after, before, beforeEach, test} from 'node:test';
import {initializeTestEnvironment, assertFails} from '@firebase/rules-unit-testing';
import {collection, doc, documentId, getDocsFromServer, limit, orderBy,
  query, startAfter, Timestamp, updateDoc, where, writeBatch} from 'firebase/firestore';

// Mirror the Dart read-only dashboard query against real Rules. This does not
// substitute for Flutter provider/model tests or test the native Windows SDK.
const asOf = Date.UTC(2030, 4, 1, 10);
let env;
const dbFor = (uid) => uid
  ? env.authenticatedContext(uid).firestore()
  : env.unauthenticatedContext().firestore();
const event = (organizerId, extra = {}) => ({
  organizerId, clubId: null, title: 'Dashboard workshop', titleLower: 'dashboard workshop',
  description: 'A practical dashboard verification workshop.', category: 'technology',
  locationName: 'Hall A', latitude: null, longitude: null,
  startAt: Timestamp.fromMillis(asOf + 86400000),
  endAt: Timestamp.fromMillis(asOf + 90000000), capacity: 100,
  registeredCount: 3, checkedInCount: 1, posterUrl: null, status: 'published',
  createdAt: Timestamp.fromMillis(asOf), updatedAt: Timestamp.fromMillis(asOf), ...extra,
});

before(async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8087') {
    throw new Error('UC-035 requires the local Firestore Emulator at 127.0.0.1:8087.');
  }
  env = await initializeTestEnvironment({
    projectId: 'demo-campushub-uc035',
    firestore: {host: '127.0.0.1', port: 8087,
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')},
  });
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore(), batch = writeBatch(db);
    for (const [uid, role] of [['a', 'organizer'], ['b', 'organizer'],
      ['student', 'student'], ['admin', 'admin'], ['disabled', 'organizer']]) {
      batch.set(doc(db, 'users', uid), {uid, role, status: uid === 'disabled' ? 'disabled' : 'active'});
    }
    // Same startAt on every page exercises the document-ID cursor tie breaker.
    for (let i = 0; i < 205; i++) {
      batch.set(doc(db, 'events', `a-${String(i).padStart(3, '0')}`),
        event('a', {status: i % 2 ? 'cancelled' : 'published'}));
    }
    batch.set(doc(db, 'events/draft'), event('a', {status: 'draft', registeredCount: 0, checkedInCount: 0}));
    batch.set(doc(db, 'events/finished'), event('a', {status: 'finished', registeredCount: 4, checkedInCount: 4}));
    batch.set(doc(db, 'events/ongoing'), event('a', {startAt: Timestamp.fromMillis(asOf), registeredCount: 2}));
    batch.set(doc(db, 'events/past'), event('a', {startAt: Timestamp.fromMillis(asOf - 3600000),
      endAt: Timestamp.fromMillis(asOf), registeredCount: 5, checkedInCount: 2}));
    batch.set(doc(db, 'events/b-only'), event('b', {registeredCount: 90, checkedInCount: 80}));
    batch.set(doc(db, 'events/admin-only'), event('admin', {status: 'draft', registeredCount: 0, checkedInCount: 0}));
    await batch.commit();
  });
});

async function dashboard(db, owner) {
  const base = [where('organizerId', '==', owner), orderBy('startAt', 'desc'), orderBy(documentId(), 'desc')];
  const result = {total: 0, upcoming: 0, published: 0, cancelled: 0, registrations: 0, checkedIn: 0,
    ids: [], pageSizes: []};
  let cursor;
  while (true) {
    const page = await getDocsFromServer(query(collection(db, 'events'), ...base,
      ...(cursor ? [startAfter(cursor)] : []), limit(100)));
    result.pageSizes.push(page.size);
    for (const snapshot of page.docs) {
      const e = snapshot.data();
      assert.equal(e.organizerId, owner);
      result.total++;
      result.upcoming += Number(e.status === 'published' && e.startAt.toMillis() > asOf && e.endAt.toMillis() > asOf);
      result.published += Number(e.status === 'published');
      result.cancelled += Number(e.status === 'cancelled');
      result.registrations += e.registeredCount;
      result.checkedIn += e.checkedInCount;
      result.ids.push(snapshot.id);
    }
    if (page.size < 100) return result;
    cursor = page.docs.at(-1);
  }
}

test('owner KPIs include all 209 events across three pages and preserve cancelled history', async () => {
  const actual = await dashboard(dbFor('a'), 'a');
  assert.deepEqual(actual.pageSizes, [100, 100, 9]);
  assert.equal(new Set(actual.ids).size, 209);
  assert.deepEqual([actual.total, actual.upcoming, actual.published, actual.cancelled,
    actual.registrations, actual.checkedIn], [209, 103, 105, 102, 626, 212]);
  assert.ok(!actual.ids.includes('b-only'));
});

test('organizer B has independent counters and cannot query organizer A history', async () => {
  const actual = await dashboard(dbFor('b'), 'b');
  assert.deepEqual(actual.ids, ['b-only']);
  assert.equal(actual.registrations, 90);
  assert.equal(actual.checkedIn, 80);
  await assertFails(dashboard(dbFor('b'), 'a'));
});

for (const uid of ['student', 'disabled', null]) {
  test(`${uid ?? 'guest'} cannot execute the organizer all-status dashboard query`, async () => {
    await assertFails(dashboard(dbFor(uid), uid ?? 'a'));
  });
}

test('admin dashboard query is personal while existing admin management policy remains global', async () => {
  const actual = await dashboard(dbFor('admin'), 'admin');
  assert.deepEqual(actual.ids, ['admin-only']);
  assert.equal((await getDocsFromServer(collection(dbFor('admin'), 'events'))).size, 211);
});

test('explicit refresh reads changed event counters without reading registrations', async () => {
  const db = dbFor('a'), before = await dashboard(db, 'a');
  // Simulate the trusted counter producer; mutation contracts are tested by
  // existing ownership/registration suites, not reimplemented by UC-035.
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'events/a-000'), {registeredCount: 4, checkedInCount: 2});
  });
  const refreshed = await dashboard(db, 'a');
  assert.equal(refreshed.registrations, before.registrations + 1);
  assert.equal(refreshed.checkedIn, before.checkedIn + 1);
  assert.equal(refreshed.total, before.total);
});
