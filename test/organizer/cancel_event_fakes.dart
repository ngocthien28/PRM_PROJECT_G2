import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/events/data/models/event_filter.dart';
import 'package:campushub/shared/enums/event_status.dart';
import '../events/event_fakes.dart';

class CancelEventsFake extends FakeEvents {
  int cancelRequests = 0;
  Object? cancelFailure;
  Future<void>? cancelGate;
  final cancelledIds = <String>[];
  @override
  Future<List<EventModel>> getUpcomingEvents({
    EventFilter? filter,
    bool forceRefresh = false,
  }) async => (await super.getUpcomingEvents(
    filter: filter,
    forceRefresh: forceRefresh,
  )).where((event) => event.status == EventStatus.published).toList();
  @override
  Future<EventModel> cancelEvent({
    required String eventId,
    required AppUser actor,
  }) async {
    cancelRequests++;
    cancelledIds.add(eventId);
    if (cancelGate != null) await cancelGate;
    if (cancelFailure != null) throw cancelFailure!;
    return super.cancelEvent(eventId: eventId, actor: actor);
  }
}
