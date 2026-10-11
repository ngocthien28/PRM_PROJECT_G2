# Iteration 1 — Authentication Foundation

Ngày thực hiện: 11/10/2026. Owner: Member 1 — Minh.

## Phân tích trước triển khai

Source ban đầu chỉ là skeleton: `main.dart` chạy MaterialApp bootstrap, dependencies chỉ có Flutter/flutter_test/flutter_lints. Các file model, Auth/Profile repository, provider, router, form và validator là TODO. Firebase options chưa có thông tin dự án. Không có implementation cần bảo toàn hoặc implementation trùng lặp; các module khác vẫn giữ nguyên.

Cấu trúc liên quan: `lib/core/{constants,errors,routing,services,theme,utils}`, `lib/features/auth/{data,presentation}`, `lib/features/profile/data`, `lib/features/home/presentation/screens`, `lib/shared/enums`, `test/auth`, `test/core`.

Môi trường: Flutter 3.47.3, Dart 3.13.3, Windows. SDK requirement đã cập nhật thành Flutter >=3.44 / Dart >=3.12 theo package thực tế. Dependencies: flutter_riverpod 3.4.3, go_router 18.0.2, firebase_core 4.15.0, firebase_auth 6.7.0, cloud_firestore 6.10.0. Test: mocktail 1.0.5, fake_cloud_firestore 4.3.0, firebase_auth_mocks 0.15.2. Phiên bản khóa trong pubspec.lock.

| Chức năng | File liên quan | Hiện trạng ban đầu | Công việc |
|---|---|---|---|
| Firebase initialization | main.dart, app.dart, firebase_options.dart | Bootstrap; chưa có cấu hình | ProviderScope, async startup, lỗi và retry |
| Model/role | auth/data/models/app_user.dart, shared/enums/user_role.dart | Chưa có | Schema mục 10.1, fail closed với role lạ |
| Register/Login/Reset/Logout | auth/data/auth_repository*.dart | Chưa có | Firebase SDK và error mapping |
| Hồ sơ ban đầu | profile/data/profile_repository*.dart | Chưa có | Create-if-absent transaction và stream |
| Session/ViewModel | auth/presentation/viewmodels/auth_view_model.dart | Chưa có | Loading/success/error, double-submit, state theo UID |
| Form Auth | auth/presentation/screens, widgets | Chưa có | Validation, disable khi loading, thông báo |
| Splash/router/logout destination | core/routing, student_shell.dart | Chưa có, phụ thuộc shared | Session gate, role landing, chặn Back |
| Tests | test/auth, test/core, widget_test.dart | Placeholder/bootstrap | Test logic, repository, form và navigation |

Kế hoạch đã báo trước khi sửa code: contracts/dependencies → Firebase/Auth/Profile repository → session/ViewModel → form/Splash/router/logout → tests và tài liệu. ProfileRepository đảm nhiệm chức năng UserRepository để tránh abstraction trùng lặp. Không bổ sung Storage, SQLite, FCM, theme settings, Profile CRUD hoặc tính năng các thành viên khác.

## Hành vi đã triển khai

