# CampusHub — PRM393

Iteration 1 implements the authentication foundation using the existing feature-first MVVM, Riverpod and repository structure. Event, Registration, QR, Club, Notification, Admin dashboards and full Profile features remain TODO placeholders.

The source of truth is `docs/specifications/00_CampusHub_Master_Coder_Implementation_Blueprint.docx`. File ownership: Member 1 Auth/Profile/App Shell; Member 2 Discovery/Weather; Member 3 Organizer Events; Member 4 Registration/Ticket/Check-in; Member 5 Clubs/Notifications/Admin.

Read [the Iteration 1 report](docs/authentication_iteration_1.md) for the initial analysis, change list, recovery behavior, test results, setup and demo checklist.

## Requirements

For UC-065/066/073/074/075 notification setup, local Node push worker and Android
testing, see [Notifications setup](docs/notifications-setup.md).

- Flutter >= 3.44.0 and Dart >= 3.12.0. Verified with Flutter 3.47.3 / Dart 3.13.3.
- Dependencies are resolved in `pubspec.lock`; commit and reuse this lockfile.
- Android/iOS/Web scaffolds are included. iOS builds require macOS.
- Firebase is configured for the team project `campushub-prm-g2` on Windows and Web. Do not commit service-account keys or user passwords.

## Configure and run

1. Run `flutter pub get`.
2. Choose the final Android application ID / iOS bundle ID before registering those platforms in Firebase.
3. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`.
4. Re-run `flutterfire configure --project=campushub-prm-g2` when adding a new platform. Follow the [official Firebase setup guide](https://firebase.google.com/docs/flutter/setup).
5. Enable Firebase Authentication → Email/Password and create Cloud Firestore.
6. Deploy rule/index changes with `npx firebase-tools deploy --only firestore --project campushub-prm-g2`.
7. Run `flutter run -d windows` or `flutter run -d chrome`.

### Run with local demo data

Plain `flutter run -d windows` connects to the configured Firebase project.
For the seeded demo accounts, keep the local Auth (`9099`) and Firestore (`8087`)
emulators running and start the app with:

```powershell
flutter run -d windows --dart-define=USE_FIREBASE_EMULATOR=true
```

See [the emulator and seed setup](firebase/README.md) for local data preparation.
Changing the backend requires stopping and restarting the app. Cached sessions
that are explicitly rejected as invalid or expired are cleared so the app can
return to sign-in. Network failures and disabled accounts retain their error
state; Retry and Sign out remain available. A profile permission error requires
checking the selected backend and its deployed Firestore rules; Retry does not
grant access.

### Windows terminal output

Use the filtered runner to hide VM Service links and Firestore transaction
traces while keeping errors and connection status visible:

```powershell
.\scripts\run_windows.ps1
# For the local demo accounts:
.\scripts\run_windows.ps1 -Emulator
```

The runner disables DevTools startup and keeps the Flutter exit code. Additional
Flutter arguments can be passed after the script options. Direct `flutter run`
continues to show the standard Flutter/plugin output.

## Club logo uploads (Cloudinary)

Club logos are uploaded directly from the app to Cloudinary with an unsigned
upload preset. The API secret is never stored in this repository or shipped in
the Flutter application.

- Cloud name: `djznx3z7o`
- Unsigned preset: `campushub_club_logos_unsigned`
- Asset folder configured by the preset: `campushub/club_logos`
- Accepted formats: JPG, PNG, and WebP; maximum size: 5 MB

The defaults above work for the team environment. They can be overridden at
build time without changing source code:

```powershell
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=djznx3z7o --dart-define=CLOUDINARY_UPLOAD_PRESET=campushub_club_logos_unsigned
```

Deploy the updated `firestore.rules` before testing Club create/edit/join/leave
against the real Firebase project. Organizer and admin roles must still be
assigned by a trusted administrator.

Android SDK licenses still need acceptance on the checked development machine: `flutter doctor --android-licenses`.

## Verify

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/auth test/core/validators_test.dart test/widget_test.dart
flutter build web
```

52 authentication tests passed and `flutter analyze` reported no issues. Tests inject fake repositories / mocked Firebase SDKs and do not prove a real Firebase deployment works. After merging the Organizer foundation from remote main, four unrelated skeleton test files still lack `main`. The combined Auth/Organizer check reported 93 passing tests and 11 failing Organizer widget tests whose taps target an off-screen save button; Organizer code was preserved unchanged.

Do not rerun the original `scripts/setup_windows.ps1` / `setup_unix.sh` merely to start this iteration: those bootstrap scripts add dependencies for the entire project.

No passwords are persisted. New accounts receive `student/active`. Organizer/Admin roles must be provisioned through trusted project administration. Authenticated landing pages are minimal session/role destinations, ready for future modules.
