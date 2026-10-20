import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../local/dao/favorite_local_dao.dart';
import '../../events/data/models/event_model.dart';
import 'favorite_repository.dart';

/// Firestore collection path: users/{userId}/favorites/{eventId}
/// Document chỉ lưu: { eventId, addedAt }
class FavoriteRepositoryImpl implements FavoriteRepository {
  FavoriteRepositoryImpl({
    required this.firestore,
    required this.localDao,
  });

  final FirebaseFirestore firestore;
  final FavoriteLocalDao localDao;

  CollectionReference<Map<String, dynamic>> _favCol(String userId) =>
      firestore.collection('users').doc(userId).collection('favorites');

  @override
  Future<void> toggleFavorite({
    required String userId,
    required String eventId,
    required bool isFavorite,
  }) async {
    // 1. Cập nhật Firestore
    final docRef = _favCol(userId).doc(eventId);
    if (isFavorite) {
      await docRef.set({
        'eventId': eventId,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.delete();
    }
    // 2. Đồng bộ local SQLite
    await localDao.setFavorite(
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
    // Ưu tiên local cache để phản hồi nhanh
    final local = await localDao.isFavorite(
      eventId: eventId,
      userId: userId,
    );
    return local;
  }

  @override
  Future<List<EventModel>> getFavoriteEvents(String userId) async {
    final snapshot = await _favCol(userId).get();
    if (snapshot.docs.isEmpty) return [];

    final eventIds = snapshot.docs.map((d) => d.id).toList();

    // Lấy events từ Firestore (batch by 10 do Firestore whereIn limit)
    final results = <EventModel>[];
    for (int i = 0; i < eventIds.length; i += 10) {
      final chunk = eventIds.sublist(
        i,
        i + 10 > eventIds.length ? eventIds.length : i + 10,
      );
      final eventsSnap = await firestore
          .collection('events')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in eventsSnap.docs) {
        try {
          results.add(EventModel.fromFirestore(doc));
        } catch (_) {
          // Skip malformed events
        }
      }
    }
    // Sắp xếp theo thời gian thêm vào favorites (mới nhất trước)
    results.sort((a, b) => b.startAt.compareTo(a.startAt));
    return results;
  }

  @override
  Stream<List<String>> watchFavoriteIds(String userId) {
    return _favCol(userId).snapshots().map(
          (snapshot) => snapshot.docs.map((d) => d.id).toList(),
        );
  }
}
