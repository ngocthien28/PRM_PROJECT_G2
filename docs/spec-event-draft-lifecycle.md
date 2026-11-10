# Spec: Event Draft / Published selector

Status: Scope corrected by the user, 2026-11-09. Implement a status selector;
both draft and published events require complete form input.

## Objective and acceptance criteria

- Add a Status selector with Draft and Published to create/edit forms.
- Create defaults to Published; editing preselects the saved status. Submit
  saves the selected status on the same event ID.
- Both statuses require title, description, category, location, ordered dates,
  positive capacity and existing poster validation. No title-only drafts.
- New publication, including draft-to-published, requires a future start.
  Drafts may retain past starts, but their other validations remain unchanged.
- Allow draft/published transitions only with zero registered/check-in
  participants. Do not reopen finished/cancelled events through this selector.
- Enforce permissions and transitions in repository transactions and Rules.
  Drafts remain private to owner/admin and inaccessible for registration.
- Preserve local Save Draft recovery separately, including selected status.
- Keep stable create request IDs, stale-edit and poster retry protection.
  Retry confirmation compares status; failed poster upload must not publish
  an existing draft.

## Stack, structure and style

Use current Flutter/Dart, Riverpod, Firestore, SQLite and Node lockfiles.
Input and UI: lib/features/organizer_events. Persistence: lib/features/events.
Rules: firestore.rules. Tests: test/organizer, test/events and
notification-server/test. Keep immutable inputs, named arguments, EventStatus,
AppException and existing transaction patterns. Optional status intent defaults
legacy creates to published and preserves status for legacy update callers.

## Verification commands

Use the VS Code Flutter SDK at C:/Users/tagia/flutter/bin/flutter.bat:

```powershell
& 'C:/Users/tagia/flutter/bin/flutter.bat' test --no-pub test/organizer test/events
& 'C:/Users/tagia/flutter/bin/flutter.bat' test --no-pub
& 'C:/Users/tagia/flutter/bin/flutter.bat' analyze --no-pub
& 'C:/Users/tagia/flutter/bin/flutter.bat' build windows --debug --no-pub
```

Write failing tests before behavior changes. Cover validation in both modes,
create/edit widgets, actual persistence, retries and status transitions. Run
security tests with isolated demo emulators; never clear a running demo dataset.
Check non-owner/student denial, protected fields, registration and stale edits.
Record pre-existing failures separately instead of weakening tests.

Manual flow: complete the form, select Draft, create, reopen from Draft, edit
while retaining Draft, then select Published and save. Confirm the same ID moves
to Published and becomes student-visible.

## Boundaries

No new collection/dependency, schema relaxation, notifications or production
deployment. Git commit/push was authorized in the user's follow-up request.
Preserve unrelated local edits and existing test checks.
Production Firestore Rules will need deployment before using this on the live
backend. Preserve local form recovery and existing cancellation behavior.

## Official references

- https://api.flutter.dev/flutter/material/DropdownButtonFormField/DropdownButtonFormField.html
- https://firebase.google.com/docs/firestore/manage-data/transactions
- https://firebase.google.com/docs/firestore/security/rules-fields
- https://firebase.google.com/docs/firestore/security/test-rules-emulator
