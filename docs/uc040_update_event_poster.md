# UC-040 — Update Event Poster

> **Đã thay đổi theo lựa chọn của người dùng:** poster mới dùng Cloudinary Free,
> giữ Firebase Spark. Tài liệu hiện hành là [UC-040 Cloudinary Free](uc040_cloudinary_free.md).
> Phần dưới là lịch sử implementation Firebase Storage và chẩn đoán trước khi chuyển adapter.

## Phạm vi và thiết kế

Luồng dùng chung cho Create/Edit: Image Picker → kiểm tra ảnh → preview → Save →
Firebase Storage → cập nhật `events/{eventId}.posterUrl` → refresh các provider.
Chỉ chọn ảnh không thực hiện upload. Không thay đổi Registration/Check-in, seed
data hoặc các luồng Cancel Event.

| File | Thay đổi |
| --- | --- |
| `lib/features/organizer_events/data/event_poster_service.dart:12` | Validator; picker tại dòng 112; Firebase Storage upload/progress/cleanup tại dòng 136 |
| `lib/features/organizer_events/data/models/event_form_input.dart:20` | ID ổn định cho create; selection chứa bytes tách biệt với URL tại dòng 107 |
| `lib/features/organizer_events/presentation/viewmodels/event_poster_view_model.dart:9` | Dependency injection, selecting/preview/lỗi picker và tiến độ upload |
| `lib/features/organizer_events/presentation/screens/event_form_screen.dart:43` | Request ID, Select/Change Poster và preview tại dòng 185; lỗi và khóa thao tác |
| `lib/features/organizer_events/presentation/screens/organizer_create_event_screen.dart:16` | Scope state riêng cho từng create/edit form, không mang ảnh đã chọn sang event khác |
| `lib/features/events/data/event_repository_impl.dart:213` | Create; edit tại dòng 311; transaction tại dòng 355; upload/retry an toàn tại dòng 431 |
| `lib/features/events/presentation/viewmodels/event_list_view_model.dart` | Inject poster service vào repository hiện có |
| `lib/core/services/firebase_providers.dart:39` | Kết nối Storage Emulator khi `USE_FIREBASE_EMULATOR=true` |
| `ios/Runner/Info.plist:7` | Mô tả quyền chọn ảnh từ photo library |
| `firestore.rules:72` | Cho phép owner/admin thay URL hợp lệ của chính event, giữ protected fields |
| `storage.rules:25` | Xác minh owner/admin qua event và active profile, MIME và size |
| `test/organizer/event_poster_*`, `test/events/event_poster_repository_test.dart` | Validation, SDK service, widget, repository và retry tests |
| `notification-server/test/event-poster.integration.js` | Upload/URL/read và security tests trên emulator |
| `notification-server/test/storage-rules.integration.js` | Cập nhật test event-scoped theo ownership thực tế |
| `notification-server/package.json` | Lệnh `test:poster`, đưa poster tests vào các bộ rules tổng hợp |
| Hai test form/route hiện có | Scroll tới category trước khi tap vì form có thêm phần poster |

## Policy ảnh

- Chỉ JPG/JPEG, PNG, WebP; tối đa **5 MiB = 5 × 1024 × 1024 bytes**, UI ghi 5 MB.
- Kiểm tra extension, MIME do platform cung cấp nếu có, magic bytes và decode
  ảnh thực tế. Trường hợp platform không cung cấp MIME, suy ra từ extension và
  xác minh bằng signature + decoder.
- Đọc có giới hạn sau khi kiểm tra file size; không nạp file quá giới hạn vào bộ
  nhớ. Giới hạn ảnh giải mã ở 40 megapixels để tránh ảnh nén nhỏ nhưng quá lớn.
- Hủy picker, từ chối quyền hoặc chọn file sai không xóa poster/selection trước.
- Path upload: `events/{eventId}/{uuid}.{jpg|png|webp}`. Không dùng raw filename
  hoặc local device path làm Storage path/Firestore URL.

## Create/Edit và retry

Create tạo document bằng repository hiện có trước vì Storage Rules cần event để
kiểm tra ownership. Chỉ báo thành công và điều hướng khi upload, transaction cập
nhật URL và đọc lại event đã hoàn tất. Nếu upload lỗi, document đã tạo vẫn tồn
tại với `posterUrl == null`; form giữ request ID và repository giữ attempt để
Save lần nữa tiếp tục trên **cùng event**, kể cả khi sửa các field trước retry.

