# CampusHub — Firebase Infrastructure & Security Guide (UC-034)

This document provides complete instructions for Firebase setup, Cloud Firestore Security Rules, Composite Indexes, Firebase Storage Rules, Local Emulator Suite, reproducible Seed Data, and automated verification for the CampusHub application (**PRM_PROJECT_G2**, Iteration 2).

---

## 1. Firebase Architecture Overview

CampusHub utilizes Cloud Firestore, Firebase Authentication, and Firebase Storage under a strictly enforced role-based security model.

### 1.1 Collections & Schemas

| Collection | Document ID Format | Key Fields & Types | Security & Access Policy |
| :--- | :--- | :--- | :--- |
| **`users`** | `{uid}` | `uid`, `email`, `displayName`, `avatarUrl`, `role` (`student`\|`organizer`\|`admin`), `status` (`active`\|`disabled`), `createdAt`, `updatedAt` | Self-signup restricted to `student` + `active`. No client role escalation. Owner reads own profile; Event Managers (Organizer/Admin) can read profiles for participant verification/check-in. |
| **`users/{uid}/favorites`** | `{eventId}` | `eventId` (string), `addedAt` (timestamp) | Scoped strictly to owner (`owns(uid) && activeUser()`). |
| **`users/{uid}/device_tokens`** | `{tokenId}` | `token` (string), `platform` (`android`), `updatedAt` (timestamp) | Scoped strictly to owner (`owns(uid)`). |
| **`events`** | Auto-generated or custom | `organizerId`, `clubId`, `title`, `titleLower`, `description`, `category` (`technology`\|`sport`\|`workshop`\|`music`), `locationName`, `latitude`, `longitude`, `startAt`, `endAt`, `capacity`, `registeredCount`, `checkedInCount`, `posterUrl`, `status` (`draft`\|`published`\|`cancelled`\|`finished`), `lastCheckInRegistrationId`, `createdAt`, `updatedAt` | **Read**: Active users read `published` events; Organizers read own events; Admins read all. Drafts remain private to owner/admin.<br>**Create**: Active Organizers/Admins only; creator cannot be spoofed (`organizerId == auth.uid`); initial counters must be 0.<br>**Update**: Owner/Admin only. Cannot transfer ownership, hard delete, or directly alter counters.<br>**Counters**: Counter updates must occur reciprocally with atomic registration transactions (`joinedAtomically`, `cancelledAtomically`, `checkedInAtomically`). |
| **`registrations`** | `{eventId}_{userId}` | `eventId`, `userId`, `status` (`registered`\|`cancelled`\|`checkedIn`), `qrToken`, `registeredAt`, `cancelledAt`, `checkedInAt` | **Read**: Student reads own registrations; Organizer reads only participants of events they own; Admin reads all.<br>**Write**: Atomic reciprocal transaction with event document. Enforces capacity invariants and cutoff rule (cancellation >= 2 hours before start). Deterministic document ID prevents duplicate join. |
| **`clubs`** | Auto-generated | `ownerId`, `name`, `nameLower`, `description`, `memberCount`, `status` (`active`\|`cancelled`), `logoUrl`, `createdAt`, `updatedAt` | Read by active users; created/updated by owner organizer or admin. Member count updated atomically upon membership changes. |
| **`club_memberships`** | `{clubId}_{userId}` | `clubId`, `userId`, `role` (`member`\|`manager`), `status` (`active`\|`left`), `joinedAt`, `updatedAt` | Scoped to member or club organizer. Updated atomically with notification generation. |
| **`notifications`** | Auto-generated | `userId`, `title`, `body`, `type`, `referenceId`, `membershipStatus`, `isRead`, `pushStatus`, `createdAt` | Read & marked read exclusively by recipient (`userId == auth.uid`). |
| **`moderation_cases`** | Stable demo IDs | Target details, reporter details, status, resolution, and audit timestamps | Read and resolved by active admins; active users can submit pending reports. |

---

## 2. Firebase Storage Configuration & Rules

