# CampusHub Club and Cloudinary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the nine approved Club, authorization, scaffold, membership, and CRUD features with Cloudinary logo uploads and Firestore persistence.

**Architecture:** Flutter screens consume Riverpod providers and view models; those call a `ClubRepository` whose Firestore implementation enforces authorization and transaction rules. A separately injected `ClubLogoService` uploads `XFile` bytes to the configured unsigned Cloudinary endpoint, keeping network and storage concerns out of UI code.

**Tech Stack:** Flutter 3.44+, Dart 3.12+, Riverpod 3, GoRouter 18, Firebase Auth, Cloud Firestore, `http`, `image_picker`, Cloudinary unsigned Upload API, flutter_test, mocktail, fake_cloud_firestore.

**Spec:** `docs/superpowers/specs/2026-10-13-club-cloudinary-design.md`

## Global Constraints

- Preserve the existing feature-first MVVM/repository structure; screens never access Firebase or Cloudinary directly.
- Use Cloudinary cloud `djznx3z7o`, unsigned preset `campushub_club_logos_unsigned`, and preset folder `campushub/club_logos`; never add an API secret.
- Club logos are optional JPG/JPEG/PNG/WebP files with a 5 MB maximum.
- Firestore is the source of truth for `clubs` and `club_memberships`; membership counts change only in transactions.
- Cancel is a soft delete (`status=cancelled`); never delete Club or Membership history.
- Student may read/join/leave; Organizer manages owned Clubs; Admin manages every Club.
- Preserve unrelated user changes, including existing generated Windows plugin files.
- Commit messages use `KhangLG_FunctionName_Add`, `KhangLG_FunctionName_Edit`, or `KhangLG_FunctionName_Delete`.

## Review Focus

- A Firestore timestamp can be null during a local pending write; model parsing must remain usable without crashing.
- A rejoin after `left` must increment `memberCount` once, while a duplicate active join must not increment it.
- Concurrent leave requests must not reduce `memberCount` below zero.
- An organizer must not edit/cancel another organizer's Club even when navigating directly to the route.
- A Cloudinary upload can succeed before Firestore fails; the UI must report the write failure and never replace the stored URL with an invalid value.

---

### Task 1: Club, Membership, and Notification Contracts

**Files:**
- Modify: `lib/shared/enums/membership_status.dart`
- Create: `lib/shared/enums/club_status.dart`
- Modify: `lib/features/clubs/data/models/club_model.dart`
- Modify: `lib/features/clubs/data/models/club_membership.dart`
- Modify: `lib/features/notifications/data/models/app_notification.dart`
- Modify: `lib/features/clubs/data/club_repository.dart`
- Modify: `lib/features/notifications/data/notification_repository.dart`
- Modify: `lib/core/constants/firestore_collections.dart`
- Create: `test/clubs/club_models_test.dart`

**Interfaces:**
- Consumes: `AppUser`, Firestore `Timestamp`, existing enum serialization conventions.
- Produces: `ClubStatus`, `MembershipRole`, `MembershipStatus`, `ClubModel`, `ClubMembership`, `AppNotification`, `ClubRepository`, and `NotificationRepository` contracts used by every later task.

- [ ] **Step 1: Write failing model tests**

Add tests named `ClubModel round-trips Firestore fields`, `ClubModel tolerates pending null timestamps`, `ClubMembership uses deterministic id and round-trips`, and `AppNotification round-trips optional referenceId`. Assert exact field names from the spec and rejection of unknown enum values.

- [ ] **Step 2: Run model tests and verify failure**

Run: `flutter test test/clubs/club_models_test.dart`
Expected: FAIL because skeleton types and enum values do not exist.

- [ ] **Step 3: Implement the model and enum types**

Implement immutable constructors, `fromFirestore`/`fromMap`, create/update maps, and `copyWith`. Use `DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)` only as the pending-write timestamp fallback; malformed persisted enum values throw `AppException`.

- [ ] **Step 4: Define repository interfaces and collection constants**

Add `clubs`, `clubMemberships`, and `notifications` constants. Define `ClubRepository` methods for watching active Clubs, loading one Club, watching membership, join, leave, create, update, and cancel. Define `NotificationRepository.watchInbox`, `markRead`, and `saveDeviceToken` without a runtime implementation.

- [ ] **Step 5: Run tests and static analysis for the files**

Run these commands in order:

```powershell
dart format lib/shared/enums lib/features/clubs/data lib/features/notifications/data test/clubs/club_models_test.dart
flutter test test/clubs/club_models_test.dart
flutter analyze lib/shared/enums lib/features/clubs/data lib/features/notifications/data
```
Expected: formatting succeeds, tests pass, and analyzer reports no issues.

- [ ] **Step 6: Commit**

