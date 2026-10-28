import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../../local/dao/event_cache_dao.dart';
import '../../data/event_repository.dart';
import '../../data/event_repository_impl.dart';
import '../../data/models/event_filter.dart';
import '../../data/models/event_model.dart';
import '../../../organizer_events/presentation/viewmodels/event_poster_view_model.dart';

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepositoryImpl(
    firestore: ref.watch(firestoreProvider),
    authenticatedActor: ref.watch(authenticatedActorProvider),
    posterService: ref.watch(eventPosterServiceProvider),
    eventCacheDao: ref.watch(eventCacheDaoProvider),
  ),
);

/// UC-016: Read-only contract provider for student discovery screens.
final eventReadRepositoryProvider = Provider<EventReadRepository>(
  (ref) => ref.watch(eventRepositoryProvider),
);

final eventFilterProvider = NotifierProvider<EventFilterViewModel, EventFilter>(
  EventFilterViewModel.new,
);

class EventFilterViewModel extends Notifier<EventFilter> {
  @override
  EventFilter build() {
    ref.watch(authStateProvider.select((state) => state.asData?.value?.uid));
    return const EventFilter();
  }

  void setFilter(EventFilter filter) => state = filter;
  void setKeyword(String value) => state = state.withKeyword(value);
  void setSort(EventSort sort) => state = state.withSort(sort);
  void reset() => state = const EventFilter();
}

final eventListProvider =
    AsyncNotifierProvider.autoDispose<EventListViewModel, List<EventModel>>(
      EventListViewModel.new,
    );

class EventListViewModel extends AsyncNotifier<List<EventModel>> {
  @override
  Future<List<EventModel>> build() async {
    // Typing searches the fetched results; only a category change refetches.
    final category = ref.watch(
      eventFilterProvider.select((filter) => filter.category),
    );
    final identity = await ref.watch(authStateProvider.future);
    if (!ref.mounted || identity == null) return [];
    return ref
        .watch(eventRepositoryProvider)
        .getUpcomingEvents(filter: EventFilter(category: category));
  }
}

final filteredEventsProvider =
    Provider.autoDispose<AsyncValue<List<EventModel>>>((ref) {
      final filter = ref.watch(eventFilterProvider);
      return ref.watch(eventListProvider).whenData(filter.apply);
    });

final homeEventsProvider = FutureProvider.autoDispose<List<EventModel>>((
  ref,
) async {
  final identity = await ref.watch(authStateProvider.future);
  if (!ref.mounted || identity == null) return [];
  return ref.watch(eventRepositoryProvider).getUpcomingEvents();
});