Event posters are managed under Cloud Storage with strict file type, size, and ownership verification:

- **Rules File**: `storage.rules`
- **MIME Type Allow-list**: `image/jpeg`, `image/png`, `image/webp`
- **Maximum File Size**: `5 MB` (`5 * 1024 * 1024 bytes`)

### Storage Paths & Policies

1. **Organizer-scoped Staging Path**: `/posters/{userId}/{fileName}`
   - **Read**: Public (`allow read: if true;`) so student discovery feeds and tickets can load cached posters.
   - **Create / Update**: Restricted to authenticated user owning the path (`request.auth.uid == userId`) who has `organizer` or `admin` role, with valid image MIME type and size <= 5MB.
   - **Delete**: Owner or Admin only. Organizer A cannot delete or overwrite Organizer B's posters.
2. **Event-scoped Path**: `/events/{eventId}/{userId}_{fileName}`
   - Upload file name must be prefixed with the uploader's authenticated UID.
3. **Fallback**: All other storage paths default to `allow read, write: if false;`.

---

## 3. Firestore Composite Indexes

Located in `firestore.indexes.json`, composite indexes map directly to application queries:

| Collection | Indexed Fields | Query Purpose | Application Call Site |
| :--- | :--- | :--- | :--- |
| `events` | `status ASC, startAt ASC` | Student Upcoming Events discovery feed | `EventRepositoryImpl.getUpcomingEvents` |
| `events` | `category ASC, status ASC, startAt ASC` | Student Category Filtered Events | `EventRepositoryImpl.getUpcomingEvents(filter: category)` |
| `events` | `organizerId ASC, startAt DESC` | Organizer "My Managed Events" list | `EventRepositoryImpl.getManagedEvents` |
| `registrations` | `userId ASC, registeredAt DESC` | Student Tickets / Registration History | `RegistrationRepositoryImpl.getMyRegistrations` |
| `registrations` | `eventId ASC, status ASC` | Organizer Event Participants Query | `RegistrationRepositoryImpl.getEventParticipants` |
| `notifications` | `userId ASC, createdAt DESC` | User Notification Inbox feed | `NotificationRepositoryImpl.watchInbox` |

---

## 4. Local Firebase Emulator Suite

The repository is configured to run fully offline using the Firebase Emulator Suite without incurring cloud costs or modifying production data.

### 4.1 Port Configuration (`firebase.json` & `firebase.security-test.json`)

| Emulator Service | Port | Host | Notes |
| :--- | :--- | :--- | :--- |
| **Cloud Firestore** | `8087` | `127.0.0.1` | Configured with `firestore.rules` and `firestore.indexes.json` |
| **Authentication** | `9099` | `127.0.0.1` | Supports email/password, custom claims (`role`) |
| **Cloud Storage** | `9199` | `127.0.0.1` | Configured with `storage.rules` |
| **Emulator Hub** | `4407` | `127.0.0.1` | Internal orchestration |
| **Logging** | `4507` | `127.0.0.1` | Emulator logs |

### 4.2 Prerequisites

- **Node.js**: `>= 22` (Verified on Node `v24.14.0`)
- **Java**: `>= 21` (Verified on OpenJDK `21.0.9 LTS`)
- **Firebase CLI**: `>= 15.0.0` (Verified on `15.33.0`)
- **Flutter**: `>= 3.44.0` / Dart `>= 3.12.0`

---

## 5. Seed Data Architecture & Catalog

The seed script is located at `firebase/seed/seed.mjs` with deterministic fixtures in `firebase/seed/seed_data.mjs`.

### 5.1 Production Protection & Safety Guarantees

The script verifies environment variables before execution:
```javascript
if (!process.env.FIREBASE_AUTH_EMULATOR_HOST || !process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('FATAL: SAFETY VIOLATION PREVENTED');
  process.exit(1);
}
```
**Under no circumstances will the seed script write to or mutate a production Firebase project.**

### 5.2 Idempotency

