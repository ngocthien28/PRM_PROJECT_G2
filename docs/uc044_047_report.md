# Báo cáo UC-044 → UC-047

Ngày thực hiện: 28/10/2026. Theo xác nhận của người dùng, xử lý lần lượt cả bốn UC. Working tree ban đầu sạch. Giai đoạn triển khai chưa commit/push; sau đó người dùng yêu cầu tách và push bốn commit theo UC. Không deploy, không ghi/xóa dữ liệu Firebase production. Không sửa Firestore Rules hoặc indexes.

## Trạng thái

| UC | Status | Review |
|---|---|---|
| UC-044 Local Draft | DONE | READY FOR REVIEW — SQLite thật, migration, autosave/restore/discard/cleanup đã kiểm thử |
| UC-045 Forms & CRUD tests | DONE | READY FOR REVIEW — targeted tests và toàn bộ regression PASS |
| UC-046 Feed & check-in summary | DONE | READY FOR REVIEW — Dart repository/provider flow và Emulator Rules PASS |
| UC-047 Seed & demo | PARTIAL | Backend automated PASS; manual UI demo NOT VERIFIED |

## Changed files và lý do

Đường dẫn tính từ repository root; số dòng chỉ điểm bắt đầu phần liên quan.

| File / dòng | Thay đổi |
|---|---|
| `lib/local/db_migrations.dart:7` | Schema version 4; tạo bảng event_drafts trên create và upgrade, không reset bảng khác |
| `lib/local/dao/event_draft_dao.dart:4` | SQLite transaction upsert, get, has, delete theo organizer UID |
| `lib/features/organizer_events/data/models/event_draft.dart:5` | Model raw form + JSON serialization; timestamp UTC; đọc payload lỗi có kiểm tra |
| `lib/features/organizer_events/data/event_draft_repository.dart:8` | Resolve active authenticated actor, khóa UID theo phiên, map lỗi storage, kiểm tra account trước/sau async |
| `lib/features/organizer_events/presentation/viewmodels/event_draft_provider.dart:8` | Kết nối AppDatabase chung với draft repository |
| `lib/features/organizer_events/presentation/viewmodels/event_draft_controller.dart:8` | Debounce 750 ms, serialize writes, revision guard, retry, flush/clear |
| `lib/features/organizer_events/presentation/viewmodels/event_form_view_model.dart:152` | Form VM sở hữu draft controller và lifecycle dispose |
| `lib/features/organizer_events/presentation/screens/event_form_screen.dart:77` | Restore raw fields, lifecycle flush, Save/Discard UI, confirmation, cảnh báo chọn lại poster, cleanup sau success |
| `lib/features/organizer_events/presentation/screens/organizer_create_event_screen.dart:18` | Scope form theo actor UID; chỉ Create bật draft; Edit giữ luồng riêng |
| `lib/features/events/data/event_repository_impl.dart:358` | Stable request ID phục hồi cùng document sau restart; owner-filtered lookup, không ghi đè counters của event đã tồn tại |
| `lib/features/registration/presentation/viewmodels/registration_view_model.dart:94` | Invalidate event detail và participant summary sau Join/Cancel thành công |
| `lib/features/checkin/presentation/viewmodels/checkin_view_model.dart:166` | Invalidate summary/dashboard/details sau check-in thành công |
| `lib/core/services/firebase_providers.dart:26` | Emulator project/bucket khớp seed; hỗ trợ host Android; chặn project không có prefix demo- trong chế độ emulator |
| `lib/features/organizer_events/presentation/viewmodels/event_poster_view_model.dart:14` | Chế độ emulator chọn HTTP có xác thực trên Windows, Firebase SDK trên Android/Web; giữ service hiện tại ngoài emulator |
| `test/events/event_fakes.dart:42` | FakeEvents đúng shared contract: controlled async/failure, mutation counters riêng, clock, validation và protected fields |
| `test/organizer/organizer_create_event_route_test.dart:50` | Override draft repository; route tests không chạm SQLite thật trong fake widget clock |
| `test/organizer/draft_fakes.dart:5` | Repository double chỉ dành cho widget tests; durability kiểm tra riêng với SQLite |
| `test/organizer/event_draft_uc044_test.dart:1` | SQLite persistence, migration, scoping, corruption, debounce, retry, queue ordering và stale-account cleanup |
| `test/organizer/event_draft_widget_uc044_test.dart:1` | Restore, validation/failure retention, success cleanup, confirmation, navigation và poster reselection |
| `test/organizer/event_crud_uc045_test.dart:1` | Shared fake CRUD, ownership/admin, counters/poster, async failure/retry/double submit |
| `test/organizer/event_flow_uc046_test.dart:1` | Production Dart repositories + summary provider trên fake Firestore; recovery sau repository recreation |
| `test/organizer/demo_fixture_uc047_test.dart:1` | Fixture PNG vượt qua production poster validation |
| `notification-server/test/helpers/event-flow.mjs:1` | Helper emulator/transaction shapes dùng lại cho hai suite mới |
| `notification-server/test/event-flow.integration.js:1` | Real Rules: feed/edit/join/check-in/summary/cancel, unauthorized writes, last-slot concurrency, offline server reads |
| `notification-server/test/organizer-demo.integration.js:1` | Auth login thật cho 5 accounts; seed hai lần; upload/download poster; end-to-end backend demo |
| `notification-server/package.json:19` | Commands test:flow, test:demo, test:organizer |
| `firebase/seed/seed.mjs:1` | Reuse seed infrastructure; loopback/demo-project guard, poster upload thật, giữ QR token khi reseed |
| `firebase/seed/seed_data.mjs:349` | UUID token theo cơ chế hiện có, thay chuỗi placeholder |
| `firebase/fixtures/organizer-poster.png` | PNG 512×512 tái sử dụng icon trong repo cho chọn ảnh/upload demo |
| `docs/organizer_demo.md:1` | Prerequisites, commands, accounts, kịch bản 9 bước, expected results, troubleshooting |

