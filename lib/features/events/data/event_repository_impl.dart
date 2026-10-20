import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_mapper.dart';
import '../../auth/data/models/app_user.dart';
import '../../organizer_events/data/models/event_form_input.dart';
import '../../../shared/enums/event_status.dart';
import '../../../shared/enums/user_role.dart';
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

  @override
  Future<EventModel> getEventById(String eventId) => _request(() async {
    if (eventId.trim().isEmpty || eventId.contains('/')) {
      throw const AppException(
        'This event is unavailable.',
        code: 'event-not-found',
      );
    }
    // Status-constrained query also satisfies published-only rules for missing
    // or unpublished IDs without leaking the underlying document.
    final snapshot = await firestore
        .collection(FirestoreCollections.events)
        .where(FieldPath.documentId, isEqualTo: eventId)
        .where('status', isEqualTo: EventStatus.published.name)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (snapshot.docs.isEmpty) {
      throw const AppException(
        'This event is unavailable or is no longer published.',
        code: 'event-not-found',
      );
    }
    return EventModel.fromFirestore(snapshot.docs.single);
  });

  @override
  Future<List<EventModel>> getManagedEvents({required AppUser actor}) =>
      _request(() async {
        _requireEventManager(actor);
        Query<Map<String, dynamic>> query =
            firestore.collection(FirestoreCollections.events);
        if (actor.role != UserRole.admin) {
          query = query.where('organizerId', isEqualTo: actor.uid);
        }
        final snapshot = await query
            .orderBy('startAt', descending: true)
            .limit(100)
            .get(const GetOptions(source: Source.server));
        return snapshot.docs.map(EventModel.fromFirestore).toList();
      });

  @override
  Future<EventModel> createEvent({
    required EventFormInput input,
    required AppUser actor,
  }) => _request(() async {
    _requireEventManager(actor);
    _requireValidInput(input, requireFutureStart: true);
    final ref = firestore.collection(FirestoreCollections.events).doc();
    await ref.set(_createMap(input, actor.uid));
    final snapshot = await ref.get(const GetOptions(source: Source.server));
    return EventModel.fromFirestore(snapshot);
  });

  @override
  Future<EventModel> updateEvent({
    required String eventId,
    required EventFormInput input,
    required AppUser actor,
  }) => _request(() async {
    _requireEventManager(actor);
    _requireValidInput(input);
    final ref = _eventDocument(eventId);
    final existing = await _loadEvent(ref);
    _requireOwnerOrAdmin(existing, actor);
    if (existing.status == EventStatus.cancelled) {
      throw const AppException(
        'Cancelled events cannot be updated.',
        code: 'event-cancelled',
      );
    }
    await ref.update(_editableMap(input));
    return EventModel.fromFirestore(
      await ref.get(const GetOptions(source: Source.server)),
    );
  });

  @override
  Future<EventModel> cancelEvent({
    required String eventId,
    required AppUser actor,
  }) => _request(() async {
    _requireEventManager(actor);
    final ref = _eventDocument(eventId);
    final existing = await _loadEvent(ref);
    _requireOwnerOrAdmin(existing, actor);
    if (existing.status == EventStatus.cancelled) return existing;
    await ref.update({
      'status': EventStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return EventModel.fromFirestore(
      await ref.get(const GetOptions(source: Source.server)),
    );
  });

  DocumentReference<Map<String, dynamic>> _eventDocument(String eventId) {
    final id = eventId.trim();
    if (id.isEmpty || id.contains('/')) {
      throw const AppException(
        'This event is unavailable.',
        code: 'event-not-found',
      );
    }
    return firestore.collection(FirestoreCollections.events).doc(id);
  }

  Future<EventModel> _loadEvent(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final snapshot = await ref.get(const GetOptions(source: Source.server));
    if (!snapshot.exists) {
      throw const AppException(
        'This event is unavailable.',
        code: 'event-not-found',
      );
    }
    return EventModel.fromFirestore(snapshot);
  }

  void _requireEventManager(AppUser actor) {
    if (!actor.isActive || !actor.role.canOrganize) {
      throw const AppException(
        'Only active organizers or admins can manage events.',
        code: 'event-forbidden',
      );
    }
  }

  void _requireOwnerOrAdmin(EventModel event, AppUser actor) {
    if (actor.role != UserRole.admin && event.organizerId != actor.uid) {
      throw const AppException(
        'You can only manage events you own.',
        code: 'event-forbidden',
      );
    }
  }

  void _requireValidInput(
    EventFormInput input, {
    bool requireFutureStart = false,
  }) {
    final errors = input.validate(
      requireFutureStart: requireFutureStart,
      now: _now(),
    );
    if (errors.isNotEmpty) {
      throw AppException(
        errors.values.first,
        code: 'invalid-event-input',
      );
    }
  }

  Map<String, dynamic> _createMap(EventFormInput input, String organizerId) => {
    ..._editableValues(input),
    'organizerId': organizerId,
    'clubId': null,
    'latitude': null,
    'longitude': null,
    'registeredCount': 0,
    'checkedInCount': 0,
    'posterUrl': null,
    'status': EventStatus.published.name,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> _editableMap(EventFormInput input) => {
    ..._editableValues(input),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> _editableValues(EventFormInput input) => {
    'title': input.title.trim(),
    'titleLower': input.title.trim().toLowerCase(),
    'description': input.description.trim(),
    'category': input.category.trim(),
    'locationName': input.locationName.trim(),
    'startAt': Timestamp.fromDate(input.startAt.toUtc()),
    'endAt': Timestamp.fromDate(input.endAt.toUtc()),
    'capacity': input.capacity,
  };
}
