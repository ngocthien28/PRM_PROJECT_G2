import 'dart:async';
import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/event_form_view_model.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter_test/flutter_test.dart';
import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';
import 'event_form_view_model_test.dart' show validInput;

void main() {
  final owner = testUser(uid: 'organizer-1', role: UserRole.organizer);
  final other = testUser(uid: 'other', role: UserRole.organizer);
  final student = testUser(role: UserRole.student);
  final admin = testUser(role: UserRole.admin);
  late FakeEvents repository;
  setUp(() {
    repository = FakeEvents([])..now = () => DateTime.utc(2029);
  });

  test(
    'shared-contract fake creates, reads, edits and soft cancels with protected fields preserved',
    () async {
      final created = await repository.createEvent(
        input: validInput(),
        actor: owner,
      );
      final edited = await repository.updateEvent(
        eventId: created.id,
        input: validInput(title: 'Changed title'),
        actor: owner,
      );
      expect(edited.title, 'Changed title');
      expect(edited.organizerId, owner.uid);
      expect(edited.registeredCount, 0);
      expect(edited.checkedInCount, 0);
      final cancelled = await repository.cancelEvent(
        eventId: created.id,
        actor: owner,
      );
      expect(cancelled.status, EventStatus.cancelled);
      expect(
        (await repository.getEventById(created.id, actor: owner)).id,
        created.id,
      );
      expect(await repository.getManagedEvents(actor: owner), hasLength(1));
      await repository.cancelEvent(eventId: created.id, actor: owner);
      expect(repository.mutations, 3);
      await expectLater(
        repository.updateEvent(
          eventId: created.id,
          input: validInput(),
          actor: owner,
        ),
        throwsA(isA<AppException>()),
      );
    },
  );
  test(
    'non-owner and student cannot mutate; admin follows override policy',
    () async {
      repository.events = [testEvent()];
      for (final actor in [other, student]) {
        await expectLater(
          repository.updateEvent(
            eventId: 'event-1',
            input: validInput(),
            actor: actor,
          ),
          throwsA(isA<AppException>()),
        );
        await expectLater(
          repository.cancelEvent(eventId: 'event-1', actor: actor),
          throwsA(isA<AppException>()),
        );
        await expectLater(
          repository.getEventById('event-1', actor: actor),
          throwsA(isA<AppException>()),
        );
      }
      final edited = await repository.updateEvent(
        eventId: 'event-1',
        input: validInput(),
        actor: admin,
      );
      expect(edited.organizerId, owner.uid);
      expect(repository.mutations, 1);
    },
  );
  test(
    'edit retains poster and counters and rejects capacity below registrations',
    () async {
      repository.events = [
        testEvent(
          registeredCount: 20,
          checkedInCount: 10,
          posterUrl: 'https://fixture.test/poster.png',
        ),
      ];
      await expectLater(
        repository.updateEvent(
          eventId: 'event-1',
          input: validInput().copyWith(capacity: 19),
          actor: owner,
        ),
        throwsException,
      );
      final updated = await repository.updateEvent(
        eventId: 'event-1',
        input: validInput(),
        actor: owner,
      );
      expect(updated.registeredCount, 20);
      expect(updated.checkedInCount, 10);
      expect(updated.posterUrl, 'https://fixture.test/poster.png');
    },
  );
  test(
    'controlled async failure transitions to retry success without duplicate create',
    () async {
      final controller = EventFormSubmissionController(
        now: () => DateTime.utc(2029),
      );
      final gate = Completer<void>();
      repository.pending = gate.future;
      repository.failure = const AppException('Offline', code: 'unavailable');
      Future<void> save(input) async {
        await repository.createEvent(input: input, actor: owner);
      }

      final first = controller.submit(validInput(), save);
      expect(controller.state.isSubmitting, isTrue);
      expect(await controller.submit(validInput(), save), isFalse);
      expect(repository.createRequests, 1);
      gate.complete();
      expect(await first, isFalse);
      expect(controller.state.errorMessage, 'Offline');
      expect(repository.events, isEmpty);
      repository.pending = null;
      repository.failure = null;
      expect(await controller.submit(validInput(), save), isTrue);
      expect(repository.createRequests, 2);
      expect(repository.events, hasLength(1));
    },
  );
  test('update/cancel failure never mutates the stored event', () async {
    repository.events = [testEvent()];
    repository.failure = const AppException('Denied');
    await expectLater(
      repository.updateEvent(
        eventId: 'event-1',
        input: validInput(),
        actor: owner,
      ),
      throwsException,
    );
    await expectLater(
      repository.cancelEvent(eventId: 'event-1', actor: owner),
      throwsException,
    );
    expect(repository.events.single.status, EventStatus.published);
    expect(repository.mutations, 0);
  });
  test('invalid business input never reaches the save callback', () async {
    final controller = EventFormSubmissionController(
      now: () => DateTime.utc(2029),
    );
    expect(
      await controller.submit(validInput(title: ' '), (input) async {
        await repository.createEvent(input: input, actor: owner);
      }),
      isFalse,
    );
    expect(repository.createRequests, 0);
    expect(controller.state.validationErrors, contains('title'));
  });
}
