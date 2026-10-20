import {test, before} from 'node:test';
import assert from 'node:assert/strict';
import {runSeed} from '../../firebase/seed/seed.mjs';
import {createRequire} from 'node:module';

const require = createRequire(import.meta.url);
const {getFirestore} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');

before(() => {
  if (!process.env.FIREBASE_AUTH_EMULATOR_HOST || !process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Emulator hosts must be defined before running seed integration test.');
  }
});

test('seed script is idempotent: running twice preserves exact counts and consistency', async () => {
  // First run
  const firstResult = await runSeed();
  assert.equal(firstResult.usersCount, 5);
  assert.equal(firstResult.eventsCount, 10);
  assert.equal(firstResult.registrationsCount, 9);
  assert.equal(firstResult.clubsCount, 2);
  assert.equal(firstResult.notificationsCount, 3);

  // Second run immediately after
  const secondResult = await runSeed();
  assert.equal(secondResult.usersCount, 5);
  assert.equal(secondResult.eventsCount, 10);
  assert.equal(secondResult.registrationsCount, 9);
  assert.equal(secondResult.clubsCount, 2);
  assert.equal(secondResult.notificationsCount, 3);

  // Verify documents in Firestore (scoped to demo IDs to guarantee test isolation)
  const db = getFirestore();
  const demoUids = [
    'demo_student_01',
    'demo_student_02',
    'demo_organizer_01',
    'demo_organizer_02',
    'demo_admin_01',
  ];
  for (const uid of demoUids) {
    const doc = await db.collection('users').doc(uid).get();
    assert.equal(doc.exists, true);
    assert.equal(doc.data().status, 'active');
  }

  const demoEventIds = [
    'demo_event_tech_flutter_01',
    'demo_event_full_ai_hackathon_02',
    'demo_event_workshop_resume_03',
    'demo_event_outdoor_badminton_04',
    'demo_event_music_acoustic_night_05',
    'demo_event_past_robotics_symposium_06',
    'demo_event_cancelled_football_07',
    'demo_event_draft_cloud_study_08',
    'demo_event_music_rock_fest_09',
    'demo_event_sport_marathon_10',
  ];
  for (const eid of demoEventIds) {
    const doc = await db.collection('events').doc(eid).get();
    assert.equal(doc.exists, true);
  }

  const demoRegIds = [
    'demo_event_tech_flutter_01_demo_student_01',
    'demo_event_full_ai_hackathon_02_demo_student_01',
    'demo_event_full_ai_hackathon_02_demo_student_02',
    'demo_event_outdoor_badminton_04_demo_student_01',
    'demo_event_music_acoustic_night_05_demo_student_02',
    'demo_event_past_robotics_symposium_06_demo_student_01',
    'demo_event_music_rock_fest_09_demo_student_02',
    'demo_event_sport_marathon_10_demo_student_01',
    'demo_event_sport_marathon_10_demo_student_02',
  ];
  for (const rid of demoRegIds) {
    const doc = await db.collection('registrations').doc(rid).get();
    assert.equal(doc.exists, true);
  }

  const auth = getAuth();
  const student1 = await auth.getUser('demo_student_01');
  assert.equal(student1.email, 'student1@demo.com');
  assert.equal(student1.customClaims?.role, 'student');

  const admin1 = await auth.getUser('demo_admin_01');
  assert.equal(admin1.email, 'admin1@demo.com');
  assert.equal(admin1.customClaims?.role, 'admin');
});
