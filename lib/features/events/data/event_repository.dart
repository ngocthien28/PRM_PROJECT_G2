import '../../auth/data/models/app_user.dart';
import '../../organizer_events/data/models/event_form_input.dart';
import '../../organizer_events/data/models/organizer_dashboard_summary.dart';
import 'event_read_repository.dart';
import 'models/event_model.dart';

export 'event_read_repository.dart';

/// Shared event discovery and organizer mutation contract.
///
/// Read/search operations are declared in [EventReadRepository] (UC-016);
/// this interface adds the organizer/admin management operations.
abstract interface class EventRepository implements EventReadRepository {
  Future<List<EventModel>> getManagedEvents({required AppUser actor});

  /// Full owner-scoped totals and bounded previews; never a single list page.
  /// Admins also see only their own events here, unlike system management.
  Future<OrganizerDashboardSummary> getOrganizerDashboard({
    required AppUser actor,
    required DateTime asOf,
  });
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
