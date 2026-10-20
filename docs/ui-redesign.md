# CampusHub UI refresh

The app uses a shared teal, warm-white and gold design system. The visual refresh
covers Home, Club List, Club Detail, Create/Edit Club, Notifications, Admin
Dashboard, the Moderation scaffold and authentication forms. Existing repository
operations and notification delivery remain connected.

- A desktop workspace sidebar appears from 1120 logical pixels. Smaller windows
  and phones use bottom navigation; secondary screens retain an explicit Back.
- Club search filters the current directory; Most members sorts real counts.
  Image errors fall back to generated artwork, never a broken image widget.
- Detail separates community information from membership/management actions.
  Management controls follow the same role and owner permissions as the repository.
- The club editor provides a live preview, readable validation and a persistent
  Save/Cancel footer. Preview rebuilds preserve the text controllers and focus.
- Notifications retain account isolation, read state, unread filtering and badge
  updates. Empty and error views provide a relevant next action.
- Dashboard counts come from Firestore. Its bars share one scale and do not show
  fabricated trends or activity. Moderation remains clearly marked as upcoming.
- Authentication keeps the existing validators and submission states in a new
  split desktop layout and a scrollable phone layout.

## Visual checks

`flutter test test/design/campus_ui_preview_test.dart` checks seven primary screens
at 1440×1000, 390×844 and phone text scaling at 160%, plus club search, editor live
preview, validation and pointer focus. It writes review images under
`build/ui-previews/`. All names/counts in these review images are test fixtures;
the application itself continues to display real Firebase data.

Examples: `clubs-desktop.png`, `detail-phone.png`, `form-desktop.png`,
`inbox-desktop.png`, `admin-desktop.png`, `home-phone.png`, `login-desktop.png`.

Restart the running app to review the global theme and navigation changes. No
additional service credentials, server deployment or Firebase Rules changes are
required for this visual refresh.

## Verification

- Targeted UI, inbox and navigation tests: 25 passed.
- Analyzer for the redesigned screens and tests: no issues.
- Full Flutter suite: 189 passed; two existing Organizer error-message tests fail
  because the expected save-error text differs from the generic error mapper.
- Windows debug build succeeded.
- Android debug build succeeded with the Android Studio JDK and a temporary
  2 GB Gradle heap override after the original 8 GB heap exhausted native memory.
