import 'package:campushub/features/registration/presentation/widgets/registration_status_chip.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegistrationStatusChip Widget Tests', () {
    testWidgets('renders active registered status correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RegistrationStatusChip(status: RegistrationStatus.registered),
          ),
        ),
      );

      expect(find.text('Đã đăng ký'), findsOneWidget);
      expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);
    });

    testWidgets('renders checked-in status correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RegistrationStatusChip(status: RegistrationStatus.checkedIn),
          ),
        ),
      );

      expect(find.text('Đã check-in'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('renders cancelled status correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RegistrationStatusChip(status: RegistrationStatus.cancelled),
          ),
        ),
      );

      expect(find.text('Đã hủy'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    });
  });
}