```powershell
git add lib/shared/enums lib/features/clubs/data lib/features/notifications/data lib/core/constants/firestore_collections.dart test/clubs/club_models_test.dart
git commit -m "KhangLG_ClubNotificationModelContracts_Add"
```

### Task 2: Cloudinary Club Logo Service

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `lib/core/services/club_logo_service.dart`
- Create: `lib/core/services/cloudinary_club_logo_service.dart`
- Create: `test/clubs/cloudinary_club_logo_service_test.dart`

**Interfaces:**
- Consumes: `XFile` from `image_picker`, `http.Client`.
- Produces: `ClubLogoUpload { secureUrl, publicId }` and `ClubLogoService.uploadLogo(XFile file)`.

- [ ] **Step 1: Add failing service tests**

Test valid multipart upload fields and response parsing, rejection of unsupported extension, rejection above 5 MB, non-2xx Cloudinary response mapping, and malformed success response mapping. Use a fake/mock HTTP client; no real upload in tests.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/clubs/cloudinary_club_logo_service_test.dart`
Expected: FAIL because the service does not exist.

- [ ] **Step 3: Add `http` and `image_picker` dependencies**

Run: `flutter pub add http image_picker`
Expected: `pubspec.yaml` and lockfile contain compatible versions.

- [ ] **Step 4: Implement Cloudinary upload service**

Use default compile-time values `CLOUDINARY_CLOUD_NAME=djznx3z7o` and `CLOUDINARY_UPLOAD_PRESET=campushub_club_logos_unsigned`. POST multipart bytes to `/v1_1/{cloud}/image/upload`, include only `file` and `upload_preset`, and parse `secure_url` and `public_id`. Never define API key/secret fields.

- [ ] **Step 5: Run tests and analysis**

Run these commands in order:

```powershell
dart format lib/core/services/club_logo_service.dart lib/core/services/cloudinary_club_logo_service.dart test/clubs/cloudinary_club_logo_service_test.dart
flutter test test/clubs/cloudinary_club_logo_service_test.dart
flutter analyze lib/core/services
```
Expected: PASS and no analyzer issues.

- [ ] **Step 6: Commit**

```powershell
git add pubspec.yaml pubspec.lock lib/core/services/club_logo_service.dart lib/core/services/cloudinary_club_logo_service.dart test/clubs/cloudinary_club_logo_service_test.dart
git commit -m "KhangLG_ClubLogoCloudinary_Add"
```

### Task 3: Organizer/Admin Authorization and Firestore Club Repository

**Files:**
- Modify: `lib/features/clubs/data/club_repository_impl.dart`
- Create: `test/clubs/club_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 models/contracts, Task 2 `ClubLogoService`, `FirebaseFirestore`, and `AppUser` actor.
- Produces: `ClubRepositoryImpl` with transactional membership changes and owner/admin authorization.

- [ ] **Step 1: Write failing repository tests**

Use `FakeFirebaseFirestore` and a fake logo service. Test active list filtering, Club lookup, create with manager membership, student create rejection, organizer non-owner update/cancel rejection, admin override, cancelled edit rejection, optional/replacement logo data, duplicate active join rejection, rejoin after leave, manager leave rejection, and member count never below zero.

- [ ] **Step 2: Run repository tests and verify failure**

Run: `flutter test test/clubs/club_repository_test.dart`
Expected: FAIL because `ClubRepositoryImpl` remains a skeleton.

- [ ] **Step 3: Implement read and authorized CRUD methods**

Implement the exact Task 1 interface. Create uses a batch for Club plus manager membership. Update preserves `ownerId`, `memberCount`, `createdAt`, and existing logo when no replacement is selected. Cancel updates only status and timestamp.

- [ ] **Step 4: Implement transactional join/leave**

Join reads Club and deterministic membership in one transaction, rejects cancelled/duplicate/manager cases, and increments once. Leave requires active member status and writes `max(memberCount - 1, 0)` in the same transaction.

- [ ] **Step 5: Run repository tests and analysis**

Run these commands in order:

```powershell
dart format lib/features/clubs/data/club_repository_impl.dart test/clubs/club_repository_test.dart
flutter test test/clubs/club_repository_test.dart
flutter analyze lib/features/clubs/data
```
Expected: PASS and no analyzer issues.

- [ ] **Step 6: Commit**

```powershell
git add lib/features/clubs/data/club_repository_impl.dart test/clubs/club_repository_test.dart
git commit -m "KhangLG_OrganizerAdminAuthorization_Add"
```

### Task 4: Providers, ViewModels, Routes, and Scaffolds

