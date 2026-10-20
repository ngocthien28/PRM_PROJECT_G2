import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/registration/data/models/registration_model.dart';
import 'package:campushub/features/registration/presentation/screens/ticket_screen.dart';
import 'package:campushub/features/registration/presentation/widgets/registration_status_chip.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  group('TicketScreen Checked-In Verification Test', () {
    testWidgets(
      'displays "Đã check-in" for Autonomous Robotics & IoT Showcase 2026',
      (tester) async {
        final sampleEvent = EventModel(
          id: 'demo_event_past_robotics_symposium_06',
          organizerId: 'demo_organizer_01',
          title: 'Autonomous Robotics & IoT Showcase 2026',
          description: 'Demo past event description',
          category: 'technology',
          locationName: 'Hall B, Building Alpha',
          startAt: DateTime.utc(2026, 10, 15, 9, 0),
          endAt: DateTime.utc(2026, 10, 15, 17, 0),
          capacity: 40,
          registeredCount: 1,
          checkedInCount: 1,
          status: EventStatus.finished,
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        );

        final checkedInRegistration = RegistrationModel(
          id: 'demo_event_past_robotics_symposium_06_demo_student_01',
          eventId: 'demo_event_past_robotics_symposium_06',
          userId: 'demo_student_01',
          status: RegistrationStatus.checkedIn,
          qrToken: 'qr_token_past_robotics_06_student_01',
          registeredAt: DateTime.utc(2026, 10, 10, 8, 30),
          checkedInAt: DateTime.utc(2026, 10, 15, 9, 15),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: TicketScreen(
                registrationId: checkedInRegistration.id,
                initialRegistration: checkedInRegistration,
                initialEvent: sampleEvent,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify Event Title
        expect(find.text('Autonomous Robotics & IoT Showcase 2026'), findsOneWidget);

        // 2. Verify Status Chip displays "Đã check-in" with check circle icon
        expect(find.text('Đã check-in'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

        // 3. Verify Location
        expect(find.text('Hall B, Building Alpha'), findsOneWidget);

        // 4. Verify Ticket ID is shown
        expect(
          find.text('Mã vé: demo_event_past_robotics_symposium_06_demo_student_01'),
          findsOneWidget,
        );

        // 5. Verify Cancel button is not rendered because ticket is checked-in
        expect(find.text('Hủy vé đăng ký'), findsNothing);
      },
    );
  });
}
