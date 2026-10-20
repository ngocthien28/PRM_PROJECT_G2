# UC-039 — Cancel Event, Iteration 2

Ngày kiểm chứng: 21/10/2026, múi giờ Asia/Saigon. HEAD đầu phiên: `a0f0c8c` (UC-035).

## 1. Status

**Trước: PARTIAL 65% → Sau: DONE trong phạm vi UC-039 — READY FOR REVIEW.**

Working tree ban đầu sạch; đã chạy `git status --short`, `git diff --check` và kiểm tra implementation mới nhất. UC-035 đã có trong HEAD; giữ nguyên phần KPI, aggregation và routing. Theo yêu cầu bổ sung, bố cục thẻ sự kiện được đổi giống Clubs và các thay đổi đã được commit/push. Không deploy Firebase.

Audit cũ không còn hoàn toàn đúng: hai màn hình đã dùng chữ Cancel event và repository đã có soft cancellation bằng transaction. Phần cần hoàn thiện là loading/disable, giữ dialog khi lỗi, chống request trùng, safe retry và bằng chứng kiểm thử đầy đủ.

## 2. Changed Files

Số dòng là vị trí nội dung liên quan trong phiên bản cuối.

| File / dòng | Mục đích |
|---|---|
| `lib/features/organizer_events/presentation/widgets/cancel_event_dialog.dart:10` | Dialog dùng chung; `_submit` dòng 33, error mapping dòng 55, PopScope/loading/actions từ dòng 82 |
| `lib/features/organizer_events/presentation/screens/manage_events_screen.dart:96` | Gọi dialog chung, chỉ hiện success sau xác nhận; nhãn menu Cancel Event dòng 555 |
| `lib/features/organizer_events/presentation/screens/organizer_dashboard_screen.dart:278` | Tái sử dụng cùng luồng dialog; nhãn menu Cancel Event dòng 456; không sửa KPI |
| `lib/features/organizer_events/presentation/viewmodels/organizer_events_view_model.dart:138` | Coalesce cancel theo actor/event; timeout, reset lock và invalidation hiện có |
| `lib/features/events/data/event_repository_impl.dart:319` | Giữ nguyên public signature; chia sẻ attempt đang chạy để retry không mở thêm transaction song song; transaction tại dòng 344 |
| `test/events/cancel_event_test.dart:83` | 19 repository tests: quyền, dữ liệu bảo toàn, lỗi, timeout, request trùng, OCC, trạng thái và idempotency |
| `test/organizer/cancel_event_actions_test.dart:17` | 5 action/provider tests: lock, retry, timeout/auth và invalidation |
| `test/organizer/cancel_event_screen_test.dart:22` | 18 widget tests trên Dashboard và Managed Events |
| `test/organizer/cancel_event_fakes.dart:7` | Fake có điều khiển pending/error cho cancel; chỉ dùng trong tests |
| `test/admin/admin_event_management_test.dart:208` | Cập nhật test Cancel UI theo nhãn/dialog mới; vẫn kiểm tra Keep không hủy, Admin cancel giữ owner/counter |
| `test/organizer/organizer_dashboard_screen_test.dart:156` | Kiểm tra sự kiện cancelled không có nhãn Cancel Event mới |
| `notification-server/test/cancel-event.integration.js:1` | 20 tests với Firestore Emulator và Rules thật, project demo riêng |
| `notification-server/package.json:17` | Thêm script `test:cancel` |
| `docs/uc039_cancel_event.md:1` | Báo cáo và hướng dẫn chạy lại kiểm thử |

## 3. Implemented

### UI và async state

- Cùng một dialog **Cancel Event** cho Dashboard và Managed Events. Giải thích Student không thể đăng ký mới, event và registrations hiện có vẫn được giữ trong lịch sử.
- Keep Event, Escape hoặc đóng dialog trước khi xác nhận không gọi repository.
- Sau khi xác nhận, hiển thị `Cancelling…`, vô hiệu hóa hai nút và chặn Back/Escape/click ngoài trong lúc chờ. Handler kiểm tra busy ngay trước await, nên double tap không gửi request lặp.
- Chỉ đóng dialog với kết quả thành công khi server-backed action hoàn thành; màn hình gọi mới hiện `Event cancelled.`.
- Khi permission-denied, not-found, unavailable/offline/timeout hoặc lỗi bất ngờ: giữ dialog, hiển thị lỗi thân thiện, dừng loading, bật Retry và Back. Không lộ stack trace/native details.
- Sau lỗi chưa xác nhận, nút đóng là **Back**, thay vì ngụ ý Keep Event có thể hoàn tác request đã gửi. Timeout là trạng thái chưa xác nhận; nó không rollback một transaction có thể đang chờ phản hồi. Retry sẽ đối chiếu/truy vấn lại an toàn.
- Cancelled event không có menu Cancel Event. Management history vẫn giữ event; bộ lọc Published có thể ẩn nó theo đúng filter, có thể xem lại bằng All/Cancelled.

