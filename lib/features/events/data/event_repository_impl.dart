import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_mapper.dart';
import '../../auth/data/models/app_user.dart';
import '../../organizer_events/data/models/event_form_input.dart';
import '../../organizer_events/data/event_poster_service.dart';
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
    this.posterService,
  }) : _now = now ?? DateTime.now;
  final FirebaseFirestore firestore;
  final DateTime Function() _now;
  final Duration requestTimeout;
  final EventPosterService? posterService;

  /// Production injects a fresh Firebase identity/profile resolver. Isolated
  /// repository tests may supply their trusted actor directly without Firebase.
  final Future<AppUser?> Function()? authenticatedActor;
  final Map<String, _EventCreateAttempt> _createAttempts = {};
  final _cancelAttempts = <(String, String), Future<EventModel>>{};
  final _posterAttempts =
      <(String, String, EventPosterSelection), _PosterAttempt>{};

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
          final detailsKey = jsonEncode([
            actor.uid,
            input.title.trim(),
            input.description.trim(),
            input.category.trim(),
            input.locationName.trim(),
            input.startAt.microsecondsSinceEpoch,
            input.endAt.microsecondsSinceEpoch,
            input.capacity,
          ]);
          final key = input.createRequestId == null
              ? detailsKey
              : jsonEncode([actor.uid, input.createRequestId]);
          final existing = _createAttempts[key];
          _requireValidInput(input, requireFutureStart: existing == null);
          if (input.posterSelection != null) {
            await EventPosterValidator.validate(input.posterSelection!);
            _requirePosterService();
          }
          final attempt =
              existing ??
              _EventCreateAttempt(
                firestore.collection(FirestoreCollections.events).doc(),
                _createMap(input, actor.uid),
                detailsKey,
              );
          _createAttempts[key] = attempt;
          try {
            final event = await attempt.confirm();
            if (input.posterSelection != null) {
              if (identical(attempt.posterSelection, input.posterSelection) &&
                  attempt.posterUrl != null &&
                  attempt.posterUrl == event.posterUrl) {
                return _sameEditableValues(event, input)
                    ? event
                    : await _commitUpdate(
                        event.id,
                        input,
                        actor,
                        posterUrl: event.posterUrl,
                      );
              }
              attempt.posterSelection = input.posterSelection;
              final saved = await _savePoster(event, input, actor);
              attempt.posterUrl = saved.posterUrl;
              return saved;
            }
            if (attempt.detailsKey != detailsKey) {
              return await updateEvent(
                eventId: event.id,
                input: input,
                actor: actor,
              );
            }
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
        if (input.posterSelection != null) {
          _posterAttempts.remove((actor.uid, event.id, input.posterSelection!));
        }
        return event;
      });

  @override
  Future<EventModel> updateEvent({
    required String eventId,
    required EventFormInput input,
    required AppUser actor,
    DateTime? expectedUpdatedAt,
  }) =>
      _request(() async {
        actor = await _verifiedActor(actor);
        _requireEventManager(actor);
        _requireValidInput(input);
        if (input.posterSelection != null) {
          await EventPosterValidator.validate(input.posterSelection!);
          _requirePosterService();
          final snapshot = await _eventDocument(
            eventId,
          ).get(const GetOptions(source: Source.server));
          if (!snapshot.exists) {
            throw const AppException(
              'This event is unavailable.',
              code: 'event-not-found',
            );
          }
          final event = EventModel.fromFirestore(snapshot);
          _requireOwnerOrAdmin(event, actor);
          return _savePoster(
            event,
            input,
            actor,
            expectedUpdatedAt: expectedUpdatedAt,
          );
        }
        return _commitUpdate(
          eventId,
          input,
          actor,
          expectedUpdatedAt: expectedUpdatedAt,
        );
      }).then((event) {
        if (input.posterSelection != null) {
          _posterAttempts.remove((actor.uid, event.id, input.posterSelection!));
        }
        return event;
      });

  Future<EventModel> _commitUpdate(
    String eventId,
    EventFormInput input,
    AppUser actor, {
    DateTime? expectedUpdatedAt,
    String? posterUrl,
    void Function()? onPosterAttached,
  }) async {
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
      if (posterUrl != null && existing.posterUrl == posterUrl) {
        onPosterAttached?.call();
      }
      // Confirm a previous commit whose response was lost, without writing
      // again or treating our own timestamp as a competing edit.
      if (posterUrl != null &&
          existing.posterUrl == posterUrl &&
          _sameEditableValues(existing, input)) {
        return;
      }
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
      final updates = _editableMap(input);
      if (posterUrl != null) updates['posterUrl'] = posterUrl;
      transaction.update(ref, updates);
    }, timeout: requestTimeout);
    onPosterAttached?.call();
    return EventModel.fromFirestore(
      await ref.get(const GetOptions(source: Source.server)),
    );
  }

  EventPosterService _requirePosterService() =>
      posterService ??
      (throw const AppException(
        'Poster upload is unavailable. Please try again.',
        code: 'poster-unavailable',
      ));

  bool _sameEditableValues(EventModel event, EventFormInput input) =>
      event.title == input.title.trim() &&
      event.description == input.description.trim() &&
      event.category == input.category.trim() &&
      event.locationName == input.locationName.trim() &&
      event.capacity == input.capacity &&
      event.startAt.isAtSameMomentAs(input.startAt) &&
      event.endAt.isAtSameMomentAs(input.endAt);

  Future<EventModel> _savePoster(
    EventModel event,
    EventFormInput input,
    AppUser actor, {
    DateTime? expectedUpdatedAt,
  }) async {
    final selection = input.posterSelection!;
    final key = (actor.uid, event.id, selection);
    final attempt = _posterAttempts.putIfAbsent(key, _PosterAttempt.new);
    if (attempt.pending != null) {
      final result = await attempt.pending!;
      if (!_sameEditableValues(result, input)) {
        throw const AppException(
          'The previous save finished with different details. Reload the latest event before saving again.',
          code: 'event-edit-conflict',
        );
      }
      return result;
    }
    final operation = () async {
      _requireOwnerOrAdmin(event, actor);
      if (event.status == EventStatus.cancelled) {
        throw const AppException(
          'Cancelled events cannot be updated.',
          code: 'event-cancelled',
        );
      }
      if (input.capacity < event.registeredCount) {
        throw AppException(
          'Capacity must be at least ${event.registeredCount}, the current number of registered participants.',
          code: 'event-capacity-below-registered',
        );
      }
      // Preflight before uploading, then recheck inside the transaction.
      // A retained upload may be confirmation of our own earlier commit.
      if (attempt.upload == null &&
          expectedUpdatedAt != null &&
          !event.updatedAt.isAtSameMomentAs(expectedUpdatedAt)) {
        throw const AppException(
          'This event changed while you were editing. Reload the latest event before saving again.',
          code: 'event-edit-conflict',
        );
      }
      final service = _requirePosterService();
      try {
        attempt.upload ??= await service.upload(event.id, selection);
        final result = await _commitUpdate(
          event.id,
          input,
          actor,
          expectedUpdatedAt: expectedUpdatedAt,
          posterUrl: attempt.upload!.url,
          onPosterAttached: () => attempt.attached = true,
        );
        // Evict only when the outer caller confirms success. A caller may have
        // timed out while this operation continued; its retry must reuse this URL.
        return result;
      } catch (error) {
        final code = error is FirebaseException
            ? error.code
            : error is AppException
            ? error.code
            : '';
        // Delete only after a definite rejection. Timeouts/unavailable responses
        // can hide a committed transaction; retain its URL to confirm on retry.
        if (!attempt.attached &&
            {
              'permission-denied',
              'unauthenticated',
              'invalid-argument',
              'event-edit-conflict',
              'event-forbidden',
              'event-cancelled',
              'event-capacity-below-registered',
              'event-not-found',
            }.contains(code)) {
          final upload = attempt.upload;
          if (upload != null) {
            try {
              await service.delete(upload);
            } catch (_) {}
          }
          _posterAttempts.remove(key);
        }
        rethrow;
      }
    }();
    attempt.pending = operation;
    try {
      return await operation;
    } finally {
      attempt.pending = null;
    }
  }

  @override
  Future<EventModel> cancelEvent({
    required String eventId,
    required AppUser actor,
  }) => _request(() async {
    actor = await _verifiedActor(actor);
    _requireEventManager(actor);
    final ref = _eventDocument(eventId);
    final key = (actor.uid, ref.id);
    final pending = _cancelAttempts[key];
    if (pending != null) return pending;
    // A caller timeout does not cancel a native transaction. Retry joins the
    // original attempt until it settles, rather than starting another write.
    final attempt = _cancelEvent(ref, actor);
    _cancelAttempts[key] = attempt;
    unawaited(
      attempt.then<void>(
        (_) => _cancelAttempts.remove(key),
        onError: (Object _, StackTrace _) {
          _cancelAttempts.remove(key);
        },
      ),
    );
    return attempt;
  });

  Future<EventModel> _cancelEvent(
    DocumentReference<Map<String, dynamic>> ref,
    AppUser actor,
  ) async {
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
  }

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
  _EventCreateAttempt(
    this.reference,
    Map<String, dynamic> data,
    this.detailsKey,
  ) {
    _write = reference.set(data).then((_) => writeAcknowledged = true);
  }

  final DocumentReference<Map<String, dynamic>> reference;
  final String detailsKey;
  EventPosterSelection? posterSelection;
  String? posterUrl;
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

class _PosterAttempt {
  bool attached = false;
  UploadedEventPoster? upload;
  Future<EventModel>? pending;
}
