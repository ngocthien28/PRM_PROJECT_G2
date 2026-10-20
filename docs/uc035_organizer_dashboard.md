# UC-035 — View Organizer Dashboard, Iteration 2

Ngày kiểm chứng: 21/10/2026. HEAD đối chiếu: `bd6bd73`.

## A. Implementation Summary

- Trước: PARTIAL, khoảng 45% theo yêu cầu đầu vào.
- Sau: **DONE trong phạm vi UC-035 — READY FOR REVIEW**.
- Hoàn thiện sáu KPI thực, phân loại status/thời gian, preview giới hạn, điều hướng, loading/empty/error/retry/refresh và responsive.
- Tách nguồn tổng hợp dashboard khỏi danh sách Managed Events giới hạn 100 bản ghi. Sự kiện cancelled vẫn đóng góp vào Total Events và counter hợp lệ.
- Dashboard không ghi Firestore, sửa registration/check-in transactions hoặc sửa Rules/Indexes/seed.
- Không còn hạng mục triển khai UC-035 bắt buộc đang thiếu. Có ba lỗi test ngoài phạm vi, đã tái hiện trên HEAD chưa sửa; xem F.
- Chưa commit/push; không triển khai lên Firebase production. Kiểm chứng Firebase dùng project Emulator riêng.

## B. Changed Files

Các số dòng dưới đây là vị trí bắt đầu nội dung liên quan trong phiên bản cuối.

| File / dòng | Thay đổi | Lý do |
|---|---|---|
| `lib/features/organizer_events/data/models/organizer_dashboard_summary.dart:8` | Summary bất biến; accumulator tại dòng 60 | Sáu KPI, UTC, chống đếm trùng, preview 5/3, phát hiện counter sai |
| `lib/features/events/data/event_repository.dart:22` | Thêm `getOrganizerDashboard` chỉ đọc | Giữ chữ ký create/update/cancel và nguồn danh sách cũ |
| `lib/features/events/data/event_repository_impl.dart:171` | Đọc server, lọc owner, phân trang 100 | Tổng hợp toàn bộ dữ liệu thay vì chỉ trang đầu |
| `lib/features/organizer_events/presentation/viewmodels/organizer_dashboard_view_model.dart:8` | Clock có thể inject, provider tại dòng 12 | Auth, account changes, lỗi và request lifecycle |
| `lib/features/organizer_events/presentation/viewmodels/organizer_events_view_model.dart:86` | Invalidate dashboard sau mutation thành công | Create/update/cancel cập nhật KPI |
| `lib/features/organizer_events/presentation/screens/organizer_dashboard_screen.dart:20` | Header, CTA, KPI, trạng thái, danh sách và actions | Hoàn thiện Dashboard; KPI widget dòng 310, event card dòng 422 |
| `lib/shared/widgets/campus_scaffold.dart:30` | Tùy chọn `sidebarWidth`, mặc định 232 như cũ | Dashboard tăng chiều rộng sidebar khi chữ lớn; các màn hình khác giữ mặc định |
| `test/events/event_fakes.dart:53` | Fake hỗ trợ API đọc summary | Giữ các test cũ tương thích với interface mở rộng |
| `test/organizer/organizer_dashboard_summary_test.dart:18` | 14 unit tests | Công thức KPI, status, thời gian, owner, dữ liệu trùng/sai |
| `test/organizer/organizer_dashboard_repository_test.dart:27` | 5 repository tests | 205 events, cursor trùng timestamp, quyền, admin, refresh, không ghi dữ liệu |
| `test/organizer/organizer_dashboard_provider_test.dart:54` | 8 provider tests | Loading/error/retry, refresh, mutations, account switch, phản hồi cũ đến muộn |
| `test/organizer/organizer_dashboard_screen_test.dart:79` | 11 widget tests | KPI, CTA/actions/routes, refresh, account/logout, responsive/chữ lớn |
| `test/organizer/organizer_screen_structure_test.dart:70` | Cập nhật hai assertion tên tiêu đề | Đồng bộ tên Organizer Dashboard; giữ kiểm thử routing/cấu trúc |
| `test/organizer/organizer_create_event_route_test.dart:123` | Scroll card vào viewport trước khi tap | KPI mới làm card nằm thấp hơn; vẫn kiểm tra detail và Back thật |
| `notification-server/test/organizer-dashboard.integration.js:1` | 7 tests với Firestore Emulator | Query phân trang, Rules, ownership, admin và counter refresh |
| `notification-server/package.json:16` | Script `test:dashboard` | Chạy riêng integration của UC-035 |
| `docs/uc035_organizer_dashboard.md:1` | Báo cáo này | Công thức, bằng chứng kiểm thử, dependency và giới hạn |

