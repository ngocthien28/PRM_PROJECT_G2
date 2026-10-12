import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';

/// Test-only roles for exercising organizer authorization before the shared
/// UserRole contract and Firebase Auth are available.
enum FakeOrganizerActorRole { student, organizer, admin }

/// Test-only authenticated actor. This is not the shared AppUser model.
class FakeOrganizerActor {
  const FakeOrganizerActor({
    required this.actorId,
    required this.actorRole,
  });

  final String actorId;
  final FakeOrganizerActorRole actorRole;
}

/// Test-only event lifecycle used by the in-memory fake repository.
enum FakeOrganizerEventStatus { published, cancelled }

/// Test-only stored record. It must not be used as the shared EventModel.
class FakeOrganizerEvent {
  const FakeOrganizerEvent({
    required this.id,
    required this.organizerId,
    required this.input,
    required this.status,
  });

  final String id;
  final String organizerId;
  final EventFormInput input;
  final FakeOrganizerEventStatus status;

  FakeOrganizerEvent copyWith({
    EventFormInput? input,
    FakeOrganizerEventStatus? status,
  }) {
    return FakeOrganizerEvent(
      id: id,
      organizerId: organizerId,
      input: input ?? this.input,
      status: status ?? this.status,
    );
  }
}

/// Test-only in-memory CRUD behavior for the organizer flow.
///
/// This deliberately does not implement the shared EventRepository contract.
/// It exists only until the shared model, repository, Firebase, and auth
/// contracts are available.
class FakeOrganizerEventRepository {
  final Map<String, FakeOrganizerEvent> _events = {};
  int _nextId = 1;

  Future<FakeOrganizerEvent> create({
    required EventFormInput input,
    required FakeOrganizerActor actor,
  }) async {
    _requireOrganizerOrAdmin(actor);
    _requireValidInput(input);

    final event = FakeOrganizerEvent(
      id: 'fake-event-${_nextId++}',
      organizerId: actor.actorId,
      input: input,
      status: FakeOrganizerEventStatus.published,
    );
    _events[event.id] = event;
    return event;
  }

  Future<List<FakeOrganizerEvent>> getManagedEvents(
    FakeOrganizerActor actor,
  ) async {
    _requireOrganizerOrAdmin(actor);
    return _events.values
        .where((event) => event.organizerId == actor.actorId)
        .toList(growable: false);
  }

  Future<FakeOrganizerEvent> update({
    required String eventId,
    required EventFormInput input,
    required FakeOrganizerActor actor,
  }) async {
    _requireOrganizerOrAdmin(actor);
    _requireValidInput(input);

    final existing = _eventOrThrow(eventId);
    _requireOwnerOrAdmin(existing, actor);
    if (existing.status == FakeOrganizerEventStatus.cancelled) {
      throw StateError('Cancelled events cannot be republished by update.');
    }

    final updated = existing.copyWith(input: input);
    _events[eventId] = updated;
    return updated;
  }

  Future<FakeOrganizerEvent> cancel({
    required String eventId,
    required FakeOrganizerActor actor,
  }) async {
    _requireOrganizerOrAdmin(actor);

    final existing = _eventOrThrow(eventId);
    _requireOwnerOrAdmin(existing, actor);
    final cancelled = existing.copyWith(
      status: FakeOrganizerEventStatus.cancelled,
    );
    _events[eventId] = cancelled;
    return cancelled;
  }

  FakeOrganizerEvent _eventOrThrow(String eventId) {
    final event = _events[eventId];
    if (event == null) {
      throw StateError('Event $eventId does not exist.');
    }
    return event;
  }

  void _requireOrganizerOrAdmin(FakeOrganizerActor actor) {
    if (actor.actorRole != FakeOrganizerActorRole.organizer &&
        actor.actorRole != FakeOrganizerActorRole.admin) {
      throw const FakeOrganizerAuthorizationException(
        'Only organizers and admins can manage events.',
      );
    }
  }

  void _requireOwnerOrAdmin(
    FakeOrganizerEvent event,
    FakeOrganizerActor actor,
  ) {
    final isAdmin = actor.actorRole == FakeOrganizerActorRole.admin;
    if (!isAdmin && event.organizerId != actor.actorId) {
      throw const FakeOrganizerAuthorizationException(
        'Only the event owner or an admin can manage this event.',
      );
    }
  }

  void _requireValidInput(EventFormInput input) {
    final errors = input.validate();
    if (errors.isNotEmpty) {
      throw ArgumentError.value(input, 'input', errors.values.join(' '));
    }
  }
}

class FakeOrganizerAuthorizationException implements Exception {
  const FakeOrganizerAuthorizationException(this.message);

  final String message;

  @override
  String toString() => message;
}
