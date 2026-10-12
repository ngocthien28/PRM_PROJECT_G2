import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/events/data/event_repository.dart';
import 'package:campushub/features/events/data/models/event_filter.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/shared/enums/event_status.dart';

EventModel testEvent({
  String id = 'event-1',
  String title = 'Flutter Workshop',
  String category = 'technology',
  EventStatus status = EventStatus.published,
  DateTime? startAt,
  int capacity = 100,
  int registeredCount = 20,
  String? posterUrl,
}) => EventModel(
  id: id,
  organizerId: 'organizer-1',
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
  checkedInCount: 0,
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
  Future<EventModel> getEventById(String eventId) async {
    if (failure != null) throw failure!;
    final matching = events.where((event) => event.id == eventId);
    if (matching.isEmpty) {
      throw const AppException(
        'This event is unavailable.',
        code: 'event-not-found',
      );
    }
    return matching.first;
  }
}
