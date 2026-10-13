# CampusHub Club, Authorization, and Cloudinary Design

## Goal

Implement the following assigned features as one coherent vertical slice:

1. Club / Notification Model Contracts
2. Organizer / Admin Authorization
3. Club / Notification / Admin Scaffold
4. Club List
5. Club Detail
6. Join / Leave Club
7. Create Club
8. Edit Club
9. Cancel Club

The implementation must follow the existing Flutter, Riverpod, MVVM, and repository structure. Firebase Authentication remains the identity source and Firestore remains the source of truth for Club and Membership data. Cloudinary replaces Firebase Storage only for Club logo storage.

Notification and Admin work in this scope is limited to shared contracts, routing/scaffolding, and authorization needed by the Club flow. Notification inbox, FCM, Admin Dashboard data, and moderation screens are outside this implementation.

## Architecture

The dependency flow is:

```text
Screen
  -> Riverpod ViewModel/Provider
    -> ClubRepository
      -> Firestore (clubs and club_memberships)
      -> CloudinaryService (Club logo uploads)
```

Screens must not call Firebase or Cloudinary directly. The repository coordinates Firestore writes and media upload. Providers inject all external dependencies so tests can use fakes.

## Models and Contracts

### ClubModel

Fields:

- `id`: Firestore document ID.
- `ownerId`: UID of the organizer who owns the Club.
- `name`: trimmed display name.
- `nameLower`: normalized lowercase name for search.
- `description`: trimmed Club description.
- `logoUrl`: nullable Cloudinary secure delivery URL.
- `logoPublicId`: nullable Cloudinary public identifier.
- `memberCount`: non-negative count of active memberships.
- `status`: `active` or `cancelled`.
- `createdAt`: server-backed creation timestamp.
- `updatedAt`: server-backed last-update timestamp.

The model provides Firestore serialization, deserialization, and immutable copy behavior. Missing optional media fields remain null. Invalid or unknown status values fail safely instead of silently granting access.

### ClubMembership

Fields:

- `id`: deterministic `${clubId}_${userId}`.
- `clubId`: associated Club ID.
- `userId`: member UID.
- `role`: `member` or `manager`.
- `status`: `active` or `left`.
- `joinedAt`: first join timestamp.
- `updatedAt`: last membership state change.

Create Club also creates an active manager membership for its owner without increasing the public student `memberCount`. Student join and leave operations update `memberCount` transactionally.

### AppNotification

Fields:

- `id`
- `userId`
- `title`
- `body`
- `type`
- `referenceId`
- `isRead`
- `createdAt`

`NotificationRepository` exposes the blueprint contract for watching an inbox, marking an item read, and saving a device token. Its runtime implementation, UI, FCM, and local cache are deferred.

### ClubRepository

The repository exposes:

- watch/list active Clubs.
- get a Club by ID.
- watch/read the current user's membership for a Club.
- join a Club.
- leave a Club.
- create a Club with an optional local logo.
- update a Club with an optional replacement logo.
- cancel a Club.

Create, update, and cancel receive the authenticated `AppUser` or an equivalent actor context. Authorization is enforced inside the repository as well as in routing and Firestore Rules.

## Cloudinary Logo Storage

Configuration:

- Cloud name: `djznx3z7o`
- Unsigned upload preset: `campushub_club_logos_unsigned`
- Asset folder configured by the preset: `campushub/club_logos`
- Upload endpoint: `https://api.cloudinary.com/v1_1/djznx3z7o/image/upload`

The Flutter client contains no Cloudinary API secret. The previously disclosed secret must be revoked outside the repository and is never used by this implementation.

`image_picker` supplies an `XFile`. `CloudinaryService` validates supported extensions and a 5 MB maximum, uploads bytes as multipart form data, and returns `secure_url` plus `public_id`. This bytes-based API works for Web and avoids depending on `dart:io` in shared code.

Logo upload is optional. Without a logo, the UI displays a deterministic placeholder. Create uploads a selected logo before writing the Club. Edit uploads a replacement before updating Firestore. Because unsigned clients cannot securely destroy Cloudinary assets, replaced or orphaned assets are retained; cleanup requires a future trusted backend. Cancelling a Club does not delete its logo.

Cloudinary configuration uses compile-time `--dart-define` values with the non-secret values above as documented development defaults. This keeps environment selection explicit while allowing the app to run without a secret file.

## Authorization

Roles are sourced from the authenticated user's Firestore profile:

- Student: list/detail active Clubs and join/leave them.
- Organizer: student permissions plus create Clubs and edit/cancel Clubs where `ownerId` matches the organizer UID.
- Admin: all organizer operations for every Club.

