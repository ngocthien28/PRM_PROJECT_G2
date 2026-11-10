import '../../events/data/models/event_model.dart';

/// Contract cho tính năng Favorites (UC-025, UC-026).
abstract interface class FavoriteRepository {
  /// Thêm hoặc xóa sự kiện khỏi danh sách yêu thích trên Firestore.
  /// Tự động đồng bộ trạng thái local SQLite.
  Future<void> toggleFavorite({
    required String userId,
    required String eventId,
    required bool isFavorite,
  });

  /// Xóa sự kiện khỏi danh sách yêu thích trên Firestore và đồng bộ local SQLite (UC-082).
  Future<void> removeFavorite({
    required String userId,
    required String eventId,
  });

  /// Xóa toàn bộ sự kiện khỏi danh sách yêu thích của người dùng (UC-086).
  Future<void> clearAllFavorites(String userId);

  /// Kiểm tra xem event có trong danh sách yêu thích không (Firestore + local).
  Future<bool> isFavorite({required String userId, required String eventId});

  /// Lấy danh sách sự kiện yêu thích đầy đủ của user từ Firestore.
  Future<List<EventModel>> getFavoriteEvents(String userId);

  /// Stream theo dõi real-time danh sách eventId yêu thích.
  Stream<List<String>> watchFavoriteIds(String userId);
}