Edit kiểm tra active Owner/Admin trước upload và kiểm tra lại owner, status,
capacity và `expectedUpdatedAt` trong transaction. Chỉ cập nhật các field được
phép cùng URL mới và `updatedAt`. Không chọn ảnh mới thì không upload, không ghi
`posterUrl`, giữ nguyên ảnh cũ. Không xóa ảnh cũ sau thay thế vì URL có thể còn
được cache/tham chiếu ở nơi khác.

Các thao tác lưu trùng dùng chung upload đang chạy. Nếu timeout xảy ra, native
operation vẫn có thể hoàn tất: retry xác nhận kết quả và dùng lại URL đã upload.
Nếu details đã đổi trong lúc một save khác đang hoàn tất, trả conflict thay vì
báo lưu thành công với dữ liệu khác. UI dùng lại cơ chế submission lock hiện có;
khóa submit/picker trong lúc chọn ảnh hoặc upload/save, hiện progress, giữ dữ
liệu và cho Save lại sau lỗi.

Sau khi lưu, `OrganizerEventActions` hiện có invalidates managed list, dashboard,
discovery, home và Event Detail. Student dùng `EventPoster` hiện có để hiển thị
download URL mới.

## Security và giới hạn

Storage kiểm tra profile trong Firestore là `active` và role là organizer/admin;
claim `role: admin` không ghi đè profile student. Path `events/{eventId}` cần
event tồn tại và actor là owner hoặc admin. Event cancelled không nhận upload
mới. Giữ read policy công khai cho poster theo cấu hình trước UC-040.

Firestore cho owner/admin thay `posterUrl` đúng event path; chặn local path,
external URL, URL của event khác và sửa kèm organizer/counters/createdAt.
Tạo event bắt đầu với poster null. URL phải thuộc endpoint Firebase Storage hoặc
loopback Storage Emulator cổng 9199, với object path của đúng event. Không khóa
tên bucket để hỗ trợ namespace Firebase đã cấu hình khi chạy app trên emulator.

Client Rules không thể chứng minh download token hợp lệ, bucket thuộc project,
URL loopback sẽ truy cập được ở thiết bị khác hay nội dung object thực sự là ảnh.
Chính sách hiện tại tin cậy active
Owner/Admin gắn URL của đúng event; Storage Rules kiểm tra MIME/size, còn decoder
client xác minh nội dung. Không mở quyền event update tổng quát.

Cleanup chỉ xóa **file mới chưa được gắn** khi Firestore từ chối rõ ràng. File
đã được transaction xác nhận hoặc đã được đọc thấy trong `posterUrl` không bị
xóa vì lỗi đọc lại/conflict. Lỗi mạng không xác định giữ URL cho retry thay vì
xóa file có thể đang dùng. Nếu cleanup bị Rules/network từ chối, file chưa gắn
có thể còn lại. Việc dọn ảnh cũ/file orphan lâu dài cần một quy trình backend có
kiểm tra reference; không có thao tác xóa hàng loạt trong UC này.

Idempotency và URL giữ cho retry có hiệu lực trong form/repository session;
không cam kết phục hồi qua đóng app, khởi động lại hoặc thiết bị khác. Đóng form
sau khi create thành công một phần có thể để lại event chưa có poster.

## Kiểm chứng

Không dùng Firebase production để test; không commit/push hoặc deploy Rules.

```powershell
flutter test test/organizer/event_poster_validation_test.dart test/organizer/event_poster_service_test.dart test/organizer/event_poster_widget_test.dart test/events/event_poster_repository_test.dart
firebase emulators:exec --only firestore,storage --project demo-campushub --config firebase.security-test.json "npm --prefix notification-server run test:poster"
flutter analyze
flutter test
git diff --check
```

Chạy app với emulator cần cả Auth, Firestore và Storage:

```powershell
firebase emulators:start --only auth,firestore,storage --project campushub-prm-g2 --config firebase.security-test.json
flutter run -d windows --dart-define=USE_FIREBASE_EMULATOR=true
```

Lệnh chạy app dùng project ID hiện có trong `lib/firebase_options.dart` làm
namespace **cục bộ** của emulator; không deploy và không gọi backend production.
Cần có tài khoản/profile active với đúng role trong emulator đó. Bộ test tự động
phía trên dùng riêng `demo-campushub`, không dùng tài khoản/seed production.

Kết quả ngày 21/10/2026:

