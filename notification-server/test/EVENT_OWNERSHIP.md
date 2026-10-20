# UC-042 security tests

Run from the repository root (Node >=22, Java 21+, Firebase CLI):

```powershell
npm.cmd --prefix notification-server ci --ignore-scripts --no-audit --no-fund
firebase.cmd emulators:exec --only firestore --project demo-campushub --config firebase.security-test.json "npm.cmd --prefix notification-server run test:ownership"
```

The suite requires `FIRESTORE_EMULATOR_HOST=127.0.0.1:8087` set by
`emulators:exec`. It uses only `demo-campushub`, synthetic identities and local
fixtures. It never deploys or seeds the configured production project. The
notification rules/worker tests run sequentially as regression checks.

## Authorization contract

- Active organizers/admins create events owned by their authenticated UID.
- Owners/admins edit/cancel; ordinary clients cannot transfer ownership, hard
  delete, replace posters or directly rewrite counters.
- Roles come from `users/{auth.uid}`. Self-signup can create only an active
  student profile. Ordinary clients cannot modify roles/status.
- Students read their own registrations; organizers read only registrations
  whose trusted event document belongs to them; admins read all.
- Owner participant queries must constrain `eventId`. Rules do not filter
  an unrestricted collection query.

## Reciprocal transaction invariants

Each registration write validates the event before/after, and each counter
write validates the registration before/after using `getAfter()`:

| Operation | Registration transition | Event write |
| --- | --- | --- |
| Join | Missing/cancelled -> registered at server time; canonical `{eventId}_{uid}` | `registeredCount + 1`, `updatedAt` |
| Cancel registration | Registered, not checked in -> cancelled at server time; >=2h before start | `registeredCount - 1`, `updatedAt` |
| Check-in | Registered -> checkedIn at server time, owner/admin only | `checkedInCount + 1`, `updatedAt`, `lastCheckInRegistrationId` |

The optional `lastCheckInRegistrationId` identifies the one registration that
must transition in the same atomic operation. Without it, the existing
counter-only payload cannot prove which participant was checked in. The marker
is not a log or another source of truth. It cannot change through normal event
editing; EventModel readers tolerate it and partial updates preserve it.
One marker cannot authorize multiple registration check-ins in a batch.

RegistrationRepository keeps its public interface. The minimal Member 4 changes
are: no fabricated success/offline ticket on rejected join, no cache side effect
inside a retryable transaction, no rejoin of checked-in registrations, server
check-in timestamp, reciprocal marker, and owner/auth checks. The existing
action ViewModel caches tickets after a confirmed join result.

Production providers inject a fresh Firebase Auth/profile resolver into Event
and Registration repositories. Optional resolver injection preserves isolated
fake-DB tests; it does not replace server-side Rules. The backend still checks
the actual request identity even if client code bypasses a provider or forges
an AppUser argument.

## Review boundaries

M1: review the fresh actor resolver and fail-closed role/disabled handling.
M4: review check-in marker/server timestamp and join error/cache changes. Writes
from older check-in clients without the marker will be rejected by these rules;
deploy compatible clients/rules together through the team's normal release.

The tests execute real Firestore Rules with the JS SDK and transaction shapes
matching Dart; Dart repository regression tests use fake Firestore. A manual
device run and production deployment are separate tasks and are not performed
by this test command.
