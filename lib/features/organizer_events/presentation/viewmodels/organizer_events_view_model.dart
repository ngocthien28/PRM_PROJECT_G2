// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';

import '../../../auth/data/models/app_user.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/data/event_repository.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/presentation/viewmodels/event_list_view_model.dart';
import '../../../events/presentation/viewmodels/event_detail_view_model.dart';
import '../../../../shared/enums/event_status.dart';
import '../../data/models/event_form_input.dart';
export 'participant_summary_view_model.dart';

/// The organizer's server-backed event list. The dashboard that consumes this
/// provider is intentionally a later task; keeping it here makes the CRUD
/// operations share the same repository and authenticated profile.
final organizerEventsProvider = FutureProvider.autoDispose<List<EventModel>>((
  ref,
) async {
  final actor = await ref.watch(currentUserProvider.future);
  if (actor == null || !actor.isActive || !actor.role.canOrganize) {
    return const [];
  }
  return ref.watch(eventRepositoryProvider).getManagedEvents(actor: actor);
});

final organizerEditEventProvider = FutureProvider.autoDispose
    .family<EventModel, String>((ref, eventId) async {
      // Profile data unrelated to authorization must not reset a dirty edit form.
      ref.watch(
        currentUserProvider.select((value) {
          final user = value.asData?.value;
          return (user?.uid, user?.role, user?.isActive);
        }),
      );
      final repository = ref.watch(eventRepositoryProvider);
      final actor = await ref
          .read(currentUserProvider.future)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw const AppException(
              'Your session could not be loaded. Please try again.',
              code: 'session-timeout',
            ),
          );
      if (!ref.mounted) {
        throw const AppException(
          'This edit session has ended.',
          code: 'session-ended',
        );
      }
      if (actor == null || !actor.isActive || !actor.role.canOrganize) {
        throw const AppException(
          'Only active organizers or admins can edit events.',
          code: 'event-forbidden',
        );
      }
      final event = await repository.getEventById(eventId, actor: actor);
      if (event.status == EventStatus.cancelled) {
        throw const AppException(
          'Cancelled events cannot be updated.',
          code: 'event-cancelled',
        );
      }
      return event;
    }, retry: (_, _) => null);

/// Thin presentation-layer entry point for organizer mutations.
///
/// Form validation and the in-flight submission lock remain in
/// [EventFormSubmissionController]. This type only obtains the active profile,
/// calls the shared repository, and refreshes dependent event lists after a
/// successful mutation.
final organizerEventActionsProvider = Provider<OrganizerEventActions>((ref) {
  return OrganizerEventActions(
    repository: ref.watch(eventRepositoryProvider),
    // The route can render before the profile stream has emitted a synchronous
    // value. Await it here instead of treating that brief state as a lost
    // session.
    currentActor: () => ref.read(currentUserProvider.future),
    refresh: () {
      ref.invalidate(organizerEventsProvider);
      ref.invalidate(eventListProvider);
      ref.invalidate(homeEventsProvider);
    },
    refreshEvent: (id) {
      ref.invalidate(eventDetailProvider(id));
      ref.invalidate(managedEventDetailProvider(id));
    },
  );
});

class OrganizerEventActions {
  const OrganizerEventActions({
    required EventRepository repository,
    required FutureOr<AppUser?> Function() currentActor,
    required void Function() refresh,
    this.refreshEvent,
  })  : _repository = repository,
        _currentActor = currentActor,
        _refresh = refresh;

  final EventRepository _repository;
  final FutureOr<AppUser?> Function() _currentActor;
  final void Function() _refresh;
  final void Function(String)? refreshEvent;

  Future<void> createEvent(EventFormInput input) async {
    await _repository.createEvent(input: input, actor: await _requireActor());
    _refresh();
  }

  Future<void> updateEvent(
    String eventId,
    EventFormInput input, {
    DateTime? expectedUpdatedAt,
  }) async {
    await _repository.updateEvent(
      eventId: eventId,
      input: input,
      actor: await _requireActor(),
      expectedUpdatedAt: expectedUpdatedAt,
    );
    _refresh();
    refreshEvent?.call(eventId);
  }

  Future<void> cancelEvent(String eventId) async {
    await _repository.cancelEvent(
      eventId: eventId,
      actor: await _requireActor(),
    );
    _refresh();
    refreshEvent?.call(eventId);
  }

  Future<AppUser> _requireActor() async {
    final actor = await _currentActor();
    if (actor == null) {
      throw const AppException(
        'Your session is no longer available. Please sign in again.',
        code: 'unauthenticated',
      );
    }
    return actor;
  }
}
