import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../../local/dao/favorite_local_dao.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/data/models/event_model.dart';
import '../../data/favorite_repository.dart';
import '../../data/favorite_repository_impl.dart';

// ── Fallback repository for test environments without Firebase ────────────────

class LocalOnlyFavoriteRepository implements FavoriteRepository {
  LocalOnlyFavoriteRepository(this._localDao);
  final FavoriteLocalDao _localDao;

  @override
  Future<void> toggleFavorite({
    required String userId,
    required String eventId,
    required bool isFavorite,
  }) async {
    await _localDao.setFavorite(
      eventId: eventId,
      userId: userId,
      isFavorite: isFavorite,
    );
  }

  @override
  Future<bool> isFavorite({
    required String userId,
    required String eventId,
  }) async {
    return _localDao.isFavorite(eventId: eventId, userId: userId);
  }

  @override
  Future<List<EventModel>> getFavoriteEvents(String userId) async => [];

  @override
  Stream<List<String>> watchFavoriteIds(String userId) {
    return Stream.value([]);
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  if (Firebase.apps.isEmpty) {
    return LocalOnlyFavoriteRepository(ref.watch(favoriteLocalDaoProvider));
  }
  return FavoriteRepositoryImpl(
    firestore: ref.watch(firestoreProvider),
    localDao: ref.watch(favoriteLocalDaoProvider),
  );
});

/// Stream theo dõi real-time danh sách eventId yêu thích của user hiện tại.
final favoriteIdsProvider = StreamProvider<List<String>>((ref) async* {
  if (Firebase.apps.isEmpty) {
    yield [];
    return;
  }
  try {
    final identity = await ref.watch(authStateProvider.future);
    if (!ref.mounted || identity == null) {
      yield [];
      return;
    }
    yield* ref
        .watch(favoriteRepositoryProvider)
        .watchFavoriteIds(identity.uid);
  } catch (_) {
    yield [];
  }
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
/// Scoped theo eventId để mỗi nút trái tim hoạt động độc lập.
class FavoriteToggleViewModel extends Notifier<FavoriteToggleState> {
  FavoriteToggleViewModel(this.eventId);

  final String eventId;

  @override
  FavoriteToggleState build() => const FavoriteToggleState();

  Future<void> toggle() async {
    if (state.isLoading) return;

    final identity = ref.read(authStateProvider).asData?.value;
    if (identity == null) {
      state = const FavoriteToggleState(error: 'Vui lòng đăng nhập lại.');
      return;
    }

    final currentlyFav = ref.read(isFavoriteProvider(eventId));
    state = const FavoriteToggleState(isLoading: true);

    try {
      await ref.read(favoriteRepositoryProvider).toggleFavorite(
        userId: identity.uid,
        eventId: eventId,
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

final favoriteToggleProvider = NotifierProvider.autoDispose
    .family<FavoriteToggleViewModel, FavoriteToggleState, String>(
  FavoriteToggleViewModel.new,
);

// ── UC-026: Provider lấy toàn bộ danh sách events yêu thích ─────────────────

final favoriteEventsProvider =
    FutureProvider.autoDispose<List<EventModel>>((ref) async {
  try {
    final identity = await ref.watch(authStateProvider.future);
    if (!ref.mounted || identity == null) return [];
    // Theo dõi thay đổi từ stream để tự reload khi có toggle
    ref.watch(favoriteIdsProvider);
    return ref
        .watch(favoriteRepositoryProvider)
        .getFavoriteEvents(identity.uid);
  } catch (_) {
    return [];
  }
});
