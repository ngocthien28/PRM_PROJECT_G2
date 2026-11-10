import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../local/dao/event_cache_dao.dart';
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
    this.eventCacheDao,
  }) : _now = now ?? DateTime.now;
  final FirebaseFirestore firestore;
  final DateTime Function() _now;
  final Duration requestTimeout;
  final EventPosterService? posterService;
  final EventCacheDao? eventCacheDao;

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

  bool _isOfflineOrTimeout(Object error) {
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'network-request-failed';
    }
    if (error is AppException) {
      return error.code == 'event-timeout' ||
          error.code == 'unavailable' ||
          error.code == 'network-request-failed';
    }
    return false;
  }

  @override
  Future<List<EventModel>> getUpcomingEvents({
    EventFilter? filter,
    bool forceRefresh = false,
  }) async {
    final selection = filter ?? const EventFilter();
    try {
      return await _request(() async {
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
        final snapshot = await query
            .orderBy('startAt')
            .get(const GetOptions(source: Source.server));
        final events = snapshot.docs.map(EventModel.fromFirestore).toList();
        // UC-028: Save fresh server events into SQLite cache
        unawaited(eventCacheDao?.saveEvents(events));
        return selection.apply(events);
      });
    } catch (e) {
      // UC-030: Fallback to SQLite cache on offline / network failure
      if (_isOfflineOrTimeout(e) && eventCacheDao != null) {
        final cached = await eventCacheDao!.getCachedEvents();
        if (cached.isNotEmpty) {
          final upcomingCached = cached.where((e) => e.isUpcomingAt(_now()));
          return selection.apply(upcomingCached);
        }
      }
      rethrow;
    }
  }

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Áp dụng verified actor/manager và owner/admin cho managed read; kiểm tra participant khi event không published.
  /// ROLE: Authorization call site; nghiệp vụ event ngoài phạm vi
  /// CALLED FROM: Event management providers / EventRepositoryImpl.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
  @override
  Future<EventModel> getEventById(String eventId, {AppUser? actor}) async {
    try {
      return await _request(() async {
        if (eventId.trim().isEmpty || eventId.contains('/')) {
          throw const AppException(
            'This event is unavailable.',
            code: 'event-not-found',
          );
        }
        final supplied = actor;
        final manager = supplied == null
            ? null
            : await _verifiedActor(supplied);
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
        // UC-028: Save to local cache
        unawaited(eventCacheDao?.saveEvent(event));
        if (manager != null) {
          if (manager.role != UserRole.admin &&
              event.organizerId != manager.uid) {
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
    } catch (e) {
      if (_isOfflineOrTimeout(e) && eventCacheDao != null) {
        final cached = await eventCacheDao!.getCachedEvent(eventId);
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<EventModel>> searchEvents(EventFilter filter) async {
    // Firestore has no full-text search: fetch by category (indexed) and match
    // the keyword locally against title, location and category.
    final upcoming = await getUpcomingEvents(
      filter: EventFilter(category: filter.category),
    );
    final keyword = filter.keyword;
    return filter
        .withKeyword('')
        .apply(upcoming.where((event) => event.matchesKeyword(keyword)));
  }

  @override
  Future<List<EventModel>> getEventsByIds(List<String> eventIds) async {
    final ids = <String>{
      for (final id in eventIds)
        if (id.trim().isNotEmpty && !id.contains('/')) id.trim(),
    }.toList();
    if (ids.isEmpty) return const <EventModel>[];
    try {
      return await _request(() async {
        final results = await Future.wait(ids.map(_tryReadEvent));
        final events = List<EventModel>.unmodifiable(
          results.whereType<EventModel>(),
        );
        if (events.isEmpty && eventCacheDao != null) {
          final cached = await _readCachedByIds(ids);
          if (cached.isNotEmpty) return cached;
        }
        return events;
      });
    } catch (e) {
      if (_isOfflineOrTimeout(e) && eventCacheDao != null) {
        final cached = await _readCachedByIds(ids);
        if (cached.isNotEmpty) return cached;
      }
      rethrow;
    }
  }

  Future<List<EventModel>> _readCachedByIds(List<String> ids) async {
    if (eventCacheDao == null) return const [];
    final list = <EventModel>[];
    for (final id in ids) {
      final cached = await eventCacheDao!.getCachedEvent(id);
      if (cached != null) list.add(cached);
    }
    return List<EventModel>.unmodifiable(list);
  }

  Future<EventModel?> _tryReadEvent(String id) async {
    try {
      final snapshot = await firestore
          .collection(FirestoreCollections.events)
          .doc(id)
          .get(const GetOptions(source: Source.server));
      if (!snapshot.exists) return null;
      final event = EventModel.fromFirestore(snapshot);
      unawaited(eventCacheDao?.saveEvent(event));
      return event;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'not-found') {
        return null;
      }
      if (_isOfflineOrTimeout(error) && eventCacheDao != null) {
        return eventCacheDao!.getCachedEvent(id);
      }
      rethrow;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } catch (error) {
      if (_isOfflineOrTimeout(error) && eventCacheDao != null) {
        return eventCacheDao!.getCachedEvent(id);
      }
      rethrow;
    }
  }

  @override
  Future<List<EventModel>> getRelatedEvents({
    required String eventId,
    required String category,
    int limit = 5,
  }) async {
    final upcoming = await getUpcomingEvents(
      filter: EventFilter(category: category),
    );
    return upcoming.where((event) => event.id != eventId).take(limit).toList();
  }

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Xác minh manager và giới hạn organizer theo UID; admin dùng nhánh quản lý rộng hơn.
  /// ROLE: Authorization call site; nghiệp vụ event ngoài phạm vi
  /// CALLED FROM: Event management providers / EventRepositoryImpl.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
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

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Xác minh manager trước query dashboard owner-scoped cho cả organizer và admin.
  /// ROLE: Authorization call site; nghiệp vụ event ngoài phạm vi
  /// CALLED FROM: Event management providers / EventRepositoryImpl.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
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

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Gọi verified actor, manager và owner/admin trước khi xác nhận hoặc tiếp tục thao tác tạo event.
  /// ROLE: Authorization call site; nghiệp vụ event ngoài phạm vi
  /// CALLED FROM: Event management providers / EventRepositoryImpl.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
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
          // server timestamps/counters. A persisted createRequestId also allows
          // local drafts to recover the same document after an app restart.
          final detailsKey = jsonEncode([
            actor.uid,
            input.title.trim(),
            input.description.trim(),
            input.category.trim(),
            input.locationName.trim(),
            input.startAt.microsecondsSinceEpoch,
            input.endAt.microsecondsSinceEpoch,
            input.capacity,
            (input.status ?? EventStatus.published).name,
          ]);
          final key = input.createRequestId == null
              ? detailsKey
              : jsonEncode([actor.uid, input.createRequestId]);
          final existing = _createAttempts[key];
          _requireValidInput(
            input,
            requireFutureStart:
                existing == null &&
                (input.status ?? EventStatus.published) ==
                    EventStatus.published,
          );
          if (input.posterSelection != null) {
            await EventPosterValidator.validate(input.posterSelection!);
            _requirePosterService();
          }
          final attempt =
              existing ??
              _EventCreateAttempt(
                firestore
                    .collection(FirestoreCollections.events)
                    .doc(
                      input.createRequestId == null
                          ? null
                          : '${Uri.encodeComponent(actor.uid)}_${Uri.encodeComponent(input.createRequestId!)}',
                    ),
                _createMap(input, actor.uid),
                detailsKey,
                reuseExisting: input.createRequestId != null,
              );
          _createAttempts[key] = attempt;
          try {
            final event = await attempt.confirm();
            _requireOwnerOrAdmin(event, actor);
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
            if (attempt.detailsKey != detailsKey ||
                !_sameEditableValues(event, input)) {
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

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Xác minh actor/manager trước cập nhật và kiểm tra owner/admin khi tải event.
  /// ROLE: Authorization call site; nghiệp vụ event ngoài phạm vi
  /// CALLED FROM: Event management providers / EventRepositoryImpl.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
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

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm tra owner/admin trên event được đọc trong transaction trước update.
  /// ROLE: Authorization call site; nghiệp vụ event ngoài phạm vi
  /// CALLED FROM: Event management providers / EventRepositoryImpl.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
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
      _requireStatusTransition(existing, input);
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

  void _requireStatusTransition(EventModel event, EventFormInput input) {
    final target = input.status ?? event.status;
    if (target == event.status) return;
    if (!{EventStatus.draft, EventStatus.published}.contains(event.status) ||
        !{EventStatus.draft, EventStatus.published}.contains(target)) {
      throw const AppException(
        'Only draft and published events can change publication status.',
        code: 'event-status-transition',
      );
    }
    if (event.registeredCount != 0 || event.checkedInCount != 0) {
      throw const AppException(
        'Publication status cannot change after participants have registered.',
        code: 'event-status-has-participants',
      );
    }
    if (target == EventStatus.published) {
      _requireValidInput(input, requireFutureStart: true);
    }
  }

  bool _sameEditableValues(EventModel event, EventFormInput input) =>
      event.title == input.title.trim() &&
      event.description == input.description.trim() &&
      event.category == input.category.trim() &&
      event.locationName == input.locationName.trim() &&
      event.capacity == input.capacity &&
      (input.status == null || event.status == input.status) &&
      event.startAt.isAtSameMomentAs(input.startAt) &&
      event.endAt.isAtSameMomentAs(input.endAt);

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm tra owner/admin trước upload và tái kiểm tra trong _commitUpdate.
  /// ROLE: Authorization call site; nghiệp vụ event ngoài phạm vi
  /// CALLED FROM: Event management providers / EventRepositoryImpl.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
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
      _requireStatusTransition(event, input);
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
              'event-status-transition',
              'event-status-has-participants',
              'invalid-event-input',
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

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Xác minh actor/manager trước khi chuyển tới transaction hủy event.
  /// ROLE: Authorization call site; nghiệp vụ event ngoài phạm vi
  /// CALLED FROM: Event management providers / EventRepositoryImpl.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
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

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm tra owner/admin trên snapshot transaction trước khi đổi trạng thái event.
  /// ROLE: Authorization call site; nghiệp vụ event ngoài phạm vi
  /// CALLED FROM: Event management providers / EventRepositoryImpl.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
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

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Đối chiếu supplied actor với resolver xác thực; thiếu resolver là nhánh isolated tests.
  /// ROLE: Event authorization boundary
  /// CALLED FROM: Các thao tác EventRepositoryImpl có actor.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
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

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Yêu cầu UID không rỗng, account active và khả năng organizer/admin trước quản lý event.
  /// ROLE: Event authorization boundary
  /// CALLED FROM: getManagedEvents, getOrganizerDashboard và event mutations.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
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

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Từ chối organizer thao tác event người khác; cho phép admin theo nhánh hiện có.
  /// ROLE: Event authorization boundary
  /// CALLED FROM: EventRepositoryImpl update/cancel/poster.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
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
    int? currentRegisteredCount,
  }) {
    final errors = input.validate(
      requireFutureStart: requireFutureStart,
      now: _now(),
      currentRegisteredCount:
          currentRegisteredCount ?? input.currentRegisteredCount,
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
    'status': (input.status ?? EventStatus.published).name,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> _editableMap(EventFormInput input) => {
    ..._editableValues(input),
    if (input.status != null) 'status': input.status!.name,
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
    this.detailsKey, {
    bool reuseExisting = false,
  }) {
    _write =
        (reuseExisting
                ? () async {
                    // An exact documentId equality can be authorized as a get,
                    // which the existing Rules deny for a missing document.
                    // A bounded owner range remains a list query and reads at
                    // most one document, including when the target is absent.
                    final existing = await reference.parent
                        .where('organizerId', isEqualTo: data['organizerId'])
                        .where(
                          FieldPath.documentId,
                          isGreaterThanOrEqualTo: reference.id,
                        )
                        .orderBy(FieldPath.documentId)
                        .limit(1)
                        .get(const GetOptions(source: Source.server));
                    if (!existing.docs.any((doc) => doc.id == reference.id)) {
                      await reference.set(data);
                    }
                  }()
                : reference.set(data))
            .then((_) => writeAcknowledged = true);
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