Running the seed script once or multiple times produces the exact same result without duplicate documents:
- Auth accounts are queried first: created if missing, updated if existing.
- Firestore documents use deterministic IDs and are overwritten cleanly.
- Event counters are automatically validated against active registrations upon completion.

### 5.3 Demo Accounts Catalog

All demo accounts share the development password: `DemoPassword123!`

| Role | UID | Email | Password | Display Name |
| :--- | :--- | :--- | :--- | :--- |
| **Student 1** | `demo_student_01` | `student1@demo.com` | `DemoPassword123!` | Nguyen Van A (Student) |
| **Student 2** | `demo_student_02` | `student2@demo.com` | `DemoPassword123!` | Tran Thi B (Student) |
| **Organizer 1** | `demo_organizer_01` | `organizer1@demo.com` | `DemoPassword123!` | Le Van C (GDSC Organizer) |
| **Organizer 2** | `demo_organizer_02` | `organizer2@demo.com` | `DemoPassword123!` | Pham Thi D (Sports & Arts Club) |
| **Admin** | `demo_admin_01` | `admin1@demo.com` | `DemoPassword123!` | CampusHub Administrator |

### 5.4 Seed Events Catalog

All event timestamps are calculated dynamically relative to runtime (`now`):

| Event ID | Title | Category | Status | Capacity | Reg / Checked-in | Organizer |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `demo_event_tech_flutter_01` | Flutter Mobile Dev Meetup & Workshop | Technology | `published` | 50 | 1 / 0 | `demo_organizer_01` |
| `demo_event_full_ai_hackathon_02` | Campus AI Hackathon 2026 Finals (Full) | Technology | `published` | 2 | 2 / 0 (Full) | `demo_organizer_01` |
| `demo_event_workshop_resume_03` | Tech Resume & Interview Mastery Workshop | Workshop | `published` | 30 | 0 / 0 | `demo_organizer_02` |
| `demo_event_outdoor_badminton_04` | Campus Annual Badminton Tournament (Outdoor) | Sport | `published` | 16 | 1 / 0 | `demo_organizer_02` |
| `demo_event_music_acoustic_night_05` | Acoustic Sunset Concert & Jam Session | Music | `published` | 100 | 0 / 0 | `demo_organizer_01` |
| `demo_event_past_robotics_symposium_06` | Autonomous Robotics & IoT Showcase 2026 (Past) | Technology | `finished` | 40 | 1 / 1 | `demo_organizer_01` |
| `demo_event_cancelled_football_07` | Inter-Faculty Football Semi-Finals | Sport | `cancelled` | 22 | 0 / 0 | `demo_organizer_02` |
| `demo_event_draft_cloud_study_08` | Google Cloud Study Jam Session | Workshop | `draft` | 25 | 0 / 0 | `demo_organizer_01` |
| `demo_event_music_rock_fest_09` | Rock the Quad Campus Music Festival | Music | `published` | 200 | 1 / 0 | `demo_organizer_02` |
| `demo_event_sport_marathon_10` | Campus Green Ribbon Charity Run 5KM | Sport | `published` | 150 | 2 / 0 | `demo_organizer_01` |

### 5.5 Seed Registrations Catalog

Deterministic document IDs follow `${eventId}_${userId}`:

