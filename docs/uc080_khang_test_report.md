# UC-080 — Club, Notification, and Admin Module Verification

Owner: KhangLG-CE180174

## Verification command

```powershell
flutter test test/clubs test/notifications test/admin test/navigation
```

Result on Windows: **38 tests passed**.

## Covered behavior

- Club create, update, deactivate, join, leave, permissions, model parsing,
  validation, and provider state.
- Notification Firestore inbox, mark-as-read, unread badge, local SQLite cache,
  offline-first emission, deep links, and loading/error/empty states.
- Admin dashboard permissions and navigation.
- Moderation queue ordering, responsive cards, filters, review dialog, duplicate
  decision protection, and persisted audit fields.
- Student/admin navigation history and role-appropriate destinations.

## Desktop layout sizes exercised

- 1366 × 768: full Windows sidebar and moderation workflow.
- 700 × 720: compact layout with bottom navigation and stacked case actions.

No RenderFlex overflow or analyzer issue remains in these flows.
