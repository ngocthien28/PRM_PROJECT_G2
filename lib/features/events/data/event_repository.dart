import '../../auth/data/models/app_user.dart';
import '../../organizer_events/data/models/event_form_input.dart';
import 'models/event_filter.dart';
import 'models/event_model.dart';

/// Shared event discovery and organizer mutation contract.
abstract interface class EventRepository {
  Future<List<EventModel>> getUpcomingEvents({
    EventFilter? filter,
    bool forceRefresh = false,
  });

  /// Without [actor], preserves published-only Student discovery behavior.
  /// Manager reads are restricted to owner/admin, including unpublished events.
  Future<EventModel> getEventById(String eventId, {AppUser? actor});
  Future<List<EventModel>> getManagedEvents({required AppUser actor});
  Future<EventModel> createEvent({
    required EventFormInput input,
    required AppUser actor,
  });
  Future<EventModel> updateEvent({
    required String eventId,
    required EventFormInput input,
    required AppUser actor,
    DateTime? expectedUpdatedAt,
  });
  Future<EventModel> cancelEvent({
    required String eventId,
    required AppUser actor,
  });
}
