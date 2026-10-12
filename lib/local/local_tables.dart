/// Table and column name constants for CampusHub SQLite local storage.
abstract final class LocalTables {
  static const String cachedEvents = 'cached_events';
  static const String offlineTickets = 'offline_tickets';
  static const String recentlyViewed = 'recently_viewed';
  static const String favoriteLocal = 'favorite_local';

  // offline_tickets columns
  static const String colRegistrationId = 'registration_id';
  static const String colUserId = 'user_id';
  static const String colEventId = 'event_id';
  static const String colQrToken = 'qr_token';
  static const String colEventTitle = 'event_title';
  static const String colStartAt = 'start_at';
  static const String colUpdatedAt = 'updated_at';

  // cached_events columns
  static const String colId = 'id';
  static const String colJson = 'json';

  // favorite_local columns
  static const String colIsFavorite = 'is_favorite';

  // recently_viewed columns
  static const String colViewedAt = 'viewed_at';
}