## UC-044 — SQLite schema và flow

Database chung `campushub.db`, version 3 → 4. Bảng mới:

```sql
CREATE TABLE event_drafts (
  organizer_id TEXT PRIMARY KEY,
  id TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

Một Create draft cho mỗi organizer. `id` là stable create request ID, được giữ khi restore. `payload` chứa title, description, category, locationName, capacity dạng chuỗi nguyên gốc, startAt/endAt ISO UTC và posterSelected boolean. `created_at`/`updated_at` là UTC epoch milliseconds. Không lưu auth secret/token, registration counters hoặc ảnh lớn trong SQLite.

Screen → EventFormViewModel → EventDraftController → EventDraftRepository → DAO → SQLite chung. Thay đổi form chạy debounce 750 ms. Save Draft và lifecycle flush dùng cùng hàng đợi; lỗi giữ snapshot để retry. Revision guard bỏ kết quả restore đến muộn và ngăn lỗi ghi cũ làm ghi đè snapshot mới. Scope của form được reset khi actor UID đổi; repository phiên cũ không thể đọc/xóa draft UID mới.

Draft lưu được cả title trống, capacity `not an integer` và ngày kết thúc trước ngày bắt đầu. Restore không gọi submit. Draft vẫn tồn tại sau khi đóng/mở kết nối SQLite. Migration test giữ nguyên cached data từ version 3.

Create success chỉ cleanup sau khi callback bắt buộc (bao gồm poster upload/attach) thành công. Validation/network/upload/permission failure giữ draft. Discard có confirmation và đợi pending writes trước delete. Nếu cleanup local lỗi sau remote success, UI báo riêng, không cho submit lại trong phiên đã thành công. Stable document identity phục hồi event đã tạo khi mở lại draft, giữ counters và tránh tạo document thứ hai trong flow retry đã kiểm thử.

Poster là hỗ trợ tối thiểu: không lưu picker temp path/bytes, không upload khi autosave; restore có cảnh báo và yêu cầu chọn lại ảnh trước submit. Đây không phải chức năng khôi phục nội dung ảnh. SQLite Web chưa được project hỗ trợ; lỗi persistence hiển thị rõ, không fallback RAM giả.

## UC-045 — Test matrix

| Nhóm | Bằng chứng |
|---|---|
| Validation boundaries/errors/time/edit context | Tests hiện có event_form_input, event_form_validation_uc041, poster_validation; clock cố định cho tests mới |
| Create/Edit rendering, inline errors, loading, success/failure retention, small viewport | Tests event_form, edit_event_screen, event_form_submission, poster_widget và route |
| ViewModel loading/error/retry/dispose/double submit | event_form_view_model và event_crud_uc045 |
| Shared-contract fake CRUD | FakeEvents implements EventRepository; event_crud_uc045 |
| Ownership/admin/protected fields/soft cancel | Unit/repository/widget tests sẵn có + event_crud_uc045 + Emulator ownership/cancel |

Fake legacy `FakeOrganizerEventRepository` vẫn chỉ phục vụ tests cũ; UC-045 mới dùng `FakeEvents` với shared model/contract. Không dùng legacy fake để khẳng định shared repository hoặc Firestore Rules đúng. Không thu thập coverage; không tuyên bố tỷ lệ coverage.

## UC-046 — Integration matrix

| Luồng | Dart production repositories/providers | Firebase Emulator + Rules |
|---|---|---|
| Create → published upcoming Feed | PASS | PASS |
| Edit → refreshed Feed/Detail | PASS; giữ counters | PASS; title/location/category đúng |
| Join → Summary | PASS; đúng user/event/count | PASS; duplicate bị chặn |
| Check-in → Summary | PASS; status/rate/not-yet đúng | PASS; repeat không tăng count |
| Last-slot/concurrent edit | Repository/rules tests liên quan | PASS; đúng một student được nhận slot cuối |
| Network failure | Tests error mapping/repository hiện có | PASS; server-only read khi offline không giả success |
| Owner / Other Organizer / Student | Repository checks + provider guards | PASS; protected fields, summary ownership và hard delete |

Không xây lại scanner hoặc transactions của Member 4. Shared Event/Registration status mappings giữ nguyên. Summary dùng counter đã commit; event edits không ghi đè counters. Explicit refresh và provider invalidation dùng lại cơ chế hiện có. Emulator không chứng minh composite indexes production đã build; không deploy indexes trong lượt này.

## UC-047 — Seed và demo checklist

5 Auth accounts/profile cùng UID/role; 10 events, 9 registrations, 2 clubs, 3 notifications và một poster Storage thật khi bật Storage Emulator. Upcoming dates tương đối; fixture có published, full, cancelled, draft, past và checked-in. Reseed hai lần không duplicate fixture; token đang tồn tại được giữ. Suite demo so counter với actual registration documents, kiểm tra capacity invariants và tải bytes thật từ poster URL.

| Bước | Automated backend | Manual Flutter UI |
|---|---|---|
| Login / managed owner list | PASS | NOT VERIFIED |
| Create event + poster upload/download | PASS | NOT VERIFIED — Image Picker chưa thao tác bằng tay |
| Edit giữ poster/counters | PASS | NOT VERIFIED |
| Student Feed/Detail đọc thông tin mới | PASS | NOT VERIFIED |
| Registration / duplicate protection | PASS | NOT VERIFIED |
| Check-in / duplicate protection | PASS | NOT VERIFIED — camera/scanner chưa thao tác bằng tay |
| Participant Summary / rate | PASS | NOT VERIFIED |
| Soft cancel / chặn Join / giữ history | PASS | NOT VERIFIED |
| Unauthorized actions | PASS | NOT VERIFIED |

Chưa đánh dấu UC-047 DONE vì chưa có bằng chứng manual demo Flutter. [Runbook](organizer_demo.md) đã sẵn sàng để thực hiện. Seed reset fixture có chủ đích: chạy trước demo, không chạy giữa các thao tác trên fixture đang dùng.

## Test execution

| Command | Kết quả |
|---|---|
| `flutter analyze --no-pub` | PASS: No issues found |
| `flutter test --no-pub` | PASS sau bản sửa Windows: 571 passed, 0 failed, 1 skipped (Cloudinary live smoke là opt-in; không chạy upload external) |
| `firebase.cmd emulators:exec --only auth,firestore,storage --project demo-campushub --config firebase.security-test.json "npm.cmd --prefix notification-server run test:organizer"` | PASS: 116 tests, 0 fail, 0 skipped |
| `git diff --check` | PASS |
| Manual Flutter demo | NOT VERIFIED |
| Coverage | NOT RUN |

Log cục bộ (build/ được gitignore): `build/uc044-047-analyze.log`, `build/uc044-047-flutter-test.log`, `build/uc044-047-emulator.log`. Các lần chạy đầu đã phát hiện và sửa test fake counter trùng tên với lớp kế thừa, widget tests mở SQLite thật trong fake clock, và assertion lỗi Join cancelled event. Không sửa business rules/expected behavior hợp lệ để ép PASS.

## Cross-member review và hạn chế

- M1: review project/bucket/host trong emulator initialization; production options giữ nguyên. Mỗi thao tác draft kiểm tra active authenticated actor, scope UID không phải mã hóa file SQLite.
- M2: review invalidation Detail sau Join/Cancel. Feed query/serialization không bị viết lại.
- M4: review invalidation summary/dashboard/detail sau check-in. Transaction/QR policy giữ nguyên; cần xác minh camera/nhập payload trong buổi demo UI.
- Poster fixture là asset kiểm thử, không phải thiết kế poster cuối cùng. Draft chưa lưu nội dung ảnh qua phiên mới; UI yêu cầu chọn lại.
- Chưa chạy manual restart/kill app trên thiết bị, Image Picker, camera hoặc kiểm tra index production. SQLite durability đã kiểm bằng đóng/mở database thật.
- Stable create ID phục vụ retry cùng draft; không tuyên bố hỗ trợ nhiều process/device đồng thời cùng ghi một draft local.

## Commit messages theo yêu cầu người dùng

- `HuyTGCE182405: Local Data - Persist Event Draft Locally #44`
- `HuyTGCE182405: Testing & Integration - Test Event Management Forms and CRUD #45`
- `HuyTGCE182405: Testing & Integration - Integrate Event Feed with Check-in Summary #46`
- `HuyTGCE182405: Testing & Integration - Prepare Event Seed Data and Organizer Demo #47`