| Registration ID | Event ID | User ID | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `demo_event_tech_flutter_01_demo_student_01` | `demo_event_tech_flutter_01` | `demo_student_01` | `registered` | Active ticket |
| `demo_event_full_ai_hackathon_02_demo_student_01` | `demo_event_full_ai_hackathon_02` | `demo_student_01` | `registered` | Slot 1/2 of full event |
| `demo_event_full_ai_hackathon_02_demo_student_02` | `demo_event_full_ai_hackathon_02` | `demo_student_02` | `registered` | Slot 2/2 of full event |
| `demo_event_outdoor_badminton_04_demo_student_01` | `demo_event_outdoor_badminton_04` | `demo_student_01` | `registered` | Active ticket |
| `demo_event_music_acoustic_night_05_demo_student_02` | `demo_event_music_acoustic_night_05` | `demo_student_02` | `cancelled` | Student cancelled before cutoff |
| `demo_event_past_robotics_symposium_06_demo_student_01` | `demo_event_past_robotics_symposium_06` | `demo_student_01` | `checkedIn` | Checked-in participant ticket |
| `demo_event_music_rock_fest_09_demo_student_02` | `demo_event_music_rock_fest_09` | `demo_student_02` | `registered` | Active ticket |
| `demo_event_sport_marathon_10_demo_student_01` | `demo_event_sport_marathon_10` | `demo_student_01` | `registered` | Active ticket |
| `demo_event_sport_marathon_10_demo_student_02` | `demo_event_sport_marathon_10` | `demo_student_02` | `registered` | Active ticket |

---

## 6. Verification & Test Execution Commands

### 6.1 Run Seed Data in Emulator

```powershell
$env:CI="true"
firebase.cmd emulators:exec --only auth,firestore --project demo-campushub --config firebase.security-test.json "npm.cmd --prefix notification-server run seed"
```

### 6.2 Run Complete Firebase Test Suite (73 Tests)

Runs ownership rules, storage rules, notification rules, worker, and seed idempotency tests in one isolated session:

```powershell
$env:CI="true"
firebase.cmd emulators:exec --only auth,firestore,storage --project demo-campushub --config firebase.security-test.json "npm.cmd --prefix notification-server run test:all"
```

### 6.3 Run Storage Security Rules Tests Separately (10 Tests)

```powershell
$env:CI="true"
firebase.cmd emulators:exec --only firestore,storage --project demo-campushub --config firebase.security-test.json "npm.cmd --prefix notification-server run test:storage"
```

### 6.4 Run Flutter App Regression Tests (322 Tests)

```powershell
dart analyze
flutter test
```

---

## 7. Cross-Member Review Boundaries

### 7.1 Reviewer: Member 1 (Authentication / Roles)
- **Role Escalation Protection**: Verified that `/users/{uid}` rules disallow student-to-organizer or organizer-to-admin escalation. Client self-creation is strictly pinned to `role: student`, `status: active`.
- **Event Manager Profile Lookup**: Added `allow get: if owns(uid) || isEventManager();` to `/users/{uid}` so Organizers/Admins can read student display names and emails on the check-in result screen without exposing global listings to non-admins.
- **Custom Claims**: Demo accounts populate both Auth custom claims (`role`) and Firestore user profile documents identically.

### 7.2 Reviewer: Member 4 (Registration / QR Check-in)
- **Reciprocal Invariant Protection**: Verified that `joinedAtomically`, `cancelledAtomically`, and `checkedInAtomically` enforce strict counter parity without allowing fabricated success or out-of-band counter writes.
- **Deterministic ID Enforcement**: Document format `${eventId}_${userId}` prevents duplicate registrations.
- **Participant Data Privacy**: Verified that organizers can only query registrations where `eventId` belongs to an event they own. Querying all registrations requires Admin role.

---

## 8. Production Deployment Checklist (For Future Release)

When the team prepares to release to production:

1. [ ] **Review Rules**: Ensure `firestore.rules` and `storage.rules` have no syntax errors or loosened development rules.
2. [ ] **Verify Indexes**: Inspect `firestore.indexes.json` against all active queries in the build.
3. [ ] **Run Test Suites**: Confirm that `test:all` (73 tests) and `flutter test` (322 tests) PASS.
4. [ ] **Set Project Target**: Switch Firebase CLI to production project: `firebase use <production-project-id>`.
5. [ ] **Deploy Rules**: `firebase deploy --only firestore:rules,storage`.
6. [ ] **Deploy Indexes**: `firebase deploy --only firestore:indexes`. (Note: Cloud Firestore composite index building may take several minutes in Google Cloud console).
7. [ ] **Smoke Test**: Perform authenticated login, event creation, registration, and check-in smoke tests on staging/production.