**Files:**
- Modify: `lib/core/services/firebase_providers.dart`
- Modify: `lib/features/clubs/presentation/viewmodels/club_view_model.dart`
- Modify: `lib/core/routing/route_names.dart`
- Modify: `lib/core/routing/route_guards.dart`
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/features/notifications/presentation/screens/notification_screen.dart`
- Modify: `lib/features/admin/presentation/screens/admin_dashboard_screen.dart`
- Create: `test/clubs/club_authorization_test.dart`

**Interfaces:**
- Consumes: Task 3 repository, existing auth/profile providers, GoRouter.
- Produces: repository/logo providers, Club list/detail/membership providers, mutation controller, and guarded route names used by UI tasks.

- [ ] **Step 1: Write failing authorization/provider tests**

Test student management-route redirect, organizer create access, organizer edit ownership fallback in the screen/repository boundary, admin access, mutation loading/error reset, and direct `/admin` access rejection for non-admin users.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/clubs/club_authorization_test.dart`
Expected: FAIL because Club providers/routes do not exist.

- [ ] **Step 3: Add dependency providers and Club view models**

Provide an injectable `http.Client`, `ClubLogoService`, and `ClubRepository`. Implement auto-disposed list/detail/membership providers and one action controller that prevents duplicate create/update/join/leave/cancel submissions and invalidates affected providers after success.

- [ ] **Step 4: Add route names, guards, and scaffold screens**

Add exact spec routes. Reuse `sessionRedirect` for organizer/admin prefixes and keep ownership enforcement in repository/UI after Club load. Implement honest Notification/Admin scaffold screens that do not claim deferred features are complete.

- [ ] **Step 5: Run tests and analysis**

Run these commands in order:

```powershell
dart format lib/core/services/firebase_providers.dart lib/features/clubs/presentation/viewmodels lib/core/routing lib/features/notifications/presentation/screens lib/features/admin/presentation/screens test/clubs/club_authorization_test.dart
flutter test test/clubs/club_authorization_test.dart
flutter analyze lib/core/routing lib/features/clubs/presentation/viewmodels
```
Expected: PASS and no analyzer issues.

- [ ] **Step 6: Commit**

```powershell
git add lib/core/services/firebase_providers.dart lib/features/clubs/presentation/viewmodels lib/core/routing lib/features/notifications/presentation/screens lib/features/admin/presentation/screens test/clubs/club_authorization_test.dart
git commit -m "KhangLG_ClubNotificationAdminScaffold_Add"
```

### Task 5: Club List and Club Detail

**Files:**
- Modify: `lib/features/clubs/presentation/screens/club_list_screen.dart`
- Modify: `lib/features/clubs/presentation/screens/club_detail_screen.dart`
- Create: `lib/features/clubs/presentation/widgets/club_card.dart`
- Modify: `lib/core/routing/app_router.dart`
- Create: `test/clubs/club_screens_test.dart`

**Interfaces:**
- Consumes: Task 4 providers/routes and Task 1 models.
- Produces: responsive public Club discovery and detailed membership/management actions.

- [ ] **Step 1: Write failing widget tests**

Test list loading, empty, error/retry, one-column and two-column success, navigation to detail, placeholder/network logo rendering, detail fields, Join/Leave state, Create visibility for organizer/admin, and Edit/Cancel visibility only for owner/admin.

- [ ] **Step 2: Run widget tests and verify failure**

Run: `flutter test test/clubs/club_screens_test.dart`
Expected: FAIL because screens remain skeletons.

- [ ] **Step 3: Implement Club List**

Use `LayoutBuilder` for one column on narrow width and two columns at 700 px or greater. Render loading, empty, error/retry, and active Club cards. Navigate by route constants.

- [ ] **Step 4: Implement Club Detail**

Render fields and membership state. Wire Join/Leave to the action controller. Show management actions only when `actor.role == admin || club.ownerId == actor.uid`. Keep repository authorization authoritative.

- [ ] **Step 5: Run widget tests and analysis**

Run these commands in order:

```powershell
dart format lib/features/clubs/presentation test/clubs/club_screens_test.dart
flutter test test/clubs/club_screens_test.dart
flutter analyze lib/features/clubs/presentation
```
Expected: PASS and no analyzer issues.

- [ ] **Step 6: Commit**

```powershell
git add lib/features/clubs/presentation/screens/club_list_screen.dart lib/features/clubs/presentation/screens/club_detail_screen.dart lib/features/clubs/presentation/widgets/club_card.dart lib/core/routing/app_router.dart test/clubs/club_screens_test.dart
git commit -m "KhangLG_ClubListDetailJoinLeave_Add"
```

### Task 6: Create, Edit, and Cancel Club UI

