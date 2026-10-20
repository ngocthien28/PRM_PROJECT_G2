import {readFileSync} from 'node:fs';
import {test, before, after, beforeEach} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, setDoc, getDoc, updateDoc, collection, getDocs, query, where,
  writeBatch, serverTimestamp, Timestamp} from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-campushub',
    firestore: {host: '127.0.0.1', port: 8087,
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')}});
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const uid of ['u1', 'u2']) {
      await setDoc(doc(db, 'users', uid), {role: 'student', status: 'active'});
    }
    await setDoc(doc(db, 'clubs', 'c1'), {status: 'active', memberCount: 0, ownerId: 'admin'});
    await setDoc(doc(db, 'notifications', 'n1'), {
      userId: 'u1', title: 'Joined', body: 'Sport', isRead: false,
      createdAt: Timestamp.now(), pushStatus: 'pending',
    });
  });
});

test('inbox and read status belong exclusively to recipient', async () => {
  const owner = env.authenticatedContext('u1').firestore();
  const other = env.authenticatedContext('u2').firestore();
  await assertSucceeds(getDocs(query(collection(owner, 'notifications'), where('userId', '==', 'u1'))));
  await assertFails(getDocs(collection(owner, 'notifications')));
  await assertFails(getDoc(doc(other, 'notifications', 'n1')));
  await assertFails(updateDoc(doc(other, 'notifications', 'n1'), {isRead: true}));
  await assertSucceeds(updateDoc(doc(owner, 'notifications', 'n1'), {isRead: true}));
  await assertFails(updateDoc(doc(owner, 'notifications', 'n1'), {title: 'spoofed'}));
  await assertFails(updateDoc(doc(owner, 'notifications', 'n1'), {pushStatus: 'sent'}));
});

test('Join creates membership, count and notice atomically', async () => {
  const db = env.authenticatedContext('u1').firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, 'club_memberships', 'c1_u1'), {
    clubId: 'c1', userId: 'u1', role: 'member', status: 'active',
    joinedAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  batch.update(doc(db, 'clubs', 'c1'), {memberCount: 1, updatedAt: serverTimestamp()});
  batch.set(doc(db, 'notifications', 'joined'), {
    userId: 'u1', title: 'Club joined', body: 'You joined Sport.',
    type: 'club_membership', referenceId: 'c1', membershipStatus: 'active',
    isRead: false, pushStatus: 'pending', createdAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(doc(db, 'notifications', 'standalone'), {
    userId: 'u1', title: 'Fake', body: 'Fake',
    type: 'club_membership', referenceId: 'c1', membershipStatus: 'active',
    isRead: false, pushStatus: 'pending', createdAt: serverTimestamp(),
  }));
});

test('tokens cannot be registered for another account', async () => {
  const db = env.authenticatedContext('u1').firestore();
  const token = {token: 'device-token', platform: 'android', updatedAt: serverTimestamp()};
  await assertSucceeds(setDoc(doc(db, 'users/u1/device_tokens/t1'), token));
  await assertFails(setDoc(doc(db, 'users/u2/device_tokens/t1'), token));
  await assertFails(getDocs(collection(db, 'users/u2/device_tokens')));
});
