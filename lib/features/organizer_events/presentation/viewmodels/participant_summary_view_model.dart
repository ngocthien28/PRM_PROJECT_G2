import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/presentation/viewmodels/event_list_view_model.dart';
import '../../../registration/data/models/registration_model.dart';

/// State representation for the Event Participants Summary screen.
class ParticipantSummaryState {
  ParticipantSummaryState({
    required this.event,
    required List<RegistrationModel> participants,
  }) : participants = _deduplicate(participants);

  final EventModel event;
  final List<RegistrationModel> participants;

  static List<RegistrationModel> _deduplicate(List<RegistrationModel> list) {
    final seen = <String>{};
    return list.where((p) {
      final key = p.id.isNotEmpty ? p.id : '${p.eventId}_${p.userId}';
      return seen.add(key);
    }).toList();
  }

  int get registeredCount =>
      event.registeredCount < 0 ? 0 : event.registeredCount;

  int get checkedInCount {
    final count = event.checkedInCount < 0 ? 0 : event.checkedInCount;
    return count > registeredCount ? registeredCount : count;
  }

  /// Number of registered participants who have not yet checked in.
  int get notYetCheckedInCount =>
      (registeredCount - checkedInCount).clamp(0, registeredCount);

  /// Check-in / attendance rate calculated as (checkedIn / registered) * 100%.
  /// Safely returns 0.0 when there are no registered participants.
  double get attendanceRate =>
      registeredCount > 0 ? (checkedInCount / registeredCount) * 100.0 : 0.0;

  double get checkInRate => attendanceRate;
}

/// Server-backed participant summary provider for a given [eventId].
///
/// Enforces role and ownership authorization:
/// - Only active organizers or admins can query participants.
/// - Non-admin organizers can only query events they own.
final participantSummaryProvider = FutureProvider.autoDispose
    .family<ParticipantSummaryState, String>((ref, eventId) async {
      final actor =
          ref.watch(currentUserProvider).asData?.value ??
          await ref.watch(currentUserProvider.future);
      if (actor == null || !actor.isActive || !actor.role.canOrganize) {
        throw const AppException(
          'Only active organizers or admins can view event participants.',
          code: 'event-forbidden',
        );
      }

      final eventRepository = ref.watch(eventRepositoryProvider);
      final registrationRepository = ref.watch(registrationRepositoryProvider);

      final event = await eventRepository.getEventById(eventId, actor: actor);

      if (actor.role != UserRole.admin && event.organizerId != actor.uid) {
        throw const AppException(
          'You can only view participants for events you manage.',
          code: 'event-forbidden',
        );
      }

      final participants = await registrationRepository.getEventParticipants(
        eventId,
      );

      return ParticipantSummaryState(event: event, participants: participants);
    }, retry: (_, _) => null);
