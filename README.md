# CampusHub — PRM393

Iteration 1 implements the authentication foundation using the existing feature-first MVVM, Riverpod and repository structure. Event, Registration, QR, Club, Notification, Admin dashboards and full Profile features remain TODO placeholders.

The source of truth is `docs/specifications/00_CampusHub_Master_Coder_Implementation_Blueprint.docx`. File ownership: Member 1 Auth/Profile/App Shell; Member 2 Discovery/Weather; Member 3 Organizer Events; Member 4 Registration/Ticket/Check-in; Member 5 Clubs/Notifications/Admin.

Read [the Iteration 1 report](docs/authentication_iteration_1.md) for the initial analysis, change list, recovery behavior, test results, setup and demo checklist.

## Requirements

- Flutter >= 3.44.0 and Dart >= 3.12.0. Verified with Flutter 3.47.3 / Dart 3.13.3.
- Dependencies are resolved in `pubspec.lock`; commit and reuse this lockfile.
- Android/iOS/Web scaffolds are included. iOS builds require macOS.
- Firebase configuration is intentionally missing. No credentials or fake production data are supplied.

## Configure and run

1. Run `flutter pub get`.
2. Choose the final Android application ID / iOS bundle ID before registering apps in Firebase.
3. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`.
4. Run `flutterfire configure` against your team's Firebase project. This replaces `lib/firebase_options.dart`. Follow the [official Firebase setup guide](https://firebase.google.com/docs/flutter/setup).
5. Enable Firebase Authentication → Email/Password and create Cloud Firestore.
6. Review and deploy `firestore.rules` to that project using Firebase CLI or the Firebase console. These rules cover Iteration 1 only and deny other collections; merge reviewed feature rules before later integrations.
7. Run `flutter run` on a connected Android device or `flutter run -d chrome`. Without Firebase configuration, the app displays a configuration error with Retry.

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
