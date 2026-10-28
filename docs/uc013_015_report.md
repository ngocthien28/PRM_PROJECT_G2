# UC-013 / UC-014 / UC-015

Implemented on 2026-10-28.

## Changes

- UC-013: implemented `LoadingIndicator`, `AppErrorView`, and
  `AsyncValueView<T>`. Unknown exceptions show a generic message; mapped
  application errors show their readable message. Retry is optional. Loading
  and error states hide retained data. Profile and Edit Profile now use the
  shared view with profile reload; Splash uses the shared loading indicator.
- UC-014: added Auth/Profile repository flow tests covering registration,
  profile loading and editing, logout, login, error mapping, profile creation
  retry, and preservation of authorization fields. Added ProfileViewModel tests
  for duplicate submission, validation, failure, avatar cancellation, and an
  account switch during a pending save. The view model now validates inputs,
  reports missing sessions, prevents duplicate avatar selection, resets feedback
  when the account changes, and suppresses results from a previous account.
  Edit Profile initializes fields when the profile arrives and disables inputs
  while saving.
- UC-015: added a role matrix for shared, Organizer, Club management, scan,
  participants, and Admin URLs. Restricted route roots match complete path
  segments. Active students use shared routes; active organizers also use
  Organizer routes; active admins use all three groups. Guests go to login;
  missing, mismatched, disabled, loading, or failed profiles go to Splash.
  A locally stored profile is no longer emitted as session authority before the
  profile repository stream responds. Existing Firestore rules remain the
  enforcement layer for backend authorization.

## Verification

Passed: **16 tests** using Flutter tests with mocked Auth/Fake Firestore:

```powershell
flutter test test/core/async_value_view_test.dart test/auth/module_access_test.dart test/auth/auth_profile_flow_test.dart test/profile/profile_repository_test.dart
```

These tests validate application logic and repository behavior, not deployed
Firebase rules or a live device flow.

Blocked: `flutter test test/profile/profile_view_model_test.dart` cannot compile
because existing conflict markers remain in `lib/core/services/firebase_providers.dart`
and its dependencies. `flutter analyze` also fails on the pre-existing merge
conflicts throughout the repository. Its final run reported no diagnostics for
the files changed or added for these three use cases, but this is not a passing
whole-project analysis or build.

The existing merge conflicts and Git merge state were preserved. After resolving
them, run:

```powershell
flutter test test/auth test/profile test/core/async_value_view_test.dart test/navigation
flutter analyze
```

Manual integration checks after the project compiles: open restricted URLs as
each role; downgrade a signed-in admin; disable the current account; retry a
failed profile load; switch accounts during a save or avatar selection; verify
that edited profile fields persist after sign-out and sign-in.

## Publication verification

Before pushing, the changes were applied to a separate worktree based on
`origin/main` at `fc23296`. That checkout has no unresolved merge conflicts.
The original workspace and its in-progress merge were preserved.

- **82 tests passed** with the Auth, Profile, shared async widget, and Navigation
  suites listed above, including all five new ProfileViewModel tests.
- `flutter analyze`: **No issues found**.
- The ProfileViewModel test setup keeps active provider subscriptions so the
  controlled session stream emits values instead of remaining paused.

The earlier blocked results describe the original workspace, not the clean
checkout used for publication. Live Firebase and device checks remain manual.