Authorization is applied in three places:

1. Route guards prevent navigation to management routes.
2. Screens hide or disable actions that are not available to the actor.
3. Repository checks and Firestore Rules reject unauthorized requests even if the client is modified.

Cancelled Clubs remain readable to their owner/admin for management history but are excluded from the public Club List. Students cannot join cancelled Clubs.

## Firestore Data and Transactions

Collections:

```text
clubs/{clubId}
club_memberships/{clubId_userId}
notifications/{notificationId}
```

### Create Club

1. Require an active organizer or admin.
2. Validate name and description.
3. Generate the Club document reference.
4. Upload an optional logo to Cloudinary.
5. Use a Firestore batch to create the Club and owner manager membership.
6. Return the persisted Club model.

### Edit Club

1. Read the current Club.
2. Require its owner or an admin.
3. Reject edits to a cancelled Club.
4. Validate the updated form.
5. Upload an optional replacement logo.
6. Update mutable fields while preserving ownership, counts, and creation time.

### Cancel Club

1. Read the current Club.
2. Require its owner or an admin.
3. Update only `status` and `updatedAt` to soft-delete the Club.
4. Retain memberships and logo metadata for history.

### Join Club

A Firestore transaction reads the Club and deterministic membership document. It requires an active Club and active student account. An existing active membership is rejected. A missing or `left` membership becomes active, and `memberCount` increments exactly once.

### Leave Club

A Firestore transaction requires an active member membership. It marks the membership `left` and decrements `memberCount` without allowing the count below zero. Manager memberships cannot leave through the student action.

## UI and Routing

Routes:

```text
/clubs                              signed-in users
/clubs/:clubId                      signed-in users
/organizer/clubs/new                organizer/admin
/organizer/clubs/:clubId/edit       owner organizer/admin
/notifications                      signed-in scaffold
/admin                              admin scaffold
```

### Club List

- Responsive one-column/two-column presentation.
- Logo, name, description preview, and member count.
- Loading, empty, error, retry, and success states.
- Create action for organizer/admin.
- Cancelled Clubs excluded from the public list.

### Club Detail

- Logo, name, description, status, and member count.
- Join/Leave action derived from the current user's membership.
- Edit/Cancel actions for owner/admin.
- Confirmation dialog before cancellation.
- Loading and errors remain recoverable.

### Club Form

One reusable form supports Create and Edit:

- Name is required, trimmed, 3-80 characters.
- Description is required, trimmed, 20-1000 characters.
- Optional JPG, JPEG, PNG, or WebP logo up to 5 MB.
- Existing logo is previewed during Edit.
- Submit is disabled during upload/write to prevent duplicate actions.
- Field errors appear next to their inputs; service errors appear without losing form state.

### Notification and Admin Scaffold

Routes and screens compile and enforce their role requirements but clearly identify deferred content. They do not claim Notification inbox, FCM, Dashboard statistics, or moderation are complete.

## Error Handling

Repository and service failures are mapped to `AppException` messages suitable for the existing UI pattern. Expected cases include invalid input, missing Club, inactive Club, duplicate membership, unauthorized ownership, Cloudinary rejection, network failure, and Firestore permission failure.

An upload failure stops the Firestore write. If upload succeeds and the following Firestore write fails, the new Cloudinary asset may remain orphaned and the user receives a retryable error. No secret-backed delete request is attempted from Flutter.

## Testing

Tests use provider overrides and fakes instead of real Firebase or Cloudinary calls.

Coverage includes:

- Club, Membership, and Notification serialization.
- Club form validation.
- Student create/edit/cancel rejection.
- Organizer ownership enforcement.
- Admin override.
- Successful list/detail rendering.
- Loading, empty, error, and retry states.
- Join duplicate prevention and rejoin after leaving.
- Leave behavior and non-negative counts.
- Create/Edit double-submit prevention.
- Optional and replacement logo upload behavior through a fake media service.
- Cancel confirmation and soft-delete behavior.
- Route guards for student, organizer, and admin actors.

Verification requires formatting, targeted tests, full `flutter analyze`, and the practical subset of the repository's full test suite. Existing unrelated failures, if any, must be reported separately rather than attributed to this feature.

## Out of Scope

- Notification inbox UI and mark-read behavior.
- FCM token registration and push delivery.
- SQLite notification cache.
- Admin dashboard statistics and moderation actions.
- Trusted Cloudinary deletion or signed uploads.
- Club member administration beyond join/leave.
- Club event aggregation.