### Repository và tính an toàn khi retry

- Giữ `EventRepository.cancelEvent` và contract public hiện có. Xác minh actor/profile thực, role/status, ID hợp lệ và event tồn tại.
- Chỉ active Owner Organizer hoặc Admin được phép hủy. Student, Organizer khác, guest, profile bị khóa và supplied actor giả mạo bị từ chối.
- Transaction đọc event tại thời điểm xử lý, kiểm tra owner và trạng thái mỗi lần Firestore retry. Chỉ update `status: cancelled` và `updatedAt: serverTimestamp`.
- Không gọi delete, không xóa registrations, không thay owner/counters/poster/createdAt hoặc metadata khác.
- Nếu event đã cancelled, transaction không ghi lại status/timestamp. Lost acknowledgement rồi retry không tạo thêm mutation.
- Cancellation đang chạy được chia sẻ theo cặp UID/event ID ở Actions và Repository. Caller timeout không giả định native transaction đã bị hủy; retry cùng instance nối vào attempt còn chờ. Lock được gỡ khi attempt thực sự kết thúc hoặc thất bại.
- Thời gian chờ auth/request có giới hạn 20 giây mỗi bước, có thể inject thời lượng ngắn trong tests. UI không kẹt loading vô hạn. Guard `ref.mounted` tránh invalidation vào provider đã bị dispose.
- Coalescing là trong từng instance, không phải distributed lock. Tính an toàn giữa nhiều client dựa vào transaction/OCC và Firestore Rules; Emulator đã xác minh concurrent cancellation giữ timestamp/counter của commit thắng trước.
- Policy hiện tại không cấm cancel chỉ vì event đã draft/finished/đang diễn ra. Giữ policy đó, không tự thêm giới hạn mới. Draft/finished và Published cancellation được kiểm thử.

### Đồng bộ

Sau server confirmation, tiếp tục invalidate các provider hiện có: Managed Events, UC-035 dashboard, Student event list/home và event detail. Total Events vẫn giữ event, Cancelled tăng, Upcoming loại event đã hủy. Không thay công thức KPI.

Discovery query vẫn chỉ lấy published events. RegistrationRepository và Rules hiện có từ chối đăng ký mới sau cancellation; đăng ký cũ và lượt đã check-in không bị xóa/chỉnh sửa.

## 4. Tests và bằng chứng

| Test / command | Kết quả | Log |
|---|---|---|
| Format 11 Dart files thay đổi | PASS, 0 files cần đổi thêm | `dart format --output=none --set-exit-if-changed` |
| Targeted UC-039: repository + actions + widget | PASS, 42/42 | `build/uc039-targeted-tests.log` |
| Hồi quy Organizer, Admin Cancel UI, Event write contracts, registration/check-in | PASS, 241/241 | `build/uc039-regression-tests.log` |
| Firestore Emulator `npm run test:cancel` | PASS, 20/20 | `build/uc039-emulator-tests.log` |
| `flutter analyze --no-pub` | PASS, No issues found | `build/uc039-analyze.log` |
| `flutter build windows --debug --no-pub` | PASS, tạo campushub.exe | `build/uc039-windows-build.log` |
| `flutter test --reporter expanded` | 410 PASS / 3 FAIL do lỗi baseline ngoài phạm vi | `build/uc039-full-tests.log` |
| `git diff --check` | PASS | Không có whitespace error |

Các log trong `build/` được Git ignore. Không commit build artifacts hoặc dữ liệu test.

Các lệnh đã chạy:

```powershell
flutter test test/events/cancel_event_test.dart test/organizer/cancel_event_actions_test.dart test/organizer/cancel_event_screen_test.dart --reporter expanded

flutter test test/organizer test/admin/admin_event_management_test.dart test/events/event_repository_test.dart test/events/event_ownership_test.dart test/events/update_event_test.dart test/events/create_event_retry_test.dart test/registration/cancel_event_registration_test.dart test/registration/registration_business_rules_test.dart --reporter expanded

flutter analyze --no-pub
flutter test --reporter expanded
flutter build windows --debug --no-pub
git diff --check
```