**Files:**
- Modify: `lib/features/clubs/presentation/screens/manage_club_screen.dart`
- Modify: `lib/features/clubs/presentation/screens/club_detail_screen.dart`
- Create: `lib/features/clubs/presentation/widgets/club_form.dart`
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/core/utils/validators.dart`
- Create: `test/clubs/club_form_test.dart`

**Interfaces:**
- Consumes: Task 4 action controller, Task 2 `XFile` upload boundary, existing actor provider.
- Produces: reusable Create/Edit form and confirmed Cancel interaction.

- [ ] **Step 1: Write failing form/action tests**

Test name required/3-80, description required/20-1000, optional logo, unsupported/oversized logo feedback from service, existing logo preview, Create and Edit initial values, double-submit prevention, successful navigation, failed submit retaining form values, Cancel confirmation dismissal, and confirmed soft cancel.

- [ ] **Step 2: Run form tests and verify failure**

Run: `flutter test test/clubs/club_form_test.dart`
Expected: FAIL because the Club form is a skeleton.

- [ ] **Step 3: Implement reusable Club form**

Use `Form`, existing validator style, `ImagePicker.pickImage(source: ImageSource.gallery)`, local preview from `XFile.readAsBytes`, and action-state button disabling. Do not import `dart:io`.

- [ ] **Step 4: Implement Create/Edit routes and Cancel confirmation**

Create receives no Club; Edit loads by ID rather than trusting route `extra`. Cancel uses `showDialog<bool>` and invokes the repository-backed action only after confirmation.

- [ ] **Step 5: Run tests and analysis**

Run these commands in order:

```powershell
dart format lib/features/clubs/presentation lib/core/routing/app_router.dart lib/core/utils/validators.dart test/clubs/club_form_test.dart
flutter test test/clubs/club_form_test.dart
flutter analyze lib/features/clubs/presentation lib/core/routing/app_router.dart
```
Expected: PASS and no analyzer issues.

- [ ] **Step 6: Commit Create/Edit additions**

```powershell
git add lib/features/clubs/presentation/screens/manage_club_screen.dart lib/features/clubs/presentation/widgets/club_form.dart lib/core/routing/app_router.dart lib/core/utils/validators.dart test/clubs/club_form_test.dart
git commit -m "KhangLG_CreateEditClub_Add"
```

- [ ] **Step 7: Commit Cancel behavior separately if its diff is independently reviewable**

```powershell
git add lib/features/clubs/presentation/screens/club_detail_screen.dart test/clubs/club_form_test.dart
git commit -m "KhangLG_CancelClub_Add"
```

If Cancel shares inseparable hunks with the form commit, keep one commit and use `KhangLG_ClubManagement_Add` rather than staging partial hunks unsafely.

### Task 7: Firestore Rules, Indexes, Documentation, and Full Verification

**Files:**
- Modify: `firestore.rules`
- Modify: `firestore.indexes.json` if present; otherwise create it.
- Modify: `README.md`
- Modify: `test/clubs/club_view_model_test.dart`
- Test: all `test/clubs/**`

**Interfaces:**
- Consumes: final collection schema and repository queries.
- Produces: deployable Rules/indexes, setup guidance, and completed integration coverage.

- [ ] **Step 1: Replace the placeholder Club ViewModel test**

Cover provider refresh after mutations, loading lock, repository error preservation, and the five Review Focus cases not already pinned by repository/widget tests.

- [ ] **Step 2: Run the Club test suite and verify current gaps**

Run: `flutter test test/clubs`
Expected: FAIL until remaining provider behavior and rules-aligned assumptions are corrected.

- [ ] **Step 3: Add strict Firestore Rules and indexes**

Rules validate exact Club/Membership fields, owner/admin CRUD, student self-membership writes, active status, immutable ownership/timestamps/count protections, and no hard deletes. Add the `clubs(status, nameLower)` and `club_memberships(userId, status)` indexes required by actual queries.

- [ ] **Step 4: Document setup and demo**

Document the non-secret Cloudinary cloud/preset, `--dart-define` overrides, Firebase collections/index deployment, seed data expectations, and demo flow Create -> Edit -> Join -> Leave -> Cancel. Explicitly state that the Cloudinary secret is never stored in the app.

- [ ] **Step 5: Run formatter, targeted tests, analyzer, and regression tests**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter test test/clubs
flutter analyze
flutter test
```

Expected: Club tests and analyzer pass. Any unrelated pre-existing full-suite failures are recorded with exact test names and output.

- [ ] **Step 6: Commit**

```powershell
git add firestore.rules firestore.indexes.json README.md test/clubs/club_view_model_test.dart
git commit -m "KhangLG_ClubIntegration_Edit"
```

- [ ] **Step 7: Verify commit and working-tree scope**

Run: `git log --oneline -10; git status --short; git diff --check`
Expected: all feature commits follow the requested naming convention, no secret is tracked, and only known unrelated user changes remain unstaged.
