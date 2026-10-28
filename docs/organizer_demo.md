# UC-047 — Kịch bản demo Organizer GH

Chỉ dùng Firebase Emulator với project `demo-campushub`. Kết quả backend tự động và demo UI thủ công được ghi riêng trong [báo cáo UC-044–047](uc044_047_report.md).

## Chuẩn bị

- Flutter/Dart theo `pubspec.yaml`, Node >=22, Java 21, Firebase CLI.
- Chạy `flutter pub get` ở thư mục gốc và `npm.cmd --prefix notification-server ci` nếu chưa có dependencies.
- Windows desktop cần Visual Studio với workload Desktop development with C++.
- Poster fixture: `firebase/fixtures/organizer-poster.png` (PNG 512×512, tái sử dụng icon hiện có; dưới 5 MiB).
- Seed dùng lại `firebase/seed/seed.mjs` của UC-034; không cần service-account hoặc credentials production.

## Khởi động

Terminal 1, tại thư mục gốc:

```powershell
firebase.cmd emulators:start --only auth,firestore,storage --project demo-campushub --config firebase.security-test.json
```

Terminal 2:

```powershell
$env:GCLOUD_PROJECT='demo-campushub'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8087'
$env:FIREBASE_STORAGE_EMULATOR_HOST='127.0.0.1:9199'
npm.cmd --prefix notification-server run seed
flutter run -d windows --dart-define=USE_FIREBASE_EMULATOR=true
```

App emulator mode chọn cùng project/bucket với seed. Windows dùng `EmulatorEventPosterService` qua Firebase HTTP endpoint vì Firebase Storage SDK Windows không hỗ trợ emulator; request dùng ID token người đăng nhập và vẫn được Storage Rules kiểm tra. Android/Web dùng `FirebaseEventPosterService`. Host mặc định `127.0.0.1`; Android Emulator cần thêm `--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2` và chạy `-d <device-id>`. Project có thể đổi bằng `--dart-define=FIREBASE_EMULATOR_PROJECT_ID=demo-...` nhưng phải đổi cả CLI và `GCLOUD_PROJECT` tương ứng. iOS/Linux chưa có FirebaseOptions trong repository.

SQLite draft chạy trên mobile/desktop; Flutter Web hiện không hỗ trợ SQLite của project và sẽ hiển thị lỗi lưu cục bộ, không giả lập persistence bằng RAM.

Seed ghi đè các fixture ID cố định để khôi phục trạng thái demo. Nó không nhân bản fixture khi chạy lại, nhưng cũng không phải công cụ giữ nguyên các thay đổi thủ công trên fixture. Event mới tạo qua UI dùng ID riêng. Chỉ seed lại trước buổi demo; không seed giữa luồng đăng ký/check-in.

## Tài khoản

| Email | UID | Role |
|---|---|---|
| organizer1@demo.com | demo_organizer_01 | organizer |
| organizer2@demo.com | demo_organizer_02 | organizer |
| student1@demo.com | demo_student_01 | student |
| student2@demo.com | demo_student_02 | student |
| admin1@demo.com | demo_admin_01 | admin |

Mật khẩu chỉ dành cho emulator nằm trong trường `password` của fixture `users` trong `firebase/seed/seed_data.mjs`. Không sử dụng tài khoản/mật khẩu này trên production. Seed tạo cả Auth user, custom claim và `/users/{uid}` cùng UID/role.

## Dữ liệu mẫu

10 events, 9 registrations, 5 accounts, 2 clubs, 3 notifications. Ngày upcoming/past tính tương đối tại thời điểm seed. Có event published còn chỗ, full, cancelled, draft, past; hai organizer sở hữu event riêng. Registration bao gồm registered, cancelled và checkedIn. Counter chỉ tính registered + checkedIn, checkedIn không vượt registered/capacity.

Khi Storage Emulator được bật, event `demo_event_tech_flutter_01` có poster upload thật tại `events/<eventId>/demo-poster.png`; URL download được lưu trong Firestore. Không bật Storage thì poster null và seed in thông báo NOT VERIFIED. QR token dùng UUID như repository, không hard-code token giả; chạy seed lại giữ token của registration đã tồn tại.

## Các bước demo UI

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Login Organizer A; mở Dashboard/My Managed Events | KPI đúng, danh sách quản lý chỉ event của A |
| 2 | Create: title `GH Campus Workshop`, description >=20 ký tự, Technology, Hall A, start ngày mai, end sau start 2 giờ, capacity 40; chọn PNG fixture; submit | Upload thật, posterUrl tồn tại, event xuất hiện đúng một lần trong managed list |
| 3 | Edit title thành `GH Campus Workshop Updated`, location Hall B; giữ poster | Dữ liệu mới lưu; owner, registeredCount, checkedInCount và poster cũ giữ nguyên |
| 4 | Logout, login Student A; mở/refresh Feed rồi Detail | Thấy event với title/location/ngày/poster mới |
| 5 | Join; thử Join lại nếu UI cho phép | Có đúng một ticket, registeredCount tăng một lần |
| 6 | Mở vé QR của Student A; Organizer A dùng scanner hoặc nhập payload qua flow hiện có | Registration thành checkedIn, checkedInAt tồn tại; quét lại không tăng count |
| 7 | Organizer A mở/refresh Participants | Registered 1, Checked-in 1, Not yet 0, Rate 100%; đúng Student A |
| 8 | Cancel Event và xác nhận | status cancelled; event/history vẫn tồn tại, Feed upcoming bỏ event, Student B không Join được |
| 9 | Organizer B thử Edit/Participants của A; Student truy cập Create/Edit, sửa counter; thử hard delete qua security tests | Tất cả thao tác trái quyền bị từ chối |