Chạy lại Emulator tests từ repo root:

```powershell
firebase emulators:start --only firestore --project demo-campushub-uc039
# Ở terminal khác:
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8087'
Set-Location notification-server
npm run test:cancel
```

Test script bắt buộc local emulator `127.0.0.1:8087` và dùng project cố định `demo-campushub-uc039`. Không tạo fixtures trên production và không sửa seed sản phẩm.

Emulator tests xác minh: Owner/Admin ALLOW; Other Organizer/Student/disabled/guest DENY; hard delete DENY; protected fields không được đổi kèm cancel; idempotent retry; draft/finished theo policy; event không tồn tại; management history/discovery; registration mới bị chặn, registrations cũ còn nguyên; transaction retry khi có concurrent cancel. Có positive control chứng minh cùng Student đăng ký được một published event trước khi thử trường hợp cancelled.

Đây là kiểm thử JavaScript SDK transaction tương đương với Dart và Rules thật trên Emulator. Kết hợp với Dart repository/provider/widget tests và build Windows; không tuyên bố đã chạy native Windows end-to-end với Firebase production.

## 5. Dependencies

| Dependency | Ảnh hưởng |
|---|---|
| UC-035 | Chỉ thay phần gọi dialog Cancel; giữ nguyên KPI/model/query. Invalidation sau cancel được giữ và kiểm chứng |
| UC-034 | Không sửa Rules/Indexes/seed hoặc deploy; dùng Emulator đã có và thêm riêng cancel test fixtures |
| UC-042 | Tái sử dụng resolver actor và Owner/Admin Rules. Không thay role policy; quyền được kiểm chứng bằng SDK/Emulator |
| Member 4 | Không sửa RegistrationRepository, QR/check-in hoặc transactions. Chỉ kiểm tra đăng ký mới bị từ chối và registrations/counters cũ được giữ |
| Create/Update/Managed Events | Không viết lại form hoặc mutation contracts. Chỉ nối dialog tại hai entry points cancel; regression tests PASS |

## 6. Remaining Issues

Không còn phần triển khai bắt buộc UC-039 đang thiếu theo kiểm chứng hiện tại. Toàn bộ repository chưa xanh vì ba lỗi đã có từ trước UC-039:

1. `test/navigation/campus_navigation_test.dart:35`: Student Back từ Clubs/Notifications kỳ vọng nút Back không còn trên giao diện.
2. Cùng file/dòng: Admin Back từ Clubs/Notifications, cùng nguyên nhân.
3. `test/events/discovery_screens_test.dart:175`: header Discover tràn ngang 37 px trong responsive test có sẵn.

Các lỗi này đã được đối chiếu trên HEAD chưa sửa ở phiên UC-035; log `build/uc035-baseline-tests.log` và báo cáo `docs/uc035_organizer_dashboard.md` ghi nhận cùng ba failure. UC-039 không sửa các module/navigation đó. Lần chạy UC-039 cuối còn đúng ba failure này; không có failure mới.

Production Firebase/native Windows E2E: **NOT VERIFIED**, không dùng production làm môi trường test. Build Windows và automated Emulator verification đã PASS.

## 7. Conclusion

**UC-039 — READY FOR REVIEW.** Đáp ứng soft cancellation, bảo toàn dữ liệu, Owner/Admin authorization, confirmation, loading/error/success, double-submit protection, idempotent retry và invalidation. Bằng chứng: 42 targeted tests, 241 regression tests và 20 Emulator tests PASS, analyzer không có issues mới, Windows build thành công.

Commit message đã thực hiện theo yêu cầu:

```text
UC-39 HuyTGCE182405: complete UC-039 cancel event
```


## 8. Bố cục sự kiện theo yêu cầu bổ sung

Organizer Dashboard dùng cùng cách bố trí với Clubs: 3 cột khi vùng nội dung rộng từ 960 px, 2 cột từ 580 px, còn lại 1 cột. Khoảng cách ngang/dọc 18 px, ảnh cao 155 px; chiều cao nội dung thẻ tự giãn khi chữ dài hoặc cỡ chữ lớn. Áp dụng cho cả Upcoming và Recent/ongoing, giữ nguyên các actions.

Đã chạy `flutter test test/organizer/organizer_dashboard_screen_test.dart test/organizer/cancel_event_screen_test.dart test/admin/admin_event_management_test.dart --reporter expanded`: **36 PASS**, gồm kiểm tra vị trí 3/2/1 cột, chữ lớn và luồng Cancel Event. Log: `build/uc039-grid-tests.log`.
