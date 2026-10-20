# Club operation performance

- Membership opens its document snapshot listener directly, without a preceding
  one-shot read. The listener remains keyed by club ID and authenticated user ID.
- Join/Leave keeps the existing detail and membership listeners alive. It no
  longer invalidates both providers after the transaction commits.
- The form reuses selected logo bytes instead of reading the image file again
  at submission. ImagePicker requests a maximum 1024x1024 image at quality 80
  on platforms that support resizing (including Android). Desktop picker
  implementations may ignore these resize parameters; the 5 MB validation remains.
- Membership, member count and notification still commit atomically. No success
  is reported before the server operation completes.

## Measure on the actual connection

Run in debug mode and perform Create Club, Join and Leave. Filter terminal output
for `[CampusHub perf]`:

- `club.logo.upload`: Cloudinary upload duration for a new club logo.
- `club.create.commit`: Firestore batch write duration.
- `club.join.transaction` / `club.leave.transaction`: transaction duration,
  including any SDK retry time. A duration is logged even when the operation fails.

These logs contain no email, user ID, club ID or credentials. Unit-test timings
use an in-memory Firestore fake and must not be treated as production latency.
Network latency and database region are not changed by these optimizations.
