import 'package:campushub/features/checkin/presentation/screens/checkin_result_screen.dart';
import 'package:campushub/features/checkin/presentation/viewmodels/checkin_view_model.dart';
import 'package:campushub/features/registration/data/models/registration_model.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UC-058: CheckinResultScreen Widget Tests', () {
    testWidgets('renders success result screen correctly with all details', (tester) async {
      bool scanNextTapped = false;
      bool closeTapped = false;

      final successResult = CheckinResult(
        isSuccess: true,
        message: 'Check-in thành công!',
        participantName: 'Trần Văn Hoàng',
        participantEmail: 'hoangtv@fpt.edu.vn',
        eventTitle: 'Lễ Khai Mạc Hackathon 2026',
        checkedInAt: DateTime(2026, 10, 20, 14, 30),
        registration: RegistrationModel(
          id: 'event_hack_01_user_01',
          eventId: 'event_hack_01',
          userId: 'user_01',
          status: RegistrationStatus.checkedIn,
          qrToken: 'sample-token',
          registeredAt: DateTime(2026, 10, 15),
          checkedInAt: DateTime(2026, 10, 20, 14, 30),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CheckinResultScreen(
            result: successResult,
            onScanNext: () => scanNextTapped = true,
            onClose: () => closeTapped = true,
          ),
        ),
      );

      // Verify UI elements
      expect(find.text('Check-in Thành Công!'), findsOneWidget);
      expect(find.text('Trần Văn Hoàng'), findsOneWidget);
      expect(find.text('hoangtv@fpt.edu.vn'), findsOneWidget);
      expect(find.text('Lễ Khai Mạc Hackathon 2026'), findsOneWidget);
      expect(find.text('event_hack_01_user_01'), findsOneWidget);
      expect(find.text('Quét vé tiếp theo'), findsOneWidget);
      expect(find.text('Đóng'), findsOneWidget);

      // Verify callbacks
      final scanNextFinder = find.byKey(const Key('checkinResultScanNextButton'));
      await tester.ensureVisible(scanNextFinder);
      await tester.tap(scanNextFinder);
      expect(scanNextTapped, isTrue);

      final closeFinder = find.byKey(const Key('checkinResultCloseButton'));
      await tester.ensureVisible(closeFinder);
      await tester.tap(closeFinder);
      expect(closeTapped, isTrue);
    });

    testWidgets('renders failure result screen for duplicate check-in', (tester) async {
      const duplicateResult = CheckinResult(
        isSuccess: false,
        message: 'Vé này đã được check-in trước đó (Quét trùng)',
        errorCode: 'duplicate_checkin',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CheckinResultScreen(result: duplicateResult),
        ),
      );

      expect(find.text('Check-in Thất Bại'), findsOneWidget);
      expect(find.text('Vé Đã Quét Trùng'), findsOneWidget);
      expect(find.text('Thử quét lại'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    });

    testWidgets('renders failure result screen for wrong event QR', (tester) async {
      const wrongEventResult = CheckinResult(
        isSuccess: false,
        message: 'Mã vé không thuộc sự kiện này! (Vé thuộc sự kiện khác)',
        errorCode: 'wrong_event',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CheckinResultScreen(result: wrongEventResult),
        ),
      );

      expect(find.text('Check-in Thất Bại'), findsOneWidget);
      expect(find.text('Vé Nhầm Sự Kiện'), findsOneWidget);
    });

    testWidgets('renders failure result screen for invalid QR code', (tester) async {
      const invalidQrResult = CheckinResult(
        isSuccess: false,
        message: 'Mã QR không đúng định dạng của CampusHub hoặc đã bị biến đổi.',
        errorCode: 'invalid_qr',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CheckinResultScreen(result: invalidQrResult),
        ),
      );

      expect(find.text('Check-in Thất Bại'), findsOneWidget);
      expect(find.text('Mã QR Không Hợp Lệ'), findsOneWidget);
    });

    testWidgets('renders failure result screen for permission denied', (tester) async {
      const permissionResult = CheckinResult(
        isSuccess: false,
        message: 'Bạn không có quyền check-in sự kiện này.',
        errorCode: 'permission_denied',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CheckinResultScreen(result: permissionResult),
        ),
      );

      expect(find.text('Check-in Thất Bại'), findsOneWidget);
      expect(find.text('Từ Chối Quyền Truy Cập'), findsOneWidget);
    });
  });
}
