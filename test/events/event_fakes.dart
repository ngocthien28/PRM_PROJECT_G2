import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/events/data/event_repository.dart';
import 'package:campushub/features/events/data/models/event_filter.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/shared/enums/event_status.dart';

EventModel testEvent({
  String id = 'event-1',
  String organizerId = 'organizer-1',
  String title = 'Flutter Workshop',
  String category = 'technology',
  EventStatus status = EventStatus.published,
  DateTime? startAt,
  int capacity = 100,
  int registeredCount = 20,
  int checkedInCount = 0,
  String? posterUrl,
}) => EventModel(
  id: id,
  organizerId: organizerId,
  title: title,
  description:
      'Learn Flutter with fellow students through a hands-on campus workshop.',
  category: category,
  locationName: 'Hall A',
  startAt: startAt ?? DateTime.utc(2030, 5, 20, 9),
  endAt: (startAt ?? DateTime.utc(2030, 5, 20, 9)).add(
    const Duration(hours: 2),
  ),
  capacity: capacity,
  registeredCount: registeredCount,
  checkedInCount: checkedInCount,
  status: status,
  createdAt: DateTime.utc(2030),
  updatedAt: DateTime.utc(2030),
  posterUrl: posterUrl,
);

class FakeEvents implements EventRepository {
  FakeEvents([List<EventModel>? initial]) : events = initial ?? [testEvent()];
  List<EventModel> events;
  Object? failure;
  Future<void>? pending;
  int reads = 0;
  int mutations = 0;
  final categories = <String?>[];

  @override
  Future<List<EventModel>> getUpcomingEvents({
    EventFilter? filter,
    bool forceRefresh = false,
  }) async {
    reads++;
    categories.add(filter?.category);
    if (pending != null) await pending;
    if (failure != null) throw failure!;
    return (filter ?? const EventFilter()).apply(events);
  }

  @override
  Future<EventModel> getEventById(String eventId, {AppUser? actor}) async {
    if (failure != null) throw failure!;
    if (actor != null) return _ownedEvent(eventId, actor);
    final matching = events.where((event) => event.id == eventId);
    if (matching.isEmpty) {
      throw const AppException(
        'This event is unavailable.',
        code: 'event-not-found',
      );
    }
    return matching.first;
  }

  @override
  Future<EventModel> cancelEvent({
    required String eventId,
    required AppUser actor,
  }) async {
    final existing = _ownedEvent(eventId, actor);
    if (existing.status == EventStatus.cancelled) return existing;
    final updated = _copy(existing, status: EventStatus.cancelled);
    _replace(updated);
    mutations++;
    return updated;
  }

  @override
  Future<EventModel> createEvent({
    required EventFormInput input,
    required AppUser actor,
  }) async {
    _requireManager(actor);
    final errors = input.validate();
    if (errors.isNotEmpty) {
      throw AppException(errors.values.first, code: 'invalid-event-input');
    }
    final now = DateTime.now().toUtc();
    final event = EventModel(
      id: 'event-${events.length + 1}',
      organizerId: actor.uid,
      title: input.title.trim(),
      description: input.description.trim(),
      category: input.category.trim(),
      locationName: input.locationName.trim(),
      startAt: input.startAt.toUtc(),
      endAt: input.endAt.toUtc(),
      capacity: input.capacity,
      registeredCount: 0,
      checkedInCount: 0,
      status: EventStatus.published,
      createdAt: now,
      updatedAt: now,
    );
    events = [...events, event];
    mutations++;
    return event;
  }

  @override
  Future<List<EventModel>> getManagedEvents({required AppUser actor}) =>
      Future.value(
        actor.role.name == 'admin'
            ? events
            : events.where((event) => event.organizerId == actor.uid).toList(),
      );

  @override
  Future<EventModel> updateEvent({
    required String eventId,
    required EventFormInput input,
    required AppUser actor,
    DateTime? expectedUpdatedAt,
  }) async {
    final existing = _ownedEvent(eventId, actor);
    if (existing.status == EventStatus.cancelled) {
      throw const AppException(
        'Cancelled events cannot be updated.',
        code: 'event-cancelled',
      );
    }
    final errors = input.validate();
    if (errors.isNotEmpty) {
      throw AppException(errors.values.first, code: 'invalid-event-input');
    }
    final updated = _copy(
      existing,
      title: input.title.trim(),
      description: input.description.trim(),
      category: input.category.trim(),
      locationName: input.locationName.trim(),
      startAt: input.startAt.toUtc(),
      endAt: input.endAt.toUtc(),
      capacity: input.capacity,
    );
    _replace(updated);
    mutations++;
    return updated;
  }

  EventModel _ownedEvent(String eventId, AppUser actor) {
    _requireManager(actor);
    final event = events.where((event) => event.id == eventId).firstOrNull;
    if (event == null) {
      throw const AppException(
        'This event is unavailable.',
        code: 'event-not-found',
      );
    }
    if (actor.role.name != 'admin' && event.organizerId != actor.uid) {
      throw const AppException(
        'You can only manage events you own.',
        code: 'event-forbidden',
      );
    }
    return event;
  }

  void _requireManager(AppUser actor) {
    if (!actor.isActive || !actor.role.canOrganize) {
      throw const AppException(
        'Only active organizers or admins can manage events.',
        code: 'event-forbidden',
      );
    }
  }

  EventModel _copy(
    EventModel event, {
    String? title,
    String? description,
    String? category,
    String? locationName,
    DateTime? startAt,
    DateTime? endAt,
    int? capacity,
    EventStatus? status,
  }) => EventModel(
    id: event.id,
    organizerId: event.organizerId,
    title: title ?? event.title,
    description: description ?? event.description,
    category: category ?? event.category,
    locationName: locationName ?? event.locationName,
    startAt: startAt ?? event.startAt,
    endAt: endAt ?? event.endAt,
    capacity: capacity ?? event.capacity,
    registeredCount: event.registeredCount,
    checkedInCount: event.checkedInCount,
    status: status ?? event.status,
    createdAt: event.createdAt,
    updatedAt: DateTime.now().toUtc(),
    clubId: event.clubId,
    posterUrl: event.posterUrl,
    latitude: event.latitude,
    longitude: event.longitude,
  );

  void _replace(EventModel updated) {
    events = [
      for (final event in events)
        if (event.id == updated.id) updated else event,
    ];
  }
}
