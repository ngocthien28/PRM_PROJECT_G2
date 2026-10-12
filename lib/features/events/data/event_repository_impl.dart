import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../shared/enums/event_status.dart';
import 'event_repository.dart';
import 'models/event_filter.dart';
import 'models/event_model.dart';

class EventRepositoryImpl implements EventRepository {
  EventRepositoryImpl({required this.firestore, DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final FirebaseFirestore firestore;
  final DateTime Function() _now;

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw const AppException(
            'Loading events took too long. Check your connection and try again.',
            code: 'event-timeout',
          );
        },
      );
    } on FirebaseException catch (error, stack) {
      if (error.code == 'failed-precondition') {
        throw AppException(
          'The event service is not ready yet. Please try again later.',
          code: error.code,
          cause: error,
        );
      }
      throw mapError(error, stack);
    } on FormatException catch (error) {
      throw AppException(
        'An event contains invalid information. Please contact the organizer.',
        code: 'invalid-event',
        cause: error,
      );
    } on TypeError catch (error) {
      throw AppException(
        'An event contains invalid information. Please contact the organizer.',
        code: 'invalid-event',
        cause: error,
      );
    }
  }

  @override
  Future<List<EventModel>> getUpcomingEvents({
    EventFilter? filter,
    bool forceRefresh = false,
  }) => _request(() async {
    final selection = filter ?? const EventFilter();
    Query<Map<String, dynamic>> query = firestore
        .collection(FirestoreCollections.events)
        .where('status', isEqualTo: EventStatus.published.name)
        .where(
          'startAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_now().toUtc()),
        );
    if (selection.category != null) {
      query = query.where('category', isEqualTo: selection.category);
    }
    // Server reads in iteration 1; explicit SQLite fallback comes in iteration 2.
    final snapshot = await query
        .orderBy('startAt')
        .get(const GetOptions(source: Source.server));
    return selection.apply(snapshot.docs.map(EventModel.fromFirestore));
  });
}
