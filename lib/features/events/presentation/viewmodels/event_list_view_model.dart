import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../data/event_repository.dart';
import '../../data/event_repository_impl.dart';
import '../../data/models/event_model.dart';

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepositoryImpl(firestore: ref.watch(firestoreProvider)),
);

final homeEventsProvider = FutureProvider.autoDispose<List<EventModel>>((
  ref,
) async {
  final identity = await ref.watch(authStateProvider.future);
  if (!ref.mounted || identity == null) return [];
  return ref.watch(eventRepositoryProvider).getUpcomingEvents();
});
