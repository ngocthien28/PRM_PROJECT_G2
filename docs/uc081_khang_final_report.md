# UC-081 — Notification Deep Links and Final Integration

Owner: KhangLG-CE180174

## Delivered flow

1. A notification is loaded from Firestore and persisted to the account-scoped
   SQLite cache.
2. Selecting an unread notification marks it as read in Firestore and updates
   the local cache.
3. Notifications with a supported type and referenceId expose a contextual
   action:
   - club / club_membership → Club Detail
   - event_* → Event Detail
   - ticket / registration → My Events
   - moderation → Moderation workspace
4. System notifications without a target remain readable without presenting a
   broken navigation action.

## Windows desktop verification

- Use powershell -ExecutionPolicy Bypass -File scripts/run_windows.ps1.
- Sign in with the seeded student account.
- Open **Notifications** from the sidebar.
- Open **Flutter workshop details updated** and choose **View event**.
- Resize the window below and above 1120 px to verify bottom navigation and
  desktop sidebar behavior.
- Disconnect the network after the first inbox load and reopen the app to
  verify cached notifications remain available.

## Automated coverage

- Notification cache serialization, account isolation, and read persistence.
- Firestore refresh with immediate cached inbox emission.
- Notification read state and unread badge behavior.
- Deep-link mapping and navigation to Event Detail.
- Moderation queue repository, resolution audit record, and responsive UI.
