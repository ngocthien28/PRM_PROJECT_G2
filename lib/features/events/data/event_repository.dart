import 'models/event_filter.dart';
import 'models/event_model.dart';

/// Discovery reads. Organizer mutations belong to the organizer module.
abstract interface class EventRepository {
  Future<List<EventModel>> getUpcomingEvents({
    EventFilter? filter,
    bool forceRefresh = false,
  });
}
