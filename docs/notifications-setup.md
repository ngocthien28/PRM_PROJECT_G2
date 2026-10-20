# Notifications: UC-065, UC-066, UC-073, UC-074, UC-075

## Implemented flow

Join/Leave writes membership, member count and one notification in a single
Firestore transaction. The inbox and unread badge observe the signed-in user's
notifications. Tapping an item marks it read and opens its full text. Read state
is stored in Firestore and survives logout and other devices.

The Node worker polls pending notifications, sends FCM and tracks per-device
delivery receipts. It resumes pending work on restart, retries transient errors,
removes invalid tokens, and expires push after 24 hours. Inbox records remain.
Android foreground messages use a local notification; background messages use
Android's FCM notification display. Stable notification IDs/tags avoid duplicated
tray entries. A crash between FCM accepting a message and receipt persistence can
still cause a retry (at-least-once delivery, not an exactly-once guarantee).

Windows supports the inbox and read state; native FCM is Android-only. Web push
and iOS are outside this implementation. Notifications are private to each user;
an admin does not automatically receive a student's personal Join/Leave notice.

UC-065 includes an admin-only Moderation route and navigation. The moderation
queue and resolution business logic remain UC-077/UC-084. UC-066 creates SQLite
schema version 2 (`cached_notifications`, keyed by user and notification ID),
including migration from v1. Full offline cache synchronization is UC-079.

## Start the local push worker (no Blaze deployment)

Requires Node.js 22+ and internet. Firestore usage remains subject to Spark quotas.
The computer must remain on with this terminal running to deliver push.

1. Firebase Console > Project settings > Service accounts > Firebase Admin SDK >
   Generate new private key. Keep the downloaded file outside the repository,
   e.g. `C:\campushub-secrets\service-account.json`. Never paste it into chat.
2. In PowerShell:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\campushub-secrets\service-account.json'
$env:GOOGLE_CLOUD_PROJECT = 'campushub-prm-g2'
cd notification-server
npm ci
npm start
```

The worker uses Application Default Credentials. Existing ADC configured by
Google Cloud CLI can also be used if it has Firestore and FCM send permissions.
Firebase CLI login alone is not ADC. No service-account secret belongs in Flutter.

The FCM HTTP v1 API must be enabled for the project. If sending reports an API
disabled error, enable Firebase Cloud Messaging API in Google Cloud Console for
`campushub-prm-g2`. The backend requires Firestore read/write and FCM send access.

## Firebase and Android

Android package: `com.example.campushub`; Firebase Android app:
`1:624735054316:android:4f6506ad7c0894868b78c9`.
`google-services.json` is app configuration, not an Admin SDK private key.

Deploy updated Firestore rules before running this client against production:

```powershell
npx firebase-tools deploy --only firestore:rules --project campushub-prm-g2
```

Then connect an Android device or launch an emulator with Google Play Services:

```powershell
flutter devices
flutter run -d <android-device-id>
```

Sign in and allow notification permission on Android 13+. Token registration waits
for the active profile and stores tokens under `users/{uid}/device_tokens`.
Logout removes the current token and clears local notifications before Firebase
sign-out. Token refresh updates the device registration. For a new install, open
and sign in once before testing background delivery. Force-stop in Android system
settings prevents receipt until the application is reopened.

## Manual acceptance checks

1. Sign in as a student; Join a club. Verify count +1, Leave button, one inbox
   entry and unread badge +1. Repeat Join requests must not create extra notices.
2. Open Notifications. Latest first. Tap an unread card: full text opens, read
   styling changes and badge decreases. Reopen/relogin: read state persists.
3. Enable Unread only. Read items disappear from the filtered list. Refresh and
   retry are available; a new account sees the empty state, not another inbox.
4. Leave the club. Count -1, Join button, one new Leave notification.
5. With worker running, perform Join/Leave from Windows while the same account is
   signed in on Android. Check local notification in foreground and system tray
   in background. Open a push to view the inbox. One Firestore notice per action.
6. Stop worker, perform an action, restart worker: pending push is delivered.
   Log out Android and verify that its device token is removed.
7. Sign in as admin; open Moderation scaffold. Students cannot access its route.

## Automated verification

```powershell
flutter test
flutter analyze
cd notification-server
npm test
```

Rules integration tests run only against a demo emulator (requires JDK 21):

```powershell
npx firebase-tools emulators:exec --only firestore --project demo-campushub --config firebase.notifications-test.json "npm --prefix notification-server run test:rules"
```

Do not mark real-device push delivery verified until the credentialed worker and
Android foreground/background checks have actually been performed.

## Verification on 20 October 2026

- Android debug APK and Windows debug application built successfully.
- Flutter full suite: 167 passed, 2 failed. Existing Organizer failures are
  `event_form_submission_test.dart` (failed save sets a safe error state) and
  `event_form_view_model_test.dart` (exposes a safe error message when save fails).
  Both expect `Unable to save event. Please try again.` while the current error
  mapper returns `Something went wrong. Please try again.` No Organizer production
  logic was changed for this work.
- Backend payload tests: 2 passed. Emulator rules/delivery integration: 7 passed.
- Backend dependency audit: no vulnerabilities after dependency patches.
- Production notification Rules were deployed to `campushub-prm-g2` on
  20 October 2026 after explicit user approval. Firebase CLI reported successful
  compilation and release. Real-client Join/Leave and inbox checks remain to be
  performed after restarting the app and signing in again.
- Real FCM delivery has not been verified: no Android device was connected and
  no backend ADC/service-account credential has been configured in this task.
- No project commit or push was made. Incidental formatter changes to unrelated
  files were backed up in the named Git stash
  `codex-backup-incidental-formatting-notifications`; notification changes remain
  in the working tree for review.