## C. Dashboard KPI Matrix

Nguồn chung: các Event hợp lệ có `organizerId == authenticated UID`, lấy qua Repository, không lọc status ở query.

| KPI | Nguồn dữ liệu | Công thức | Kết quả |
|---|---|---|---|
| Total Events | Tất cả event của owner | Đếm ID duy nhất, bao gồm draft/published/cancelled/finished | PASS |
| Upcoming Events | Status + startAt/endAt | `published && startAt > asOf`; event hợp lệ luôn có `endAt > startAt` | PASS |
| Published Events | `EventModel.status` | Đếm status published, kể cả đang diễn ra/đã qua | PASS |
| Cancelled Events | `EventModel.status` | Đếm status cancelled trong toàn bộ tập owner | PASS |
| Total Registrations | `EventModel.registeredCount` | Tổng counter trên tất cả event owner | PASS |
| Total Checked-in | `EventModel.checkedInCount` | Tổng counter trên tất cả event owner | PASS |

Tổng registrations/check-ins là số **lượt theo event**, không phải số sinh viên duy nhất. Counter do RegistrationRepository duy trì: đăng ký tăng registeredCount, hủy đăng ký giảm registeredCount, check-in tăng checkedInCount. Sự kiện bị hủy không đồng nghĩa mọi registration đã bị hủy; dashboard giữ counter thực của event đó.

`phaseOf` tại model dòng 44 ưu tiên cancelled, draft, finished; published có `endAt <= asOf` là past, `startAt > asOf` là upcoming, còn lại ongoing. Tại đúng startAt: ongoing; tại đúng endAt: past. Clock và Firestore timestamp dùng UTC; ngày giờ UI dùng formatter hiện có theo locale.

Attendance Rate là tùy chọn và không được thêm. Không có phép chia khi registrations bằng 0. Counter âm, registrations vượt capacity hoặc checkedIn vượt registrations tạo lỗi rõ ràng, không clamp hoặc tự sửa dữ liệu.

## D. Dashboard Flow Verification

Authenticated Organizer → `currentUserProvider` → `organizerDashboardProvider` → `EventRepository.getOrganizerDashboard` → Firestore owner query → accumulator → `OrganizerDashboardScreen`.

- **Ownership:** provider dùng profile hiện tại, không nhận organizerId từ route. Repository xác minh actor bằng resolver hiện có và kiểm tra role/status. Query lọc owner ngay tại server; model tiếp tục từ chối dữ liệu sai owner. Admin dùng dashboard cá nhân; quyền quản lý toàn hệ thống hiện có vẫn ở Managed Events/Admin.
- **Phân trang:** `organizerId == UID`, `startAt DESC`, document ID DESC, cursor `startAfterDocument`, mỗi request tối đa 100 documents. Đọc đến trang cuối; xử lý trùng timestamp ổn định và chống cộng trùng ID. Managed Events vẫn dùng provider/API hiện có với limit 100; dashboard không lấy KPI từ danh sách đó.
- **Hiệu năng:** O(N) event reads mỗi lần tải/refresh để tổng hợp đủ owner, không đọc registrations và không N+1 queries. Chỉ giữ tối đa 5 upcoming gần nhất, 3 recent/ongoing theo startAt và tập ID đã gặp. Không polling. Widget rebuild không gây query mới; dữ liệu phụ thuộc session/repository/clock và explicit invalidation.
- **Tính nhất quán:** đọc server, không dùng cache để giả làm thành công khi offline. Một lần refresh nhiều trang không phải snapshot giao dịch duy nhất; dữ liệu sửa đồng thời trong lúc đọc có thể cần refresh lại. Đây là tổng quan tại lần đọc, không phải live analytics.
- **Trạng thái:** loading không hiển thị số 0 giả; dataset rỗng thành zero KPIs + empty; có history nhưng không upcoming có thông báo riêng. Repository/Firebase/auth lỗi đi vào error + Retry, không thành empty. Request/auth timeout có giới hạn; provider không tự retry vô hạn.
- **Session:** `selectAsync` quan sát profile emissions; account B thay dependency của request A, kết quả A đến muộn không ghi đè B. Loading/reload không giữ KPI cũ trên giao diện. Logout loại bỏ metrics.
- **Refresh:** nút Refresh, pull-to-refresh và Retry dùng chung invalidation; chặn refresh trùng khi đang tải. Create/update/cancel thành công invalidate dashboard qua `organizerEventActionsProvider`. Quay lại từ event detail cũng refresh. Counter registration/check-in mới hiển thị sau explicit refresh hoặc lần mở dashboard tiếp theo.
- **Navigation:** dùng callback/router hiện có cho Create Event, My Managed Events, Edit và Participant Summary. Card/title và View details mở managed detail, Back trả về dashboard. Quyền edit/cancel tiếp tục theo policy hiện có, cancelled không có hai actions đó.
- **Responsive:** KPI tự chuyển 1/2/3 cột theo chiều rộng nội dung; số lớn co vừa card, label/metadata/CTA wrap. Phone dùng bottom navigation cho Clubs/Notifications nên không lặp hai icons trong header. Sidebar dashboard điều chỉnh theo text scale để tránh tràn trên tablet chữ lớn.

