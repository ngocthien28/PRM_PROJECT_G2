import '../../auth/data/models/app_user.dart';
import 'models/event_filter.dart';
import 'models/event_model.dart';

/// UC-016: Read/search contract for Event Discovery (shared with M3 review).
///
/// Every screen that only *reads* events (Home, Discover, Event Detail,
/// Favorites, Recently viewed) depends on this interface instead of the full
/// [EventRepository] so organizer mutation APIs are not exposed to them.
///
/// Implementations must:
/// * only return `published` events to students (unless [getEventById] is
///   called with a verified manager [AppUser]);
/// * return dates in UTC;
/// * throw `AppException` with a user-readable message on failure.
abstract interface class EventReadRepository {
  /// Upcoming published events ordered by start time. Only `category` is
  /// applied server-side; the remaining [EventFilter] options are applied on
  /// the fetched list so typing in search never triggers another query.
  Future<List<EventModel>> getUpcomingEvents({
    EventFilter? filter,
    bool forceRefresh = false,
  });

  /// Without [actor], preserves published-only Student discovery behavior.
  /// Manager reads are restricted to owner/admin, including unpublished events.
  /// Authenticated ticket holders can also read their finished/cancelled events.
  Future<EventModel> getEventById(String eventId, {AppUser? actor});

  /// Keyword + filter search over upcoming published events. The keyword is
  /// matched against title, location and category (case-insensitive).
  Future<List<EventModel>> searchEvents(EventFilter filter);

  /// Resolves many events by id (e.g. favorites, recently viewed). Missing or
  /// inaccessible ids are skipped; the result keeps the order of [eventIds].
  Future<List<EventModel>> getEventsByIds(List<String> eventIds);

  /// UC-085: Retrieves events related to [eventId], matching [category],
  /// excluding [eventId].
  Future<List<EventModel>> getRelatedEvents({
    required String eventId,
    required String category,
    int limit = 5,
  });
}
