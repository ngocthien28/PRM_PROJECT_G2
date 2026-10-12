import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/models/app_user.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/data/event_repository.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/presentation/viewmodels/event_list_view_model.dart';
import '../../data/models/event_form_input.dart';

/// The organizer's server-backed event list. The dashboard that consumes this
/// provider is intentionally a later task; keeping it here makes the CRUD
/// operations share the same repository and authenticated profile.
final organizerEventsProvider =
    FutureProvider.autoDispose<List<EventModel>>((ref) async {
      final actor = await ref.watch(currentUserProvider.future);
      if (actor == null || !actor.isActive || !actor.role.canOrganize) {
        return const [];
      }
      return ref.watch(eventRepositoryProvider).getManagedEvents(actor: actor);
    });

/// Thin presentation-layer entry point for organizer mutations.
///
/// Form validation and the in-flight submission lock remain in
/// [EventFormSubmissionController]. This type only obtains the active profile,
/// calls the shared repository, and refreshes dependent event lists after a
/// successful mutation.
final organizerEventActionsProvider = Provider<OrganizerEventActions>((ref) {
  return OrganizerEventActions(
    repository: ref.watch(eventRepositoryProvider),
    currentActor: () => ref.read(currentUserProvider).asData?.value,
    refresh: () {
      ref.invalidate(organizerEventsProvider);
      ref.invalidate(eventListProvider);
      ref.invalidate(homeEventsProvider);
    },
  );
});

class OrganizerEventActions {
  const OrganizerEventActions({
    required EventRepository repository,
    required AppUser? Function() currentActor,
    required void Function() refresh,
  }) : _repository = repository,
       _currentActor = currentActor,
       _refresh = refresh;

  final EventRepository _repository;
  final AppUser? Function() _currentActor;
  final void Function() _refresh;

  Future<void> createEvent(EventFormInput input) async {
    await _repository.createEvent(input: input, actor: _requireActor());
    _refresh();
  }

  Future<void> updateEvent(String eventId, EventFormInput input) async {
    await _repository.updateEvent(
      eventId: eventId,
      input: input,
      actor: _requireActor(),
    );
    _refresh();
  }

  Future<void> cancelEvent(String eventId) async {
    await _repository.cancelEvent(eventId: eventId, actor: _requireActor());
    _refresh();
  }

  AppUser _requireActor() {
    final actor = _currentActor();
    if (actor == null) {
      throw StateError('Your session is no longer available. Please sign in again.');
    }
    return actor;
  }
}