| Kiểm tra | Kết quả |
| --- | --- |
| Tất cả tests Organizer + poster repository + update/create retry | **PASS: 234/234** |
| Firestore/Storage Emulator (`test:poster`) | **PASS: 82/82** |
| `flutter analyze` | **PASS: No issues found** |
| `dart format` các Dart files thay đổi | **PASS** |
| `git diff --check` | **PASS** |
| `flutter test` toàn project | **442 PASS / 7 FAIL có sẵn** |

Bộ emulator chứng minh Owner/Admin upload và gắn URL thật; Other Organizer,
Student, disabled user và guest bị từ chối. Student giả claim admin vẫn bị chặn;
Student đọc được URL/bytes poster; MIME/size, event path và protected fields đều
được kiểm tra. Storage Rules không decode nội dung file: test MIME là kiểm tra
metadata; các decoder tests riêng phía Dart dùng JPG/PNG/WebP thực sự hợp lệ.

`flutter test` toàn project còn 7 lỗi ngoài UC-040. Đã trích xuất HEAD vào
`.dart_tool/uc040_baseline` và chạy cùng ba file lỗi: **24 PASS / cùng 7 FAIL**.
Các lỗi có sẵn gồm bốn ca preview (`clubs` phone/large-phone, `detail` large-phone,
`login` large-phone), hai ca Back navigation Student/Admin và Discovery với text
scale lớn bị RenderFlex overflow. Giữ nguyên các màn hình này theo phạm vi UC-040.

Bằng chứng local: `.dart_tool/uc040_final_targeted.log`,
`.dart_tool/uc040_emulators_final.log`, `.dart_tool/uc040_analyze_final.log`,
`.dart_tool/uc040_all_tests_final.log`, `.dart_tool/uc040_baseline_tests.log`.

Chưa thực hiện manual native photo-dialog testing trên Android/iOS hoặc deploy
Rules production. Các nền tảng này vẫn cần Firebase configuration hợp lệ của dự
án trước khi chạy ứng dụng; UC này không tạo project/bucket hoặc thay seed data.

**Status: DONE trong phạm vi UC-040 — READY FOR REVIEW.** Các kiểm tra mục tiêu
và emulator đã PASS; bảy lỗi baseline toàn project không phát sinh từ UC này.

Commit message đề xuất: `feat(organizer): implement UC-040 event poster upload`.

## Chẩn đoán lỗi upload khi chạy Firebase thật

Ngày 21/10/2026, khi chạy `flutter run -d windows`, upload poster thất bại.
Kiểm tra HTTP chỉ đọc tại Google Cloud Storage JSON API trả về:

```text
GET https://storage.googleapis.com/storage/v1/b/campushub-prm-g2.firebasestorage.app
HTTP 404: The specified bucket does not exist.
```

Tên bucket cũ `campushub-prm-g2.appspot.com` cũng trả về cùng lỗi. Bucket đang
được cấu hình trong `lib/firebase_options.dart` chưa tồn tại ở backend. Không
thể hoàn tất upload thật chỉ bằng hot restart hoặc đổi xử lý lỗi phía client.

Đã sửa service để phân biệt lỗi thiếu bucket/project/configuration, quota,
permission, network và cancellation; lỗi không xác định không còn mặc định
khẳng định là lỗi mạng. Debug terminal giữ mã lỗi Firebase, bucket và thông báo
SDK. Cleanup sau lỗi URL lookup chỉ chạy nếu upload đã hoàn tất, với giới hạn
chờ 3 giây; không phát sinh yêu cầu delete khi upload chưa thành công.

Kiểm tra bổ sung: **38/38 tests poster validation/service/widget/repository PASS**.
Các tests mới bao gồm mã lỗi có tiền tố `storage/`, lỗi thiếu configuration và
không xóa object sau upload bị từ chối. **Analyzer hai file: PASS, No issues found**;
**`git diff --check`: PASS** cho bản sửa chẩn đoán.

Để dùng backend thật, quản trị viên cần kiểm tra
[Firebase Console → Storage](https://console.firebase.google.com/project/campushub-prm-g2/storage),
khởi tạo bucket và đối chiếu tên thực tế với `storageBucket`. Firebase hiện yêu
cầu gói Blaze cho Cloud Storage, theo
[tài liệu Firebase](https://firebase.google.com/docs/storage/flutter/start).
Rules UC-040 cũng cần được áp dụng vào backend trước khi kiểm thử tích hợp thật.
Không tự tạo bucket, đổi gói thanh toán hoặc deploy production trong công việc này.

**Backend thật hiện bị chặn bởi bucket chưa tồn tại; kết quả emulator không
chứng minh backend production đã được provision.**
