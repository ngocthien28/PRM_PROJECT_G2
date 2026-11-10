import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../../local/dao/ticket_dao.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/presentation/screens/event_detail_screen.dart';
import '../../../events/presentation/viewmodels/event_list_view_model.dart';
import '../../../favorites/presentation/viewmodels/favorite_view_model.dart';
import '../../data/models/registration_model.dart';
import '../../../events/presentation/viewmodels/event_detail_view_model.dart';
import '../../../organizer_events/presentation/viewmodels/participant_summary_view_model.dart';

/// Provider for list of registrations belonging to the currently logged in student.
final myRegistrationsProvider =
    AsyncNotifierProvider<MyRegistrationsViewModel, List<RegistrationModel>>(
      MyRegistrationsViewModel.new,
    );

class MyRegistrationsViewModel extends AsyncNotifier<List<RegistrationModel>> {
  @override
  Future<List<RegistrationModel>> build() async {
    final identity = await ref.watch(authStateProvider.future);
    if (identity == null) return const [];

    final repo = ref.watch(registrationRepositoryProvider);
    // The repository handles network-only fallback; permission and data errors
    // must reach the error UI instead of being disguised as an empty list.
    return repo.getMyRegistrations(identity.uid);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

/// Checks whether the current user is registered for a given [eventId].
final eventRegistrationStatusProvider =
    FutureProvider.family<RegistrationModel?, String>((ref, eventId) async {
      final identity = await ref.watch(authStateProvider.future);
      if (identity == null) return null;

      final repo = ref.watch(registrationRepositoryProvider);
      return repo.getRegistration(eventId, identity.uid);
    });

/// Action notifier to handle joining or cancelling event registrations.
final registrationActionProvider =
    NotifierProvider<
      RegistrationActionViewModel,
      AsyncValue<RegistrationModel?>
    >(RegistrationActionViewModel.new);

class RegistrationActionViewModel
    extends Notifier<AsyncValue<RegistrationModel?>> {
  @override
  AsyncValue<RegistrationModel?> build() => const AsyncData(null);

  Future<RegistrationModel> joinEvent(EventModel event) async {
    final identity = ref.read(authStateProvider).asData?.value;
    if (identity == null) {
      throw const AppException('Vui lòng đăng nhập để đăng ký sự kiện');
    }

    state = const AsyncLoading();
    try {
      final repo = ref.read(registrationRepositoryProvider);
      final ticketDao = ref.read(ticketDaoProvider);

      final registration = await repo.joinEvent(
        eventId: event.id,
        userId: identity.uid,
      );

      // Cache ticket immediately for offline access
      try {
        await ticketDao.saveTicket(
          registration: registration,
          eventTitle: event.title,
          startAt: event.startAt,
        );
      } catch (_) {
        // Joining already succeeded on the server. Do not invite a retry.
      }

      state = AsyncData(registration);

      // Refresh list and event states across all modules (Home, List, Detail, Related, Favorites, Organizer)
      ref.invalidate(myRegistrationsProvider);
      ref.invalidate(eventRegistrationStatusProvider(event.id));
      ref.invalidate(homeEventsProvider);
      ref.invalidate(eventListProvider);
      ref.invalidate(eventDetailProvider(event.id));
      ref.invalidate(relatedEventsProvider);
      ref.invalidate(favoriteEventsProvider);
      ref.invalidate(recentlyViewedEventsProvider);
      ref.invalidate(participantSummaryProvider(event.id));

      return registration;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  Future<void> cancelRegistration({
    required String registrationId,
    required String eventId,
  }) async {
    final identity = ref.read(authStateProvider).asData?.value;
    if (identity == null) {
      throw const AppException('Vui lòng đăng nhập');
    }

    state = const AsyncLoading();
    try {
      final repo = ref.read(registrationRepositoryProvider);
      final ticketDao = ref.read(ticketDaoProvider);
      await repo.cancelRegistration(
        registrationId: registrationId,
        userId: identity.uid,
      );
      try {
        await ticketDao.deleteTicket(registrationId);
      } catch (_) {
        // Refresh below reconciles the confirmed cancellation from the server.
      }

      state = const AsyncData(null);

      // Refresh lists across all modules (Home, List, Detail, Related, Favorites, Organizer)
      ref.invalidate(myRegistrationsProvider);
      ref.invalidate(eventRegistrationStatusProvider(eventId));
      ref.invalidate(homeEventsProvider);
      ref.invalidate(eventListProvider);
      ref.invalidate(eventDetailProvider(eventId));
      ref.invalidate(relatedEventsProvider);
      ref.invalidate(favoriteEventsProvider);
      ref.invalidate(recentlyViewedEventsProvider);
      ref.invalidate(participantSummaryProvider(eventId));
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }
}
