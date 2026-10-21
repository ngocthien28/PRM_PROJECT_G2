# UC-040 — Event Poster với Cloudinary Free

Ngày 21/10/2026, người dùng chọn Cloudinary Free thay Firebase Storage để giữ
Firebase ở gói Spark và tiếp tục chạy `flutter run -d windows`. Đây là thay đổi
đã được chấp thuận so với yêu cầu Firebase Storage ban đầu.

## Luồng hiện tại

Image Picker → kiểm tra JPG/JPEG/PNG/WebP ≤ 5 MiB → preview → Save → Cloudinary
→ transaction lưu `events/{eventId}.posterUrl` → refresh managed list và detail.
Chỉ chọn ảnh không upload. Thông tin tài khoản/event vẫn nằm trong Firebase.
Firebase Storage và gói Blaze không được dùng cho upload poster mới.

Production provider dùng `CloudinaryEventPosterService`; implementation Firebase
trước đây được giữ để tương thích/test hồi quy, không phải upload provider đang
hoạt động. Các tính năng avatar/logo khác giữ service riêng hiện có.

## Files

| File | Thay đổi |
| --- | --- |
| `lib/features/organizer_events/data/cloudinary_event_poster_service.dart` | HTTP multipart, MIME chính xác, UUID/event path, kiểm tra response/URL, progress, timeout/abort, cleanup bằng token |
| `lib/features/organizer_events/data/event_poster_service.dart` | DTO thêm deletion token chỉ giữ trong bộ nhớ; dùng lại validator/picker hiện có |
| `lib/features/organizer_events/presentation/viewmodels/event_poster_view_model.dart` | Chuyển provider từ Firebase Storage sang Cloudinary; đóng HTTP client khi dispose |
| `firestore.rules` | Owner/Admin được gắn URL Cloudinary đúng cloud account và event; giữ protected fields và URL Firebase cũ |
| `test/organizer/cloudinary_event_poster_service_test.dart` | HTTP errors, response giả/sai path, MIME, progress, timeout, token cleanup, provider không cần Firebase Storage |
| `test/organizer/cloudinary_event_poster_live_test.dart` | Test mạng thật opt-in dùng PNG 2×2 tự tạo, upload và đọc URL qua production service |
| `test/events/event_poster_repository_test.dart` | Fake upload trả URL Cloudinary; kiểm tra create/edit/retry không mất reference |
| `notification-server/test/event-poster.integration.js` | Bổ sung Owner/Admin/Student, cloud account/event path, spoof URL, counters/timestamps trên Firestore Emulator |
| `README.md` | Hướng dẫn Spark + Cloudinary và cập nhật Firestore Rules |

Không sửa Registration/Check-in, Club logo service, seed data hoặc business
logic Create/Edit ngoài adapter poster. Các thay đổi uncommitted trước đó được
giữ nguyên. Không commit/push, nâng gói thanh toán hoặc deploy production.

## Cấu hình dùng ngay

Mặc định dùng lại cấu hình logo CLB:

```text
CLOUDINARY_CLOUD_NAME=djznx3z7o
CLOUDINARY_UPLOAD_PRESET=campushub_club_logos_unsigned
```

Preset đã nhận thành công ảnh kiểm thử online. Public ID mà app yêu cầu:
`campushub/event_posters/{eventId}/{uuid}`. Không dùng tên file trên máy làm ID.
Cloudinary không cho unsigned upload ghi đè asset đã tồn tại.

Trước khi lưu vào Firebase thật, quản trị viên cần review và tự áp dụng Rules
đã sửa từ thư mục project. **Lệnh sau thay đổi Firestore Rules trên backend thật**:

```powershell
firebase.cmd login
firebase.cmd deploy --project campushub-prm-g2 --only firestore:rules
```

Chỉ cần Firestore Rules cho adapter mới; không tạo Storage bucket hoặc bật Blaze.
Sau đó dừng app và chạy lại:

```powershell
flutter run -d windows
```

Nếu dùng cloud account khác, sửa cả cấu hình client **và** allow-list cloud name
trong `validPosterUrl` của `firestore.rules`, rồi kiểm tra/deploy Rules tương ứng.

Có thể tạo preset riêng cho poster và dùng:

```powershell
flutter run -d windows --dart-define=CLOUDINARY_EVENT_POSTER_UPLOAD_PRESET=TEN_PRESET_UNSIGNED
```

Preset riêng cần cho phép public ID do app cấp; giới hạn server nên gồm
`allowed_formats=jpg,jpeg,png,webp`, `max_file_size=5242880`. Nếu preset thêm
fixed folder prefix, adapter và Rules hiện hỗ trợ prefix cũ
`campushub/club_logos/`; cấu hình folder khác cần cập nhật policy tương ứng.
Không đưa API secret vào Dart, source control hoặc `--dart-define`.