## E. Acceptance Checklist

| Hạng mục | Trạng thái | Bằng chứng |
|---|---|---|
| UI Layout | PASS | Header, 6 KPIs, preview, CTA và action menu |
| Real KPIs | PASS | Repository server read + Emulator, không có fake production |
| Total Events | PASS | 205 events trong Dart repository; 209 events trong Emulator |
| Upcoming/Published/Cancelled | PASS | Status/time boundary tests; cancelled ở Total nhưng không Upcoming |
| Registration count | PASS | Tổng trusted event counters, gồm refresh |
| Check-in count | PASS | Counter tests, dữ liệu sai báo lỗi |
| Ownership | PASS | A/B tách biệt, forged/disabled/student/guest bị chặn |
| Upcoming list | PASS | Sắp tăng theo startAt/ID, tối đa 5, không cancelled |
| Navigation | PASS | Callback IDs và GoRouter thật; regression Create/Edit/Participants/Back |
| Loading | PASS | Không tạo zero KPIs khi đang đợi |
| Empty | PASS | Phân biệt không có event với không có upcoming |
| Error | PASS | Không biến failure thành empty |
| Retry | PASS | Error → Retry → success |
| Refresh | PASS | Button/pull, create/update/cancel và counter mới |
| Responsive | PASS | 360×800, 430×900, 844×390, 800×1024, 1200×900; text scale 1/2; counter 11 chữ số |
| UC-035 automated tests | PASS | 38/38 tests |
| Firebase verification | PASS, phạm vi Emulator | 7/7 Rules/query integration tests; project demo riêng |
| Toàn bộ Flutter suite | FAIL do baseline ngoài UC-035 | 368 PASS, 3 FAIL; cả 3 tái hiện trên HEAD chưa sửa |
| Firebase production / Windows native E2E | NOT VERIFIED | Không tạo test data production; Emulator JS không kiểm thử native FlutterFire end-to-end |

## F. Test Results

Log nằm trong `build/` (Git ignore), không đưa dữ liệu build vào commit.

| Test / command | Kết quả thực tế | Bằng chứng |
|---|---|---|
| `dart format --output=none --set-exit-if-changed` trên 14 Dart files thay đổi | PASS, 0 files changed | Đã chạy sau lần sửa cuối |
| Bốn file `organizer_dashboard_*_test.dart` | PASS, 38 tests | `build/uc035-targeted-tests.log` |
| Toàn bộ Organizer + Event contracts + route guards + role navigation | PASS, 201 tests | `build/uc035-regression-tests.log` |
| `flutter analyze --no-pub` | PASS, No issues found | `build/uc035-analyze.log` |
| `flutter build windows --debug --no-pub` | PASS, tạo `campushub.exe` | `build/uc035-windows-build.log` |
| `flutter test --reporter expanded` | 368 PASS / 3 FAIL | `build/uc035-full-tests.log` |
| Hai file navigation/Discover trên bản archive HEAD `bd6bd73` | 6 PASS / 3 FAIL, cùng lỗi với working tree | `build/uc035-baseline-tests.log` |
| `npm run test:dashboard`, local Firestore Emulator | PASS, 7 tests | `build/uc035-emulator-tests.log` |
| `git diff --check` | PASS | Không có whitespace error |

