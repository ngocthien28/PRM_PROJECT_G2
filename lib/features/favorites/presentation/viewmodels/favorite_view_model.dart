import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../../local/dao/favorite_local_dao.dart';
import '../../../../local/dao/recent_view_dao.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/presentation/viewmodels/event_list_view_model.dart';
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
  Future<void> removeFavorite({
    required String userId,
    required String eventId,
  }) async {
    await _localDao.setFavorite(
      eventId: eventId,
      userId: userId,
      isFavorite: false,
    );
  }

  @override
  Future<void> clearAllFavorites(String userId) async {
    await _localDao.clearForUser(userId);
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
      ref.invalidate(favoriteEventsProvider);
      state = const FavoriteToggleState();
    } catch (e) {
      state = FavoriteToggleState(error: 'Lỗi: $e');
    }
  }

  /// Xóa trực tiếp khỏi favorites (UC-082)
  Future<void> remove() async {
    if (state.isLoading) return;

    final identity = ref.read(authStateProvider).asData?.value;
    if (identity == null) {
      state = const FavoriteToggleState(error: 'Vui lòng đăng nhập lại.');
      return;
    }

    state = const FavoriteToggleState(isLoading: true);

    try {
      await ref.read(favoriteRepositoryProvider).removeFavorite(
        userId: identity.uid,
        eventId: eventId,
      );
      ref.invalidate(favoriteIdsProvider);
      ref.invalidate(favoriteEventsProvider);
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
    return await ref
        .watch(favoriteRepositoryProvider)
        .getFavoriteEvents(identity.uid);
  } catch (_) {
    return [];
  }
});

// ── UC-086: Provider lấy danh sách sự kiện đã xem gần đây ──────────────────

final recentlyViewedEventsProvider =
    FutureProvider.autoDispose<List<EventModel>>((ref) async {
  try {
    final identity = await ref.watch(authStateProvider.future);
    if (!ref.mounted || identity == null) return [];

    final dao = ref.watch(recentViewDaoProvider);
    final eventIds = await dao.getRecentlyViewedEventIds(userId: identity.uid);
    if (eventIds.isEmpty) return [];

    final eventRepo = ref.watch(eventReadRepositoryProvider);
    final events = await eventRepo.getEventsByIds(eventIds);
    final eventMap = {for (final e in events) e.id: e};

    // Duy trì đúng thứ tự đã xem gần nhất
    return [
      for (final id in eventIds)
        if (eventMap.containsKey(id)) eventMap[id]!,
    ];
  } catch (_) {
    return [];
  }
});