- Firebase initialization nằm trong FutureProvider, chạy sau ensureInitialized/ProviderScope và trước khi khởi tạo router/repositories. Loading và lỗi có UI; Retry không tạo dữ liệu giả.
- AuthRepository dùng Firebase Auth thật để register, sign in, reset password và sign out. Startup reload tài khoản khôi phục để phát hiện tài khoản disabled/revoked hoặc lỗi mạng.
- Register có name theo blueprint 2–50 ký tự, email, password tối thiểu 8 ký tự, confirm khớp. Login chỉ yêu cầu password không rỗng để không khóa tài khoản cũ có password ngắn hơn chính sách đăng ký mới. Email được trim/lowercase; password giữ nguyên.
- AppUser đúng schema: uid, email, displayName, avatarUrl, role, status, createdAt, updatedAt. Timestamp ghi bằng serverTimestamp, đọc UTC. Không có password trong Firestore hoặc local DB.
- Tạo profile dùng transaction đọc document; chỉ tạo khi chưa tồn tại, mặc định student/active. Không ghi đè role, status hoặc profile sẵn có. Snapshot chờ server timestamp không bị coi là profile lỗi.
- Auth và Firestore không phải transaction chung. Nếu Auth đã tạo nhưng profile setup thất bại, giữ tài khoản và báo lỗi rõ; không đăng ký lại tài khoản cùng email. Splash phân biệt thiếu profile với lỗi đọc profile. Với document thực sự thiếu, “Retry profile setup” tạo lại cùng UID. Với lỗi tải, “Retry” chỉ tải lại; không tự tạo/ghi đè dữ liệu chưa đọc được. Nếu tên Auth không lưu được trước khi thất bại, recovery dùng tên ban đầu “Student”; người dùng có thể sửa tên trong Iteration 2.
- authStateProvider theo Firebase userChanges; currentUserProvider đổi stream profile theo UID. Provider hủy luồng cũ khi session đổi. Guard kiểm tra UID, loading, lỗi, status active và role; không sử dụng profile cũ để mở route.
- Router duy nhất điều hướng session, có refresh từ providers; các widget không tự điều hướng sau login/register. Các link giữa form dùng go. Routes: /splash, /login, /register, /forgot-password, /home, /organizer, /admin. Landing theo role tối thiểu, chưa phải dashboard đầy đủ.
- Logout invalidates state trong bộ nhớ, không xóa Firestore. Router thay route stack; Back và truy cập trực tiếp route bảo vệ bị chặn. Logout thất bại giữ session và báo lỗi.
- Tài liệu hiện tại không yêu cầu email verification; chưa thêm cổng verification. Nếu nhóm thay chính sách, bổ sung contract và luồng verification cùng server rules trước khi áp dụng.
- UI có loading/error/success, scroll và giới hạn chiều rộng form. View không gọi Firebase.
- firestore.rules chỉ cho phép đọc profile của chính UID và tạo schema student/active bằng server time; chặn ghi role/status tùy ý, thêm password, update/delete, truy cập UID khác và các collection ngoài Iteration 1. Chưa deploy hoặc test rules bằng Emulator; cần làm trước demo Firebase.

## File thay đổi

Các file đã có được hoàn thiện:

- `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `lib/main.dart`, `lib/app.dart`, `lib/firebase_options.dart`, `README.md`.
- `lib/core/constants/firestore_collections.dart`; `lib/core/errors/{app_exception,error_mapper}.dart`; `lib/core/routing/{app_router,route_guards,route_names}.dart`; `lib/core/services/firebase_providers.dart`; `lib/core/theme/app_theme.dart`; `lib/core/utils/validators.dart`.
- `lib/shared/enums/user_role.dart`; `lib/features/auth/data/{auth_repository,auth_repository_impl}.dart`; `lib/features/auth/data/models/app_user.dart`.
- `lib/features/auth/presentation/screens/{login,register,forgot_password}_screen.dart`; `lib/features/auth/presentation/viewmodels/auth_view_model.dart`; `lib/features/auth/presentation/widgets/auth_form_field.dart`.
- `lib/features/profile/data/{profile_repository,profile_repository_impl}.dart`; `lib/features/home/presentation/screens/student_shell.dart`.
- `test/auth/auth_view_model_test.dart`, `test/core/validators_test.dart`, `test/widget_test.dart`.

File mới:

- `lib/features/auth/presentation/screens/splash_screen.dart`, `lib/features/auth/presentation/widgets/auth_form.dart`.
- `test/auth/{auth_fakes,auth_screens_test,repositories_test,route_guards_test,error_mapper_test}.dart`.
- `firestore.rules`, `firebase.json`, tài liệu này.
- Flutter-generated `android/`, `ios/`, `web/`, `.metadata`. Android main manifest có INTERNET permission cho release; application ID mặc định com.example.campushub, iOS deployment target 15.0. Không tạo Firebase credentials.

## Kiểm thử và giới hạn

Các test bao phủ email/password/name/confirm; success/error và chống double-submit của ViewModel; Firebase API calls và error mapping; partial registration và recovery; profile schema/idempotence; unknown role; restored session, disabled status, lỗi profile/retry; form/loading/errors; forgot-password link; Register → Logout → Login lại; Back/route access; startup lỗi cấu hình.

Chạy lại:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/auth test/core/validators_test.dart test/widget_test.dart
flutter build web
```

Kết quả cuối:

