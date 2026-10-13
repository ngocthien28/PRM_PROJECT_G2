# Club, Admin, and Notification UI Redesign Implementation Plan

**Spec:** `docs/superpowers/specs/2026-10-13-club-admin-notification-ui-redesign.md`

## Objective

Deliver a responsive, consistent Club/Admin/Notification experience and fix
the Windows form focus, live validation, Save, and navigation defects.

## Task 1: Establish UI regression tests

**Files**

- Add `test/clubs/manage_club_screen_test.dart`
- Add `test/clubs/club_navigation_test.dart`
- Extend `test/navigation/role_navigation_test.dart`

**RED cases**

1. A 20-character trimmed description is valid and 19 characters is invalid.
2. After a failed submit, editing a field clears its obsolete validation error.
3. Mouse taps can move focus name → description → Save on Windows-style UI.
4. Create/Edit screens expose Cancel and Back actions.
5. Detail exposes Back; successful cancellation navigates to Club List.
6. Admin and Notification screens expose responsive navigation/empty states.

**Verification**

```powershell
flutter test test/clubs/manage_club_screen_test.dart test/clubs/club_navigation_test.dart test/navigation/role_navigation_test.dart
```

Expected: new assertions fail for missing behavior, not compilation mistakes.

## Task 2: Shared responsive navigation and page primitives

**Files**

- Add `lib/shared/widgets/campus_page_header.dart`
- Add `lib/shared/widgets/empty_state_card.dart`
- Add `lib/shared/widgets/responsive_admin_shell.dart`
- Edit `lib/shared/widgets/role_navigation_actions.dart`

**Implementation**

- Create constrained page header and empty-state components.
- Create desktop navigation rail and narrow-layout drawer/app-bar behavior.
- Centralize role dashboard fallback and sign-out action.
- Preserve push/pop for child routes.

**Verification**

```powershell
flutter analyze lib/shared/widgets test/navigation
flutter test test/navigation/role_navigation_test.dart
```

**Commit**

`KhangLG_ResponsiveNavigation_Edit`

## Task 3: Club form behavior and visual redesign

**Files**

- Edit `lib/features/clubs/presentation/screens/manage_club_screen.dart`
- Optionally add `lib/features/clubs/presentation/widgets/club_logo_picker.dart`
- Extend `test/clubs/manage_club_screen_test.dart`

**Implementation**

- Use named controllers, FocusNodes, and a validation mode that switches to
  `onUserInteraction` after the first failed submit.
- Trim values consistently and show live 3–80 / 20–1000 counters.
- Add constrained card layout, section labels, logo preview/replace/remove,
  Cancel, and progress-aware Save.
- Use mouse-safe GestureDetector focus dismissal.
- Pop/replace routes without destroying the list history.

**Verification**

```powershell
flutter test test/clubs/manage_club_screen_test.dart
flutter analyze lib/features/clubs/presentation/screens/manage_club_screen.dart
```

**Commit**

`KhangLG_ClubFormUI_Edit`

## Task 4: Club List and Detail redesign

**Files**

- Edit `lib/features/clubs/presentation/screens/club_list_screen.dart`
- Edit `lib/features/clubs/presentation/screens/club_detail_screen.dart`
- Edit `lib/core/routing/app_router.dart`
- Extend `test/clubs/club_navigation_test.dart`

**Implementation**

- Add constrained responsive Club cards, search, active count, labeled Create,
  image loading/error states, and designed empty/no-results states.
- Push Create/Detail/Edit routes.
- Add robust Back fallback for deep links.
- Add responsive Detail hero and grouped actions.
- After cancellation, navigate to Club List with explicit success feedback.

**Verification**

```powershell
flutter test test/clubs
flutter analyze lib/features/clubs lib/core/routing
```

**Commit**

`KhangLG_ClubListDetailUI_Edit`

## Task 5: Admin Dashboard redesign

**Files**

- Edit `lib/features/admin/presentation/screens/admin_dashboard_screen.dart`
- Extend `test/admin/admin_repository_test.dart`
- Add `test/admin/admin_dashboard_screen_test.dart`

**Implementation**

- Apply responsive admin shell.
- Add title/description, refresh, compact statistics, and quick actions.
- Improve loading and error states while retaining Firestore-backed counts.

**Verification**

```powershell
flutter test test/admin test/navigation/role_navigation_test.dart
flutter analyze lib/features/admin
```

**Commit**

`KhangLG_AdminUI_Edit`

## Task 6: Notification empty-state redesign

**Files**

- Edit `lib/features/notifications/presentation/screens/notification_screen.dart`
- Add `test/notifications/notification_screen_test.dart`

**Implementation**

- Apply shared navigation/header.
- Replace placeholder text with a designed, truthful empty state.
- Provide Back/Dashboard action without inventing notification data.

**Verification**

```powershell
flutter test test/notifications test/navigation/role_navigation_test.dart
flutter analyze lib/features/notifications
```

**Commit**

`KhangLG_NotificationUI_Edit`

## Task 7: Integration verification and documentation

**Files**

- Edit `README.md` with UI test checklist if needed.

**Verification**

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze lib/features/clubs lib/features/admin lib/features/notifications lib/shared/widgets lib/core/routing test/clubs test/admin test/notifications test/navigation
flutter test test/clubs test/admin test/notifications test/navigation test/widget_test.dart
git diff --check
```

Run full `flutter test` and report any unrelated pre-existing failures by exact
test name. Manually verify Windows mouse focus, Tab order, Cloudinary preview,
Create → Detail → Back, Edit → Detail → Back, and Cancel → List → Dashboard.

**Commit**

`KhangLG_ClubAdminNotificationUI_Edit`

## Push

After all scoped checks pass and the worktree contains no unrelated changes:

```powershell
git push origin main
```