## Bản sửa sau kiểm thử Flutter Windows trực tiếp

Log người dùng cung cấp xác nhận hai lỗi mà suite backend trước đó chưa bao phủ:

1. `_EventCreateAttempt` dùng owner filter + exact documentId equality cho ID chưa tồn tại. Emulator từ chối bằng permission-denied. Đã sửa thành owner filter + documentId >= request ID, orderBy documentId, limit 1; chỉ coi là recovered nếu ID kết quả trùng chính xác. Truy vấn luôn giới hạn một document; giữ Rules hiện có.
2. firebase_storage 13.6.0 trên Windows bỏ qua `useStorageEmulator` và in cảnh báo. Đã thêm `lib/features/organizer_events/data/emulator_event_poster_service.dart`: HTTP media upload/delete tới loopback 9199, bucket demo-, dùng ID token người đăng nhập. Android/Web giữ Firebase SDK; service ngoài emulator giữ nguyên. Không dùng credential admin để upload.

Regression: `test/organizer/emulator_event_poster_service_test.dart` kiểm tra headers/body/URL, error, signed-out và giới hạn endpoint. `notification-server/test/create-recovery.integration.js` kiểm tra query thực với Rules trong project test riêng. `notification-server/test/windows-storage.integration.js` kiểm tra HTTP upload/download/delete thực, từ chối non-owner, chỉ tạo/xóa fixture ID ngẫu nhiên. Command `test:windows-create`: PASS 5/5 trên emulator đang chạy, giữ nguyên dữ liệu demo.

Kết quả 116 tests emulator phía trên là lần chạy trước bản sửa này; regression mới chạy riêng để tránh suite tổng reset buổi demo đang diễn ra. Manual Image Picker/scanner và toàn bộ demo UI vẫn cần xác minh lại, UC-047 vẫn PARTIAL.

Kiểm chứng bản sửa: Flutter targeted 47/47 PASS; full Flutter suite 571 PASS, 1 skipped, 0 fail; analyzer No issues found; git diff --check PASS. Log mới: `build/windows-create-recovery-test.log`, `build/windows-create-recovery-full-test.log`, `build/windows-create-recovery-analyze.log`.