## Retry và bảo toàn dữ liệu

Tạo event dùng cùng request ID trong một form: upload thất bại rồi Save lại sẽ
tiếp tục đúng document, không tạo event trùng. Edit không chọn ảnh mới thì giữ
poster cũ. Lỗi upload/Firestore không xóa ảnh cũ. Owner, counters, createdAt và
metadata được bảo vệ bởi transaction và Rules hiện có.

Requests trùng dùng chung attempt; timeout phía caller không làm mất URL của
upload đang chạy. Retry xác nhận commit không rõ kết quả thay vì upload lại.
Scope riêng từng form ngăn preview ảnh của event A xuất hiện trong form event B.

Progress đo bytes HTTP client đã tiêu thụ, giữ dưới 100% cho tới khi response
được kiểm tra. Đây không phải xác nhận từng byte từ server; trên web HTTP client
có thể buffer trước khi gửi. UI vẫn đợi Cloudinary và Firestore hoàn tất mới báo
success/điều hướng. Giới hạn client 5 MiB và decoder 40 megapixels được giữ nguyên.

## Phân quyền và cleanup

Repository kiểm tra active Owner/Admin trước upload. **Firestore Rules** là nơi
enforce quyền gắn poster: Other Organizer/Student/guest/disabled không thể đổi
`posterUrl`, giả cloud account/event path hoặc thay protected fields kèm theo.
Student đọc được poster qua URL Cloudinary công khai và event read policy.

**Cloudinary unsigned endpoint không xác minh tài khoản Firebase**: người biết
preset có thể gọi upload trực tiếp. Nó không cấp quyền ghi Firestore. Muốn chặn
upload trực tiếp theo role/ownership ở server cần backend ký upload sau khi
xác minh Firebase token. Adapter này dùng kiến trúc unsigned giống logo CLB;
không cam kết security policy của Firebase Storage áp dụng cho Cloudinary.
Client kiểm tra nội dung ảnh; cần đặt giới hạn MIME/size ở preset để chống bypass
validation phía client. Smoke test không xác minh toàn bộ cấu hình preset bằng
Admin API.

Chỉ cố xóa ảnh mới chưa gắn sau lỗi xác định và khi Cloudinary cung cấp
`delete_token`. Token được giữ trong memory, không ghi Firestore/log hoặc trả
vào UI. Token hết hạn sau 10 phút. **Preset hiện có không trả delete token**;
ảnh upload rồi bị Firestore từ chối có thể còn lại để admin dọn qua Cloudinary
Console. Không xóa ảnh cũ/ảnh đã được Firestore reference, không dùng API secret
ở client, không báo cleanup thành công giả.

Idempotency/attempt chỉ có hiệu lực trong cùng form/repository session. Đóng app
giữa thao tác hoặc cleanup token hết hạn có thể để lại asset chưa được gắn.
Các ảnh PNG kiểm thử nhỏ nằm dưới event ID `uc040-cloudinary-smoke`; có thể dọn
thủ công trong Cloudinary Media Library. Gói Free có giới hạn sử dụng; adapter
báo lỗi quota thay vì tự đổi gói hoặc dùng dịch vụ trả phí khác.

Tham khảo: [Cloudinary unsigned upload](https://cloudinary.com/documentation/image_upload_api_reference#unsigned_upload_parameters),
[upload presets](https://cloudinary.com/documentation/upload_presets),
[deletion tokens](https://cloudinary.com/documentation/client_side_uploading).

## Verification

Unit/widget/repository tests không gửi ảnh lên cloud:

```powershell
flutter test test/organizer/cloudinary_event_poster_service_test.dart test/organizer/event_poster_validation_test.dart test/organizer/event_poster_widget_test.dart test/events/event_poster_repository_test.dart test/organizer/organizer_create_event_route_test.dart
```

Rules tests chỉ dùng project demo. Bộ lệnh vẫn chạy Storage legacy regression,
nhưng các ca Cloudinary kiểm tra Firestore mutation riêng:

```powershell
firebase.cmd emulators:exec --only firestore,storage --project demo-campushub --config firebase.security-test.json "npm.cmd --prefix notification-server run test:poster"
```

Smoke test **opt-in**, upload một PNG 2×2 tự tạo lên Cloudinary và đọc URL thật;
không ghi Firebase production:

```powershell
flutter test --dart-define=RUN_CLOUDINARY_POSTER_SMOKE=true test/organizer/cloudinary_event_poster_live_test.dart
```

Không bật flag này thì smoke test được skip trong test suite thông thường.
Kết quả verification cuối được bổ sung sau khi chạy các checks.
