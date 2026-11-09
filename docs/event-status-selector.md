# Event status selection

The create/edit event form has a **Status** dropdown below Category:

- **Draft** saves a complete event to Firestore, visible to its owner/admin.
- **Published** makes the event available in student discovery.

Both choices require all existing fields and validation: title, description,
category, location, correctly ordered dates and positive capacity. Publishing
a new event or an existing draft requires a future start time.

New forms default to Published. Editing starts with the saved status and
retains the event ID. Status is locked when an event has registered/check-in
participants; title/location and other permitted details can still be edited.
Finished/cancelled events cannot be reopened through this dropdown.

**Save Draft** near the top is the existing device-local form recovery action.
To create an event in the server Draft list, select **Status: Draft** and press
**Create Event**. On edit, select the desired status and press **Save Changes**.
The selected status is also retained when recovering a local form draft.

## Manual verification

1. Sign in as an active organizer and open Create Event.
2. Complete every required field and select Draft, then Create Event.
3. In My Managed Events, select Draft and open the created event for editing.
4. Confirm Status is Draft; change the title and Save Changes.
5. Reopen it, select Published with a future start, and Save Changes.
6. Confirm it moves to Published, retains its ID and appears to students.
7. Attempt an incomplete form in Draft; validation must reject submission.
8. Register a student, reopen the event as organizer, and confirm status is
   locked while permitted detail editing remains available.

## Backend requirements

The updated `firestore.rules` is required as well as the Flutter code. Restart
local emulators to load the rules for demo testing. For the live Firebase
backend, the rules must be reviewed/deployed to the configured project before
draft creation or publication can work there. This change does not deploy
rules or push commits automatically.

The rules enforce complete input, owner/admin access, protected fields,
allowed transitions, participant counts and future publication time. These
checks cannot be bypassed by calling Firestore directly.
