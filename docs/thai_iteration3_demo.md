# Thái — Iteration 3: UC-060–UC-063

Owner: `ThaiQHCE181542`. Mỗi UC được commit riêng theo mẫu `ThaiQHCE181542: <Category> - <Feature> #<number>`.

## Phạm vi và kiểm chứng

| UC | Kết quả | Kiểm thử |
|---|---|---|
| 060 | SQLite v5 giữ trạng thái registered/checkedIn/cancelled, thời gian và QR token; tương thích cache v4; đọc server cập nhật cache, loại bỏ vé đã bị xóa; chỉ fallback khi lỗi mạng | `test/registration/offline_ticket_uc060_test.dart` |
| 061 | Test điều kiện Join, chỗ cuối cùng, đổi token khi đăng ký lại, từ chối QR cũ/quét trùng, QR widget và các màn hình lỗi | `test/registration/iteration3_flows_uc061_test.dart` cùng các test registration/checkin hiện có |
| 062 | Event Detail mở được vé checked-in; lỗi tải trạng thái có nút thử lại; check-in invalidates summary/feed/registration; My Events và Ticket làm mới khi app resume | `test/registration/participant_integration_uc062_test.dart` |
| 063 | Demo tự động 3 lần: Join → QR → nhập payload tại scanner → thành công → quét lại bị từ chối → My Events cập nhật | `test/checkin/end_to_end_demo_uc063_test.dart` |

```powershell
flutter test test/registration test/checkin test/organizer/participant_summary_provider_test.dart test/organizer/event_flow_uc046_test.dart test/local/app_database_test.dart
flutter analyze lib/features/registration lib/features/checkin lib/local lib/features/events/presentation/screens/event_detail_screen.dart test/registration test/checkin/end_to_end_demo_uc063_test.dart
```

Test dùng repository thật với Fake Firestore; kiểm thử cache dùng SQLite FFI thật. Demo widget sử dụng chức năng nhập payload của scanner, chưa chứng minh camera vật lý hoặc Firestore Security Rules. Không ghi nhận demo thiết bị là đã chạy chỉ dựa vào các test này.

Kết quả kiểm tra ngày 29/10/2026: **91 tests passed**, bao gồm 3 lượt demo widget; phân tích tĩnh các đường dẫn trong lệnh trên: **No issues found**. Log máy local nằm trong `build/iteration3-validation/` (không commit build artifact).

## Demo thiết bị / Firebase Emulator

Khởi động và seed theo [hướng dẫn Organizer](organizer_demo.md). Dùng `student1@demo.com` và `organizer1@demo.com`; mật khẩu emulator có trong `firebase/seed/seed_data.mjs`.

1. Organizer 1 tạo một event published mới, còn chỗ, bắt đầu ngày mai. Dùng event mới để tránh các vé đã được seed sẵn.
2. Student 1 mở Event Detail và chọn **Tham gia sự kiện**. Ghi nhận registeredCount tăng đúng 1; vé QR có mã đăng ký. Mở My Events và vé để cache dữ liệu.
3. Trên thiết bị sinh viên, tắt mạng, làm mới vé: QR vẫn hiển thị cùng token và có thông báo Offline. Trên mobile/desktop, đóng/mở app để kiểm tra SQLite còn vé. Web chỉ có cache trong RAM trong phiên hiện tại.
4. Organizer 1 mở participant summary của event, mở scanner, cấp quyền camera và quét QR từ màn hình sinh viên. Kỳ vọng màn hình thành công, checkedInAt có giá trị, summary checkedInCount = 1.
5. Chọn quét vé tiếp theo rồi quét lại **cùng QR**. Kỳ vọng báo quét trùng, checkedInCount vẫn là 1.
6. Student 1 bật mạng và bấm làm mới vé/My Events hoặc đưa app về nền rồi mở lại. Vé chuyển sang **Đã check-in**, My Events hiển thị trong tab tương ứng; không còn nút hủy.
7. Tắt mạng lần nữa và làm mới: trạng thái đã check-in vẫn được giữ trong cache.
8. Lặp lại với event mới thêm 2 lần. Ghi bằng chứng từng lần vào bảng dưới; không seed lại giữa Join và check-in.

Nếu không có camera, có thể dùng nút nhập mã thủ công của scanner và payload JSON `{v,rid,eid,t}` của vé do app tạo. Đây là demo xử lý payload; bước camera vẫn cần kiểm tra riêng trên thiết bị.

| Lần | Event / thiết bị | Join / QR | Scan thành công | Scan trùng, count không đổi | My Events / offline | Bằng chứng |
|---|---|---|---|---|---|---|
| 1 | Chưa chạy thiết bị | — | — | — | — | — |
| 2 | Chưa chạy thiết bị | — | — | — | — | — |
| 3 | Chưa chạy thiết bị | — | — | — | — | — |

## Các giới hạn cần hiểu khi trình bày

- Offline chỉ đọc vé đã cache. Join, hủy và check-in cần server; không có hàng đợi check-in offline.
- Trạng thái offline là bản chụp lần đồng bộ gần nhất. Trên hai thiết bị, sinh viên phải làm mới hoặc resume app sau khi organizer check-in. Không có thông báo realtime giữa hai thiết bị trong phạm vi này.
- Khi cache rỗng và mất mạng, UI báo lỗi có thể thử lại; không sinh vé mẫu hoặc giả vờ danh sách server rỗng.
- Lỗi permission/data không fallback sang cache. Lỗi lưu cache không biến một Join đã thành công trên server thành thất bại.
- Không đưa token QR thật hoặc thông tin tài khoản production vào ảnh/báo cáo công khai.
