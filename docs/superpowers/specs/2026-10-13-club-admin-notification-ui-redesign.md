# Club, Admin, and Notification UI Redesign

## Goal

Redesign the Club, Admin Dashboard, and Notification experiences so they are
easy to understand and operate on Windows, while remaining responsive on
mobile and web. Fix the current form validation, mouse focus, save, and
navigation defects without changing the established Club data model.

## Design principles

- Every screen must have an obvious next action and an obvious way back.
- Child screens use push/pop navigation. Root destinations use go navigation.
- Desktop content is constrained to readable widths instead of stretching
  controls across the entire window.
- Mouse, keyboard, Tab, Enter, and Escape interactions must behave predictably.
- Validation explains the problem and updates as soon as the user corrects it.
- Destructive actions require confirmation and produce visible success/error
  feedback.
- Loading, empty, error, and success states are intentionally designed.

## Shared navigation shell

Admin and organizer experiences use a responsive navigation component:

- Desktop: navigation rail/sidebar with Dashboard, Clubs, Notifications, and
  Sign out.
- Narrow layouts: app bar actions and a compact navigation drawer.
- The current destination is visibly selected.
- Direct deep links receive a safe fallback back action to the user's role
  dashboard.

Student navigation keeps the existing home experience but uses the same Club
and Notification visual language.

## Admin Dashboard

- Header includes page title, short description, refresh, and role identity.
- Compact statistic cards show Users, Clubs, Events, and Active memberships.
- Quick actions open Clubs and Notifications.
- Cards use responsive two-column desktop and one-column mobile layouts.
- Loading uses skeleton/progress UI; errors show a readable message and Retry.
- Dashboard statistics remain backed by Firestore and are admin-only.

## Club List

- Header includes Back/Home, title, active Club count, search, and a labeled
  Create Club action for organizer/admin users.
- Search filters the locally received active Club list by name and description.
- Empty state distinguishes no Clubs from no search results.
- Club cards show logo/fallback, name, description, member count, and a clear
  View details action.
- Opening Create or Detail pushes a child route so Back returns to the list.

## Create and Edit Club

- A centered form card has a maximum width and clear sections for basic
  information and logo.
- Club name accepts 3–80 trimmed characters.
- Description accepts 20–1000 trimmed characters.
- Both fields show live character counters and revalidate after the first
  submission attempt.
- Dedicated FocusNodes and text input actions support mouse selection, Tab,
  Shift+Tab, Enter/next, and keyboard submission where appropriate.
- Clicking outside fields dismisses focus without blocking future clicks.
- Logo selection shows a preview, filename, replace, and remove actions.
- Existing logo remains unchanged during Edit unless a replacement is chosen.
- Cancel returns to the previous screen without saving.
- Save disables once, shows progress, preserves typed input on failure, and
  displays a readable error.
- Successful Create/Edit replaces the form with Club Detail while preserving a
  route back to Club List.

## Club Detail

- A constrained hero layout displays logo, Club name, description, status, and
  member count.
- Student Join/Leave is a prominent primary action with progress feedback.
- Organizer/admin Edit and Cancel actions are visually separated.
- Cancel requires confirmation that explains the Club will be hidden rather
  than deleted.
- Successful cancellation returns to Club List and shows a success message.
- App bar Back always works; direct links fall back to Club List.

## Notifications

- Replace the raw placeholder with the shared navigation and a designed empty
  state containing an icon, title, explanation, and Back/Dashboard action.
- Do not fabricate notification records or mark-as-read behavior; those remain
  separate future features.

## Error handling

- Translate repository and Cloudinary failures into concise snackbars or inline
  messages.
- Firestore loading must not appear as an indefinite spinner without context.
- Retry actions invalidate the appropriate Riverpod provider.
- Network images use loading and error fallbacks.

## Testing

- Widget tests cover validation boundaries and revalidation after editing.
- Widget tests use mouse taps to move between fields and activate Save.
- Navigation tests cover List → Create → Detail → Back, List → Detail → Edit →
  Detail → Back, and Cancel → List.
- Tests cover empty, loading, error, and populated states.
- Responsive tests exercise narrow and desktop surface sizes.
- Existing Club repository/model tests remain green.

## Out of scope

- Full Notification List, unread badge, and mark-as-read behavior.
- Admin moderation workflows beyond the existing statistics dashboard.
- Changes to the Club, membership, or notification Firestore schemas.
- A new design dependency or third-party UI framework.
