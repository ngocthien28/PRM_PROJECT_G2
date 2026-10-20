import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../../local/dao/favorite_local_dao.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/data/models/event_model.dart';
import '../../data/favorite_repository.dart';
import '../../data/favorite_repository_impl.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final favoriteRepositoryProvider = Provider<FavoriteRepository>(
  (ref) => FavoriteRepositoryImpl(
    firestore: ref.watch(firestoreProvider),
    localDao: ref.watch(favoriteLocalDaoProvider),
  ),
);

/// Stream theo dõi real-time danh sách eventId yêu thích của user hiện tại.
final favoriteIdsProvider = StreamProvider<List<String>>((ref) async* {
  final identity = await ref.watch(authStateProvider.future);
  if (!ref.mounted || identity == null) {
    yield [];
    return;
  }
  yield* ref
      .watch(favoriteRepositoryProvider)
      .watchFavoriteIds(identity.uid);
});

/// Kiểm tra nhanh xem một event cụ thể có trong favorites không.
final isFavoriteProvider = Provider.family<bool, String>((ref, eventId) {
  final ids = ref.watch(favoriteIdsProvider).asData?.value ?? [];
  return ids.contains(eventId);
});

// ── ViewModel ─────────────────────────────────────────────────────────────────

/// State cho mỗi thao tác toggle yêu thích (loading / error).
class FavoriteToggleState {
  const FavoriteToggleState({this.isLoading = false, this.error});
  final bool isLoading;
  final String? error;
}

/// ViewModel xử lý UC-025: Add Event to Favorites.
/// Được scoped theo eventId để mỗi nút trái tim hoạt động độc lập.
class FavoriteToggleViewModel
    extends AutoDisposeFamilyNotifier<FavoriteToggleState, String> {
  @override
  FavoriteToggleState build(String eventId) =>
      const FavoriteToggleState();

  Future<void> toggle() async {
    if (state.isLoading) return;

    final identity = ref.read(authStateProvider).asData?.value;
    if (identity == null) {
      state = const FavoriteToggleState(error: 'Vui lòng đăng nhập lại.');
      return;
    }

    final currentlyFav = ref.read(isFavoriteProvider(arg));
    state = const FavoriteToggleState(isLoading: true);

    try {
      await ref.read(favoriteRepositoryProvider).toggleFavorite(
        userId: identity.uid,
        eventId: arg,
        isFavorite: !currentlyFav,
      );
      // Invalidate stream để cập nhật real-time
      ref.invalidate(favoriteIdsProvider);
      state = const FavoriteToggleState();
    } catch (e) {
      state = FavoriteToggleState(error: 'Lỗi: $e');
    }
  }
}

final favoriteToggleProvider = NotifierProviderFamily<
    FavoriteToggleViewModel, FavoriteToggleState, String>(
  FavoriteToggleViewModel.new,
);

// ── UC-026: Provider lấy toàn bộ danh sách events yêu thích ─────────────────

final favoriteEventsProvider =
    FutureProvider.autoDispose<List<EventModel>>((ref) async {
  final identity = await ref.watch(authStateProvider.future);
  if (!ref.mounted || identity == null) return [];
  // Theo dõi thay đổi từ stream để tự reload khi có toggle
  ref.watch(favoriteIdsProvider);
  return ref
      .watch(favoriteRepositoryProvider)
      .getFavoriteEvents(identity.uid);
});
