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
import 'organizer_dashboard_view_model.dart';
export 'participant_summary_view_model.dart';

/// The bounded server-backed management list. Dashboard totals use their own
/// full-data summary provider so this list's page limit cannot truncate KPIs.
/// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
/// MODULE: Testing & Integration
/// DESCRIPTION: Chỉ tải danh sách quản lý cho actor active có canOrganize; user khác nhận danh sách rỗng.
/// ROLE: Cross-module role/access integration
/// CALLED FROM: ManageEventsScreen.
/// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod.
final organizerEventsProvider = FutureProvider.autoDispose<List<EventModel>>((
  ref,
) async {
  final actor = await ref.watch(currentUserProvider.future);
  if (actor == null || !actor.isActive || !actor.role.canOrganize) {
    return const [];
  }
  return ref.watch(eventRepositoryProvider).getManagedEvents(actor: actor);
});

/// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
/// MODULE: Testing & Integration
/// DESCRIPTION: Theo dõi UID/role/status và chặn quyền sai trước khi đọc event chỉnh sửa.
/// ROLE: Cross-module role/access integration
/// CALLED FROM: OrganizerEditEventScreen.
/// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod.
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
/// [EventFormSubmissionController]. Cancellation coalesces requests per
/// actor/event and bounds waiting time. All successful mutations refresh the
/// existing dependent event providers.
final organizerEventActionsProvider = Provider<OrganizerEventActions>((ref) {
  return OrganizerEventActions(
    repository: ref.watch(eventRepositoryProvider),
    // The route can render before the profile stream has emitted a synchronous
    // value. Await it here instead of treating that brief state as a lost
    // session.
    currentActor: () => ref.read(currentUserProvider.future),
    refresh: () {
      if (!ref.mounted) return;
      ref.invalidate(organizerDashboardProvider);
      ref.invalidate(organizerEventsProvider);
      ref.invalidate(eventListProvider);
      ref.invalidate(homeEventsProvider);
    },
    refreshEvent: (id) {
      if (!ref.mounted) return;
      ref.invalidate(eventDetailProvider(id));
      ref.invalidate(managedEventDetailProvider(id));
    },
  );
});

class OrganizerEventActions {
  OrganizerEventActions({
    required EventRepository repository,
    required FutureOr<AppUser?> Function() currentActor,
    required void Function() refresh,
    this.refreshEvent,
    this.cancelTimeout = const Duration(seconds: 20),
  }) : _repository = repository,
       _currentActor = currentActor,
       _refresh = refresh;

  final EventRepository _repository;
  final FutureOr<AppUser?> Function() _currentActor;
  final void Function() _refresh;
  final void Function(String)? refreshEvent;
  final Duration cancelTimeout;
  final _cancellations = <(String, String), Future<void>>{};

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
    final actor = await _requireActor().timeout(
      cancelTimeout,
      onTimeout: _cancelTimedOut,
    );
    final key = (actor.uid, eventId.trim());
    final pending = _cancellations.putIfAbsent(key, () {
      final attempt = () async {
        await _repository.cancelEvent(eventId: eventId, actor: actor);
        _refresh();
        refreshEvent?.call(eventId);
      }();
      unawaited(
        attempt.then<void>(
          (_) {
            _cancellations.remove(key);
          },
          onError: (Object _, StackTrace _) {
            _cancellations.remove(key);
          },
        ),
      );
      return attempt;
    });
    await pending.timeout(cancelTimeout, onTimeout: _cancelTimedOut);
  }

  Never _cancelTimedOut() => throw const AppException(
    'Cancellation could not be confirmed yet. Check your connection and retry.',
    code: 'event-cancel-timeout',
  );

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