- dart format: kiểm tra cuối 123 file, 0 thay đổi.
- flutter analyze: No issues found.
- Test Iteration 1: 52/52 pass.
- flutter test toàn dự án: 52 pass, 5 lỗi load từ các placeholder bên dưới.
- flutter build web: thành công; artifact build/web. Build cuối --no-wasm-dry-run có exit code 0, 33 giây. Có warning font CupertinoIcons từ dependency; các màn hình hiện tại dùng Material widgets/icons.
- flutter run -d web-server: đã compile và phục vụ localhost:8765, HTTP 200; server đã dừng sau kiểm tra. Chưa quan sát runtime bằng trình duyệt hoặc thiết bị thật.
- Automatic approval review chặn mở Chrome headless để kiểm tra trực tiếp, chỉ trả lý do “blocked by policy”. Widget tests đã kiểm tra UI và startup error; không thay thế demo Firebase thật.
- Android APK, iOS build, Firestore Rules Emulator và Firebase end-to-end: chưa chạy. Firebase options vẫn là placeholder có lỗi cấu hình rõ ràng.

Log test cục bộ: build/auth-test-results.log và build/full-test-results.log; không commit các artifact build.

Kiểm tra khi tích hợp remote main trước push: giữ nguyên commit Organizer 7d70782, merge không conflict. flutter analyze không có vấn đề; bộ Auth/Organizer có 93 pass (bao gồm toàn bộ 52 test Auth), 11 lỗi widget Organizer vì tap nút Save ngoài viewport 800×600. Không sửa code/test Organizer. Placeholder test/organizer/event_form_test.dart đã được remote triển khai, nên còn bốn file module khác thiếu main. Log: build/pre-push-tests.log. Các kết quả toàn dự án và hiện trạng skeleton bên trên ghi nhận thời điểm trước merge.

Lệnh toàn bộ `flutter test` phát hiện năm placeholder module ngoài Auth thiếu main: test/clubs/club_view_model_test.dart, test/events/event_repository_test.dart, test/organizer/event_form_test.dart, test/registration/registration_repository_test.dart và test/registration/ticket_screen_test.dart. Không sửa hoặc đánh dấu pass các file này.

## Cấu hình và demo thủ công còn cần

1. Chọn application ID/bundle ID, cài FlutterFire CLI, chạy flutterfire configure để thay firebase_options.dart. Chọn đúng Firebase project của nhóm, không tạo credentials giả.
2. Enable Email/Password trong Firebase Auth, tạo Firestore, review/deploy rules trong Firebase Console hoặc Firebase CLI (`firebase deploy --only firestore:rules --project <project-id>`). File firebase.json chưa gắn project, chưa có deployment.
3. Kiểm tra rules bằng Emulator/Rules Playground: guest/UID khác bị chặn; student/active create thành công; role admin, status disabled, thêm password, cập nhật role/status và xóa bị chặn. Create bằng server timestamps phải thành công. Rules hiện deny các feature khác; tích hợp rules của các module sau trước khi dùng.
4. Trên máy hiện tại cần chạy flutter doctor --android-licenses; kết nối Android/emulator. iOS cần macOS/Xcode. Chưa kiểm chứng Android APK hoặc iOS build.
5. Demo Firebase thật: register email chưa có → kiểm tra UID/schema/student/active → logout → login lại → restart app kiểm tra restored session → logout/Back → forgot password và kiểm tra email/reset qua liên kết Firebase → login password mới.
6. Demo lỗi: invalid form, email trùng, wrong credential, tắt mạng, nhấn submit nhiều lần, profile thiếu, profile read bị permission-denied, profile write thất bại sau Auth, account disabled. Khôi phục quyền/mạng rồi Retry; confirm không tạo Auth account mới hay đổi role của profile đã tồn tại.
7. Seed organizer/admin bằng thao tác quản trị đáng tin cậy, không qua client tự đăng ký; xác nhận role landing. Không ghi mật khẩu demo vào repo.

Iteration 1 chưa được coi là hoàn tất tiêu chí demo Firebase thật: thiếu cấu hình dự án, chưa deploy/test rules chính thức, chưa thực hiện luồng end-to-end với dịch vụ thật và thiết bị.

## Tích hợp Iteration 2/3

Dùng lại AppUser, ProfileRepository, authStateProvider, currentUserProvider và authViewModelProvider; bổ sung Profile CRUD/avatar/cache theo scope sau. Mọi provider giữ dữ liệu cá nhân cần phụ thuộc UID hoặc tự invalidate khi logout. Giữ schema/timestamps và role enum thống nhất. Thay landing tối thiểu bằng shell/dashboard thật trong app_router, giữ session guard và router lifecycle. Authorization thật nằm ở Firebase Rules/backend; router không thay thế server security. Rules update profile sau này phải allow-list field và không cho client thay role/status/UID/createdAt.
