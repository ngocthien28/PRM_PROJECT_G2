import { createRequire } from 'node:module';
import { getSeedData } from './seed_data.mjs';
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';

const require = createRequire(new URL('../../notification-server/', import.meta.url));
const { initializeApp, getApps } = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');

function verifyEmulatorEnvironment() {
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;

  if (!authHost || !firestoreHost) {
    console.error('================================================================');
    console.error('FATAL: SAFETY VIOLATION PREVENTED');
    console.error('The seed script can ONLY be executed against the Firebase Emulator Suite.');
    console.error(`Current FIREBASE_AUTH_EMULATOR_HOST: ${authHost || 'NOT SET'}`);
    console.error(`Current FIRESTORE_EMULATOR_HOST:     ${firestoreHost || 'NOT SET'}`);
    console.error('Execution against production database is strictly blocked.');
    console.error('================================================================');
    process.exit(1);
  }
  for (const host of [authHost, firestoreHost, process.env.FIREBASE_STORAGE_EMULATOR_HOST].filter(Boolean)) {
    if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) throw new Error('Seed requires loopback emulator hosts.');
  }
}

export async function runSeed(options = {}) {
  verifyEmulatorEnvironment();

  const projectId = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT || 'demo-campushub';
  if (!projectId.startsWith('demo-')) throw new Error('Seed requires a demo- project.');
  if (!getApps().length) {
    initializeApp({ projectId, storageBucket: `${projectId}.appspot.com` });
  }

  const auth = getAuth();
  const db = getFirestore();
  const seedData = getSeedData(options.now || new Date());
  let posterCount = 0;
  if (process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    const bucket = getStorage().bucket(`${projectId}.appspot.com`);
    const path = `events/${seedData.events[0].id}/demo-poster.png`;
    const token = randomUUID();
    await bucket.file(path).save(readFileSync(new URL('../fixtures/organizer-poster.png', import.meta.url)), {
      resumable: false, metadata: {contentType: 'image/png', metadata: {firebaseStorageDownloadTokens: token}},
    });
    seedData.events[0].posterUrl = `http://${process.env.FIREBASE_STORAGE_EMULATOR_HOST}/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
    posterCount = 1;
  } else {
    console.log('[Poster NOT VERIFIED] Start Storage Emulator to seed a downloadable poster.');
  }

  console.log(`[CampusHub Seed] Initializing seed data for project: ${projectId}`);
  console.log(`[CampusHub Seed] Auth Emulator: ${process.env.FIREBASE_AUTH_EMULATOR_HOST}`);
  console.log(`[CampusHub Seed] Firestore Emulator: ${process.env.FIRESTORE_EMULATOR_HOST}`);

  // 1. Seed Auth accounts & User profiles
  console.log('\n--- 1. Seeding Users (Auth + Firestore /users) ---');
  for (const user of seedData.users) {
    try {
      await auth.getUser(user.uid);
      await auth.updateUser(user.uid, {
        email: user.email,
        password: user.password,
        displayName: user.displayName,
      });
      console.log(`  [UPDATE] Auth user: ${user.email} (${user.uid}) [${user.role}]`);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        await auth.createUser({
          uid: user.uid,
          email: user.email,
          password: user.password,
          displayName: user.displayName,
        });
        console.log(`  [CREATE] Auth user: ${user.email} (${user.uid}) [${user.role}]`);
      } else {
        throw e;
      }
    }

    await auth.setCustomUserClaims(user.uid, { role: user.role });

    await db.collection('users').doc(user.uid).set({
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      role: user.role,
      status: user.status,
      createdAt: Timestamp.fromDate(user.createdAt),
      updatedAt: Timestamp.fromDate(user.updatedAt),
    }, { merge: false });
  }

  // 2. Seed Clubs
  console.log('\n--- 2. Seeding Clubs ---');
  for (const club of seedData.clubs) {
    await db.collection('clubs').doc(club.id).set({
      ...club,
      createdAt: Timestamp.fromDate(club.createdAt),
      updatedAt: Timestamp.fromDate(club.updatedAt),
    }, { merge: false });
    console.log(`  [SET] Club: ${club.name} (${club.id}) - Owner: ${club.ownerId}`);
  }

  // 3. Seed Club Memberships
  console.log('\n--- 3. Seeding Club Memberships ---');
  for (const membership of seedData.clubMemberships) {
    await db.collection('club_memberships').doc(membership.id).set({
      ...membership,
      joinedAt: Timestamp.fromDate(membership.joinedAt),
      updatedAt: Timestamp.fromDate(membership.updatedAt),
    }, { merge: false });
    console.log(`  [SET] Membership: ${membership.id} - Role: ${membership.role}`);
  }

  // 4. Seed Events
  console.log('\n--- 4. Seeding Events ---');
  for (const event of seedData.events) {
    await db.collection('events').doc(event.id).set({
      ...event,
      startAt: Timestamp.fromDate(event.startAt),
      endAt: Timestamp.fromDate(event.endAt),
      createdAt: Timestamp.fromDate(event.createdAt),
      updatedAt: Timestamp.fromDate(event.updatedAt),
    }, { merge: false });
    console.log(`  [SET] Event: ${event.title} (${event.id}) [${event.status}] - Reg: ${event.registeredCount}/${event.capacity}`);
  }

  // 5. Seed Registrations
  console.log('\n--- 5. Seeding Registrations ---');
  for (const reg of seedData.registrations) {
    const previous = await db.collection('registrations').doc(reg.id).get();
    await db.collection('registrations').doc(reg.id).set({
      ...reg,
      qrToken: previous.data()?.qrToken || reg.qrToken,
      registeredAt: Timestamp.fromDate(reg.registeredAt),
      cancelledAt: reg.cancelledAt ? Timestamp.fromDate(reg.cancelledAt) : null,
      checkedInAt: reg.checkedInAt ? Timestamp.fromDate(reg.checkedInAt) : null,
    }, { merge: false });
    console.log(`  [SET] Registration: ${reg.id} [${reg.status}]`);
  }

  // 6. Seed Notifications
  console.log('\n--- 6. Seeding Notifications ---');
  for (const notice of seedData.notifications) {
    await db.collection('notifications').doc(notice.id).set({
      ...notice,
      createdAt: Timestamp.fromDate(notice.createdAt),
    }, { merge: false });
    console.log(`  [SET] Notification: ${notice.title} (${notice.userId})`);
  }

  // 7. Post-seed Consistency Verification
  console.log('\n--- 7. Validating Invariants and Counter Consistency ---');
  let hasInconsistency = false;
  for (const event of seedData.events) {
    const eventRegs = seedData.registrations.filter((r) => r.eventId === event.id);
    const activeRegs = eventRegs.filter((r) => r.status === 'registered' || r.status === 'checkedIn');
    const checkedInRegs = eventRegs.filter((r) => r.status === 'checkedIn');

    if (activeRegs.length !== event.registeredCount) {
      console.error(`  [INVARIANT ERROR] Event ${event.id}: active registrations (${activeRegs.length}) != registeredCount (${event.registeredCount})`);
      hasInconsistency = true;
    }
    if (checkedInRegs.length !== event.checkedInCount) {
      console.error(`  [INVARIANT ERROR] Event ${event.id}: checkedIn registrations (${checkedInRegs.length}) != checkedInCount (${event.checkedInCount})`);
      hasInconsistency = true;
    }
    if (event.checkedInCount > event.registeredCount) {
      console.error(`  [INVARIANT ERROR] Event ${event.id}: checkedInCount > registeredCount`);
      hasInconsistency = true;
    }
    if (event.registeredCount > event.capacity) {
      console.error(`  [INVARIANT ERROR] Event ${event.id}: registeredCount > capacity`);
      hasInconsistency = true;
    }
  }

  if (hasInconsistency) {
    throw new Error('Seed data validation failed: Counter invariant violation.');
  }

  console.log('  [PASS] All event counters match actual registrations perfectly.');
  console.log('\n[CampusHub Seed] Completed successfully with zero errors.');

  return {
    usersCount: seedData.users.length,
    eventsCount: seedData.events.length,
    registrationsCount: seedData.registrations.length,
    clubsCount: seedData.clubs.length,
    notificationsCount: seedData.notifications.length,
    posterCount,
  };
}

if (process.argv[1] && process.argv[1].endsWith('seed.mjs')) {
  runSeed().catch((err) => {
    console.error('Seed execution error:', err);
    process.exit(1);
  });
}