Các lệnh test chính đã chạy:

```powershell
flutter test test/organizer/organizer_dashboard_summary_test.dart test/organizer/organizer_dashboard_repository_test.dart test/organizer/organizer_dashboard_provider_test.dart test/organizer/organizer_dashboard_screen_test.dart --reporter expanded

flutter test test/organizer test/events/event_repository_test.dart test/events/event_ownership_test.dart test/events/create_event_retry_test.dart test/events/update_event_test.dart test/auth/route_guards_test.dart test/navigation/role_navigation_test.dart --reporter expanded

flutter analyze --no-pub
flutter test --reporter expanded
git diff --check
```

Chạy lại Emulator integration từ repo root:

```powershell
firebase emulators:start --only firestore --project demo-campushub-uc035
# Terminal khác:
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8087'
Set-Location notification-server
npm run test:dashboard
```

Integration test mirror cùng bộ lọc/order/cursor/limit với Dart, gọi Firestore Emulator thật với Rules hiện tại. Các fixtures chỉ ghi project `demo-campushub-uc035` bằng test context; không sửa seed sản phẩm. Emulator xác minh Rules và query semantics, không xác minh composite index đã deploy trên production hoặc native SDK Windows.

Ba lỗi ngoài phạm vi được đối chiếu trên bản HEAD riêng trong `build/uc035-baseline`, giữ nguyên working tree:

1. `test/navigation/campus_navigation_test.dart:35`, Student Back từ Clubs/Notifications: không tìm thấy nút Back mà test cũ kỳ vọng.
2. Cùng file/dòng, Admin Back: cùng nguyên nhân.
3. `test/events/discovery_screens_test.dart:175`: header trang Discover tràn ngang 37 px trong test responsive có sẵn.

Không sửa ba lỗi này theo yêu cầu chỉ xử lý UC-035. Bộ UC-035 và regression Organizer đều không còn failure.

## G. Cross-UC Dependencies

| Dependency | Đánh giá |
|---|---|
| UC-032 write contract | Giữ nguyên create/update/cancel methods và writable fields; regression tests PASS |
| UC-033 structure / Participant Summary | Tái sử dụng routes/callbacks. Participant summary và dashboard cùng đọc event counters; không xây lại participant screen |
| UC-034 Rules/Indexes | Owner-scoped query được Rules hiện tại cho phép, Emulator PASS. Reuse index `organizerId ASC, startAt DESC`; document-ID DESC cùng hướng mặc định của index. Không thay Rules/Indexes/seed; không deploy production |
| UC-036 Managed Events | Cùng EventRepository; giữ `organizerEventsProvider` và limit 100. Dashboard dùng summary provider riêng, tránh KPI bị cắt trang |
| UC-037 Create Event | Mutation thành công invalidate dashboard, provider test PASS |
| UC-038 Update Event | Invalidate sau save; đổi ngày/location/title được summary đọc lại, regression PASS |
| UC-039 Cancel Event | Chỉ thêm invalidation dashboard trong entry point mutation dùng chung; giữ business flow. Cancelled tăng KPI, không hard delete |
| Member 4 registration/check-in | Chỉ đọc registeredCount/checkedInCount. Refresh lấy counter mới. Không có bằng chứng counter lệch trong fixtures hợp lệ; dữ liệu production không được kiểm tra/sửa. Counter lệch thực tế là dependency cần xử lý ở nguồn transaction/data, dashboard báo lỗi |

## H. Completion Assessment

**UC-035 đã hoàn thành các hạng mục bắt buộc trong phạm vi triển khai và đủ điều kiện READY FOR REVIEW.** Sáu KPI có dữ liệu thực, ownership/phân trang/status/time đúng theo các kiểm thử, đầy đủ states/navigation/refresh và responsive. Không có regression mới được tìm thấy trong lần chạy toàn bộ tests; ba lỗi còn lại có trên HEAD chưa sửa.

Không tuyên bố toàn repository đã xanh hoặc Firebase production/native Windows E2E đã được xác minh. Review có thể dựa vào mã nguồn, 38 UC-035 tests, 201 regression tests và 7 Emulator tests nêu trên.

Commit message đề xuất, **chưa thực hiện commit/push**:

```text
feat(organizer): complete UC-035 dashboard and event KPIs
```