Check-in do Organizer thực hiện với vé của Student, theo implementation Member 4. Không thay đổi policy để ép demo. Cần hai phiên/thiết bị nếu dùng camera quét QR. Nếu dùng một máy, sử dụng luồng nhập payload hiện có; không tự dựng token.

Kiểm tra UC-044 riêng: nhập form chưa hợp lệ → chờ 750 ms hoặc Save Draft → đóng/mở app → đăng nhập cùng Organizer → Create Event khôi phục dữ liệu. Chuyển Organizer khác không thấy draft. Poster cần chọn lại sau khi mở phiên mới và UI có thông báo. Discard Draft chỉ xóa sau xác nhận; submit lỗi giữ draft.

## Automated verification

Không chạy các suite này đồng thời với demo thủ công: tests xóa fixture trong project emulator để cô lập.

```powershell
flutter analyze --no-pub
flutter test --no-pub
$env:CI='true'
firebase.cmd emulators:exec --only auth,firestore,storage --project demo-campushub --config firebase.security-test.json "npm.cmd --prefix notification-server run test:organizer"
```

`test:organizer` gộp ownership, poster, cancel, dashboard, UC-046 flow, seed và UC-047 demo. Chạy riêng bằng `test:flow` hoặc `test:demo` trong cùng lệnh emulators:exec. Nếu emulator đang chạy ở terminal khác, dùng các biến host của phần setup rồi chạy `npm.cmd --prefix notification-server run test:demo` trực tiếp.

Regression riêng cho lỗi Windows Create/poster: `npm.cmd --prefix notification-server run test:windows-create` sau khi đặt các biến host trên. Suite này không clear project demo: query tests dùng project riêng, Storage tests dùng ID fixture ngẫu nhiên và chỉ cleanup fixture tự tạo. Không dùng lệnh `test:organizer` trong khi đang thực hiện demo thủ công.

UC-046 JS kiểm tra SDK transaction + Rules; Dart test `test/organizer/event_flow_uc046_test.dart` gọi production repositories + summary provider trên fake Firestore. UC-047 JS đăng nhập thật Auth Emulator, upload/download Storage thật và kiểm tra toàn bộ luồng backend. Các kết quả đó không thay thế thao tác Image Picker/scanner bằng tay.

## Troubleshooting

| Triệu chứng | Kiểm tra |
|---|---|
| Không kết nối/login | Auth 9099, Firestore 8087, Storage 9199; cùng project demo-campushub; Windows dùng loopback, Android dùng 10.0.2.2 |
| permission-denied | Profile có đúng UID/role/status active; đúng organizer owner; không sửa counters ngoài transaction Member 4 |
| Missing index | Kiểm tra query với firestore.indexes.json; emulator không chứng minh index production đã build; không deploy production trong demo |
| Upload lỗi | Bật emulator define khi chạy app, Storage Emulator đang chạy, PNG/JPG/WebP <=5 MiB và file giải mã được |
| Create lỗi permission-denied tại `_EventCreateAttempt` | Dùng bản sửa bounded owner range query; exact documentId equality cho ID chưa tồn tại có thể bị Rules xử lý như get và từ chối. Khởi động lại app sau cập nhật |
| Windows báo Storage Emulator không được hỗ trợ | Bản sửa đã chuyển poster Windows sang HTTP emulator có xác thực; thoát bằng q và chạy lại app để thay instance service cũ |
| Poster không tải trên Android | URL seed trỏ loopback máy host; dùng upload qua app trên Android để URL dùng host 10.0.2.2 hoặc chuẩn bị endpoint phù hợp. Không đổi Rules để mở quyền |
| Feed cũ | Refresh hoặc mở lại Detail; event phải published và startAt trong tương lai |
| Counter/summary cũ | Refresh Participants; so eventId của ticket; xác minh transaction đã commit, không seed lại giữa demo |
| Draft không lưu | Dùng desktop/mobile; kiểm tra quyền/dung lượng SQLite; Save Draft để retry, không xóa database chung |
| Draft có ảnh cũ | Chọn lại poster theo cảnh báo; không có upload khi chỉ autosave |

Sau demo, dừng emulator bằng Ctrl+C. Không deploy, commit/push hoặc ghi dữ liệu production trong các bước trên.
