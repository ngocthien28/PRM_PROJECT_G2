import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_mapper.dart';
import '../../auth/data/models/app_user.dart';
import '../../organizer_events/data/models/event_form_input.dart';
import '../../organizer_events/data/models/organizer_dashboard_summary.dart';
import '../../../shared/enums/event_status.dart';
import '../../../shared/enums/user_role.dart';
import 'event_repository.dart';
import 'models/event_filter.dart';
import 'models/event_model.dart';

class EventRepositoryImpl implements EventRepository {
  EventRepositoryImpl({
    required this.firestore,
    DateTime Function()? now,
    this.requestTimeout = const Duration(seconds: 20),
    this.authenticatedActor,
  }) : _now = now ?? DateTime.now;
  final FirebaseFirestore firestore;
  final DateTime Function() _now;
  final Duration requestTimeout;

  /// Production injects a fresh Firebase identity/profile resolver. Isolated
  /// repository tests may supply their trusted actor directly without Firebase.
  final Future<AppUser?> Function()? authenticatedActor;
  final Map<String, _EventCreateAttempt> _createAttempts = {};

  Future<T> _request<T>(
    Future<T> Function() action, {
    String? timeoutMessage,
  }) async {
    try {
      return await action().timeout(
        requestTimeout,
        onTimeout: () {
          throw AppException(
            timeoutMessage ??
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
  Future<EventModel> getEventById(
    String eventId, {
    AppUser? actor,
  }) => _request(() async {
    if (eventId.trim().isEmpty || eventId.contains('/')) {
      throw const AppException(
        'This event is unavailable.',
        code: 'event-not-found',
      );
    }
    final supplied = actor;
    final manager = supplied == null ? null : await _verifiedActor(supplied);
    if (manager != null) _requireEventManager(manager);
    // Ticket holders have get-only access to their event history. A query
    // (even by document ID) uses list rules and cannot use that permission.
    final snapshot = await firestore
        .collection(FirestoreCollections.events)
        .doc(eventId)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) {
      throw const AppException(
        'This event is unavailable or you do not have access to it.',
        code: 'event-not-found',
      );
    }
    final event = EventModel.fromFirestore(snapshot);
    if (manager != null) {
      if (manager.role != UserRole.admin && event.organizerId != manager.uid) {
        throw const AppException(
          'This event is unavailable or you do not have access to it.',
          code: 'event-not-found',
        );
      }
    } else if (event.status != EventStatus.published) {
      final participant = await authenticatedActor?.call();
      final registration =
          participant == null ||
              !participant.isActive ||
              event.status == EventStatus.draft
          ? null
          : await firestore
                .collection('registrations')
                .doc('${eventId}_${participant.uid}')
                .get(const GetOptions(source: Source.server));
      final data = registration?.data();
      if (data == null ||
          data['userId'] != participant?.uid ||
          data['eventId'] != eventId) {
        throw const AppException(
          'This event is unavailable or you do not have access to it.',
          code: 'event-not-found',
        );
      }
    }
    return event;
  });

  @override
  Future<List<EventModel>> getManagedEvents({required AppUser actor}) =>
      _request(() async {
        actor = await _verifiedActor(actor);
        _requireEventManager(actor);
        Query<Map<String, dynamic>> query = firestore.collection(
          FirestoreCollections.events,
        );
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
  Future<OrganizerDashboardSummary> getOrganizerDashboard({
    required AppUser actor,
    required DateTime asOf,
  }) => _request(() async {
    actor = await _verifiedActor(actor);
    _requireEventManager(actor);
    final summary = OrganizerDashboardAccumulator(
      organizerId: actor.uid,
      asOf: asOf,
    );
    // Reuses the owner/startAt index from UC-034. Each request is bounded;
    // all pages contribute to KPIs, while only 5 upcoming / 3 recent cards
    // are retained. Registration documents are never queried.
    const pageSize = 100;
    final query = firestore
        .collection(FirestoreCollections.events)
        .where('organizerId', isEqualTo: actor.uid)
        .orderBy('startAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      final page =
          await (cursor == null ? query : query.startAfterDocument(cursor))
              .limit(pageSize)
              .get(const GetOptions(source: Source.server));
      for (final document in page.docs) {
        summary.add(EventModel.fromFirestore(document));
      }
      if (page.docs.length < pageSize) break;
      cursor = page.docs.last;
    }
    return summary.finish();
  });

  @override
  Future<EventModel> createEvent({
    required EventFormInput input,
    required AppUser actor,
  }) =>
      _request(
        () async {
          actor = await _verifiedActor(actor);
          _requireEventManager(actor);
          // Keep the original write alive across a timeout. Retrying unchanged data
          // confirms that write instead of allocating a second document or resetting
          // server timestamps/counters. This protection lasts for this repository
          // instance; it is not cross-device/restart idempotency.
          final key = jsonEncode([
            actor.uid,
            input.title.trim(),
            input.description.trim(),
            input.category.trim(),
            input.locationName.trim(),
            input.startAt.microsecondsSinceEpoch,
            input.endAt.microsecondsSinceEpoch,
            input.capacity,
          ]);
          final existing = _createAttempts[key];
          _requireValidInput(input, requireFutureStart: existing == null);
          final attempt =
              existing ??
              _EventCreateAttempt(
                firestore.collection(FirestoreCollections.events).doc(),
                _createMap(input, actor.uid),
              );
          _createAttempts[key] = attempt;
          try {
            final event = await attempt.confirm();
            // A timed-out caller must not evict a write which completed later.
            // Eviction happens in the successful outer request below.
            return event;
          } on FirebaseException catch (error) {
            // These errors explicitly reject the write. Read-back failures retain
            // the acknowledged write so retry never creates another document.
            if (!attempt.writeAcknowledged &&
                {
                  'permission-denied',
                  'unauthenticated',
                  'invalid-argument',
                }.contains(error.code)) {
              if (identical(_createAttempts[key], attempt)) {
                _createAttempts.remove(key);
              }
            }
            rethrow;
          }
        },
        timeoutMessage:
            'Saving could not be confirmed yet. Keep these details and retry to check the same event.',
      ).then((event) {
        _createAttempts.removeWhere(
          (_, attempt) => attempt.reference.id == event.id,
        );
        return event;
      });

  @override
  Future<EventModel> updateEvent({
    required String eventId,
    required EventFormInput input,
    required AppUser actor,
    DateTime? expectedUpdatedAt,
  }) => _request(() async {
    actor = await _verifiedActor(actor);
    _requireEventManager(actor);
    _requireValidInput(input);
    final ref = _eventDocument(eventId);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw const AppException(
          'This event is unavailable.',
          code: 'event-not-found',
        );
      }
      final existing = EventModel.fromFirestore(snapshot);
      _requireOwnerOrAdmin(existing, actor);
      if (existing.status == EventStatus.cancelled) {
        throw const AppException(
          'Cancelled events cannot be updated.',
          code: 'event-cancelled',
        );
      }
      if (input.capacity < existing.registeredCount) {
        throw AppException(
          'Capacity must be at least ${existing.registeredCount}, the current number of registered participants.',
          code: 'event-capacity-below-registered',
        );
      }
      if (expectedUpdatedAt != null &&
          !existing.updatedAt.isAtSameMomentAs(expectedUpdatedAt)) {
        throw const AppException(
          'This event changed while you were editing. Reload the latest event before saving again.',
          code: 'event-edit-conflict',
        );
      }
      // Read and validate the current counters/version on every transaction
      // retry. Never write protected fields or another member's metadata.
      transaction.update(ref, _editableMap(input));
    }, timeout: requestTimeout);
    return EventModel.fromFirestore(
      await ref.get(const GetOptions(source: Source.server)),
    );
  });

  @override
  Future<EventModel> cancelEvent({
    required String eventId,
    required AppUser actor,
  }) => _request(() async {
    actor = await _verifiedActor(actor);
    _requireEventManager(actor);
    final ref = _eventDocument(eventId);
    await firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) {
        throw const AppException(
          'This event is unavailable.',
          code: 'event-not-found',
        );
      }
      final existing = EventModel.fromFirestore(snapshot);
      _requireOwnerOrAdmin(existing, actor);
      if (existing.status == EventStatus.cancelled) return;
      tx.update(ref, {
        'status': EventStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }, timeout: requestTimeout);
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

  Future<AppUser> _verifiedActor(AppUser supplied) async {
    final resolver = authenticatedActor;
    if (resolver == null) return supplied;
    final actual = await resolver();
    if (actual == null || actual.uid != supplied.uid) {
      throw const AppException(
        'Your session is no longer valid. Please sign in again.',
        code: 'unauthenticated',
      );
    }
    return actual;
  }

  void _requireEventManager(AppUser actor) {
    if (actor.uid.trim().isEmpty ||
        !actor.isActive ||
        !actor.role.canOrganize) {
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
      throw AppException(errors.values.first, code: 'invalid-event-input');
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

class _EventCreateAttempt {
  _EventCreateAttempt(this.reference, Map<String, dynamic> data) {
    _write = reference.set(data).then((_) => writeAcknowledged = true);
  }

  final DocumentReference<Map<String, dynamic>> reference;
  late final Future<void> _write;
  bool writeAcknowledged = false;

  Future<EventModel> confirm() async {
    await _write;
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (!snapshot.exists) {
      throw const AppException(
        'The event could not be confirmed. Retry with the same details to check again.',
        code: 'event-create-unconfirmed',
      );
    }
    return EventModel.fromFirestore(snapshot);
  }
}
