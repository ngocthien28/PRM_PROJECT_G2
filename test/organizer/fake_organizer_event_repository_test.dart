import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_organizer_event_repository.dart';

void main() {
  const owner = FakeOrganizerActor(
    actorId: 'organizer-1',
    actorRole: FakeOrganizerActorRole.organizer,
  );
  const otherOrganizer = FakeOrganizerActor(
    actorId: 'organizer-2',
    actorRole: FakeOrganizerActorRole.organizer,
  );
  const student = FakeOrganizerActor(
    actorId: 'student-1',
    actorRole: FakeOrganizerActorRole.student,
  );
  const admin = FakeOrganizerActor(
    actorId: 'admin-1',
    actorRole: FakeOrganizerActorRole.admin,
  );

  EventFormInput validInput({String title = 'Flutter Workshop'}) {
    return EventFormInput(
      title: title,
      description: 'Learn Flutter fundamentals in this hands-on workshop.',
      category: 'technology',
      locationName: 'Hall A',
      startAt: DateTime(2030, 1, 1, 9),
      endAt: DateTime(2030, 1, 1, 11),
      capacity: 100,
    );
  }

  test('organizer creates a valid event with assigned ownership', () async {
    final repository = FakeOrganizerEventRepository();

    final event = await repository.create(input: validInput(), actor: owner);

    expect(event.id, 'fake-event-1');
    expect(event.organizerId, owner.actorId);
    expect(event.status, FakeOrganizerEventStatus.published);
  });

  test('student cannot create an event', () async {
    final repository = FakeOrganizerEventRepository();

    expect(
      () => repository.create(input: validInput(), actor: student),
      throwsA(isA<FakeOrganizerAuthorizationException>()),
    );
  });

  test('invalid EventFormInput is rejected', () async {
    final repository = FakeOrganizerEventRepository();
    final invalidInput = validInput(title: '');

    expect(
      () => repository.create(input: invalidInput, actor: owner),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('organizer can read only their own managed events', () async {
    final repository = FakeOrganizerEventRepository();
    final ownerEvent = await repository.create(input: validInput(), actor: owner);
    await repository.create(input: validInput(title: 'Dart Workshop'), actor: otherOrganizer);

    final events = await repository.getManagedEvents(owner);

    expect(events, hasLength(1));
    expect(events.single.id, ownerEvent.id);
  });

  test('organizer cannot read another organizer managed list', () async {
    final repository = FakeOrganizerEventRepository();
    final ownerEvent = await repository.create(input: validInput(), actor: owner);

    final events = await repository.getManagedEvents(otherOrganizer);

    expect(events, isEmpty);
    expect(events.map((event) => event.id), isNot(contains(ownerEvent.id)));
  });

  test('owner can update an event', () async {
    final repository = FakeOrganizerEventRepository();
    final event = await repository.create(input: validInput(), actor: owner);

    final updated = await repository.update(
      eventId: event.id,
      input: validInput(title: 'Updated Flutter Workshop'),
      actor: owner,
    );

    expect(updated.id, event.id);
    expect(updated.organizerId, owner.actorId);
    expect(updated.input.title, 'Updated Flutter Workshop');
  });

  test('non-owner organizer cannot update an event', () async {
    final repository = FakeOrganizerEventRepository();
    final event = await repository.create(input: validInput(), actor: owner);

    expect(
      () => repository.update(
        eventId: event.id,
        input: validInput(title: 'Unauthorized Update'),
        actor: otherOrganizer,
      ),
      throwsA(isA<FakeOrganizerAuthorizationException>()),
    );
  });

  test('admin can update an event', () async {
    final repository = FakeOrganizerEventRepository();
    final event = await repository.create(input: validInput(), actor: owner);

    final updated = await repository.update(
      eventId: event.id,
      input: validInput(title: 'Admin Update'),
      actor: admin,
    );

    expect(updated.input.title, 'Admin Update');
    expect(updated.organizerId, owner.actorId);
  });

  test('owner can cancel an event', () async {
    final repository = FakeOrganizerEventRepository();
    final event = await repository.create(input: validInput(), actor: owner);

    final cancelled = await repository.cancel(eventId: event.id, actor: owner);

    expect(cancelled.status, FakeOrganizerEventStatus.cancelled);
  });

  test('non-owner organizer cannot cancel an event', () async {
    final repository = FakeOrganizerEventRepository();
    final event = await repository.create(input: validInput(), actor: owner);

    expect(
      () => repository.cancel(eventId: event.id, actor: otherOrganizer),
      throwsA(isA<FakeOrganizerAuthorizationException>()),
    );
  });

  test('admin can cancel an event', () async {
    final repository = FakeOrganizerEventRepository();
    final event = await repository.create(input: validInput(), actor: owner);

    final cancelled = await repository.cancel(eventId: event.id, actor: admin);

    expect(cancelled.status, FakeOrganizerEventStatus.cancelled);
    expect(cancelled.organizerId, owner.actorId);
  });

  test('cancelled event remains stored', () async {
    final repository = FakeOrganizerEventRepository();
    final event = await repository.create(input: validInput(), actor: owner);
    await repository.cancel(eventId: event.id, actor: owner);

    final events = await repository.getManagedEvents(owner);

    expect(events, hasLength(1));
    expect(events.single.status, FakeOrganizerEventStatus.cancelled);
  });

  test('cancelled event is not hard-deleted', () async {
    final repository = FakeOrganizerEventRepository();
    final event = await repository.create(input: validInput(), actor: owner);
    await repository.cancel(eventId: event.id, actor: owner);

    final events = await repository.getManagedEvents(owner);

    expect(events.single.id, event.id);
    expect(events.single.organizerId, owner.actorId);
  });

  test('cancelled event cannot be silently republished', () async {
    final repository = FakeOrganizerEventRepository();
    final event = await repository.create(input: validInput(), actor: owner);
    await repository.cancel(eventId: event.id, actor: owner);

    expect(
      () => repository.update(
        eventId: event.id,
        input: validInput(title: 'Republished Event'),
        actor: owner,
      ),
      throwsA(isA<StateError>()),
    );

    final events = await repository.getManagedEvents(owner);
    expect(events.single.status, FakeOrganizerEventStatus.cancelled);
  });
}
