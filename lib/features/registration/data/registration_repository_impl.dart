import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/utils/qr_payload.dart';
import '../../../local/dao/ticket_dao.dart';
import '../../../shared/enums/event_status.dart';
import '../../../shared/enums/registration_status.dart';
import '../../events/data/models/event_model.dart';
import '../../auth/data/models/app_user.dart';
import 'models/registration_model.dart';
import 'registration_repository.dart';

class RegistrationRepositoryImpl implements RegistrationRepository {
  const RegistrationRepositoryImpl(
    this._firestore, [
    this._ticketDao,
    this._authenticatedActor,
  ]);

  final FirebaseFirestore _firestore;
  final TicketDao? _ticketDao;
  final Future<AppUser?> Function()? _authenticatedActor;

  Future<T> _transaction<T>(TransactionHandler<T> action) async {
    try {
      return await _firestore.runTransaction(action);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  Future<AppUser?> _actor() async {
    if (_authenticatedActor == null) return null; // Isolated fake-DB tests.
    try {
      final actor = await _authenticatedActor().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw const AppException(
          'Account verification timed out. Please try again.',
          code: 'session-timeout',
        ),
      );
      if (actor == null || actor.uid.trim().isEmpty || !actor.isActive) {
        throw const AppException(
          'Please sign in with an active account.',
          code: 'unauthenticated',
        );
      }
      return actor;
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  Future<void> _personalAccess(
    String userId, {
    bool studentOnly = false,
  }) async {
    final actor = await _actor();
    if (actor != null &&
        (actor.uid != userId ||
            (studentOnly && actor.role.name != 'student'))) {
      throw const AppException(
        'You do not have permission to perform this action.',
        code: 'permission-denied',
      );
    }
  }

  @override
  Future<RegistrationModel> joinEvent({
    required String eventId,
    required String userId,
  }) async {
    await _personalAccess(userId, studentOnly: true);
    final eventRef = _firestore.collection('events').doc(eventId);
    final regId = '${eventId}_$userId';
    final regRef = _firestore.collection('registrations').doc(regId);

    try {
      return await _transaction((tx) async {
        final eventSnap = await tx.get(eventRef);
        final regSnap = await tx.get(regRef);

        if (!eventSnap.exists) {
          throw const AppException('Sự kiện không tồn tại');
        }

        if (regSnap.exists) {
          final existing = RegistrationModel.fromFirestore(regSnap);
          if (!existing.isCancelled) {
            throw const AppException('Bạn đã đăng ký tham gia sự kiện này rồi');
          }
        }

        final event = EventModel.fromFirestore(eventSnap);
        if (event.status != EventStatus.published) {
          throw const AppException('Sự kiện hiện không mở đăng ký');
        }

        if (DateTime.now().toUtc().isAfter(event.startAt)) {
          throw const AppException(
            'Sự kiện đã bắt đầu hoặc quá thời hạn đăng ký',
          );
        }

        if (event.registeredCount >= event.capacity) {
          throw const AppException(
            'Sự kiện đã đủ số lượng người đăng ký (Hết chỗ)',
          );
        }

        final registration = RegistrationModel(
          id: regId,
          eventId: eventId,
          userId: userId,
          status: RegistrationStatus.registered,
          qrToken: const Uuid().v4(),
          registeredAt: DateTime.now().toUtc(),
        );

        tx.set(regRef, registration.toCreateMap());
        tx.update(eventRef, {
          'registeredCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return registration;
      });
    } catch (e) {
      if (e is AppException) rethrow;
      // A rejected/uncertain transaction is not a confirmed ticket.
      // The action ViewModel caches only after a successful repository result.
      throw mapError(e, StackTrace.current);
    }
  }

  @override
  Future<void> cancelRegistration({
    required String registrationId,
    required String userId,
  }) async {
    await _personalAccess(userId, studentOnly: true);
    final regRef = _firestore.collection('registrations').doc(registrationId);

    return _transaction((tx) async {
      final regSnap = await tx.get(regRef);
      if (!regSnap.exists) {
        throw const AppException('Không tìm thấy thông tin đăng ký');
      }

      final reg = RegistrationModel.fromFirestore(regSnap);
      if (reg.userId != userId) {
        throw const AppException('Bạn không có quyền hủy đăng ký này');
      }

      if (reg.status == RegistrationStatus.cancelled) {
        return;
      }

      if (reg.checkedInAt != null) {
        throw const AppException('Vé đã được check-in, không thể hủy');
      }

      final eventRef = _firestore.collection('events').doc(reg.eventId);
      final eventSnap = await tx.get(eventRef);
      if (eventSnap.exists) {
        final event = EventModel.fromFirestore(eventSnap);
        // Cutoff rule: At least 2 hours before event start time (BR-07)
        final cutoff = event.startAt.subtract(const Duration(hours: 2));
        if (DateTime.now().toUtc().isAfter(cutoff)) {
          throw const AppException(
            'Chỉ được hủy đăng ký trước giờ bắt đầu sự kiện ít nhất 2 giờ',
          );
        }

        tx.update(eventRef, {
          'registeredCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      tx.update(regRef, {
        'status': RegistrationStatus.cancelled.name,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<List<RegistrationModel>> getMyRegistrations(String userId) async {
    await _personalAccess(userId);
    try {
      final snap = await _firestore
          .collection('registrations')
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 2));

      final list = snap.docs.map(RegistrationModel.fromFirestore).toList();
      list.sort((a, b) => b.registeredAt.compareTo(a.registeredAt));

      for (final reg in list) {
        _ticketDao?.saveTicket(
          registration: reg,
          eventTitle: 'Sự kiện đã đăng ký',
          startAt: reg.registeredAt,
        );
      }
      return list;
    } catch (_) {
      // Graceful offline and permission-denied fallback from SQLite / Memory cache
      if (_ticketDao != null) {
        final cached = await _ticketDao.getMyTickets(userId);
        if (cached.isNotEmpty) {
          return cached.map((t) => t.toRegistrationModel()).toList();
        }
      }
      return const [];
    }
  }

  @override
  Future<RegistrationModel?> getRegistration(
    String eventId,
    String userId,
  ) async {
    await _personalAccess(userId);
    try {
      final regId = '${eventId}_$userId';
      final doc = await _firestore
          .collection('registrations')
          .doc(regId)
          .get()
          .timeout(const Duration(seconds: 2));
      if (!doc.exists) return null;
      return RegistrationModel.fromFirestore(doc);
    } catch (_) {
      if (_ticketDao != null) {
        final ticket = await _ticketDao.getTicket('${eventId}_$userId');
        return ticket?.toRegistrationModel();
      }
      return null;
    }
  }

  @override
  Future<List<RegistrationModel>> getEventParticipants(String eventId) async {
    try {
      final actor = await _actor();
      if (actor != null) {
        final event = await _firestore
            .collection('events')
            .doc(eventId)
            .get(const GetOptions(source: Source.server));
        if (!actor.role.canOrganize ||
            (actor.role.name != 'admin' &&
                event.data()?['organizerId'] != actor.uid)) {
          throw const AppException(
            'You can only view participants for events you manage.',
            code: 'event-forbidden',
          );
        }
      }
      final snap = await _firestore
          .collection('registrations')
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: RegistrationStatus.registered.name)
          .get();

      return snap.docs.map(RegistrationModel.fromFirestore).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw mapError(e, StackTrace.current);
    }
  }

  @override
  Future<RegistrationModel> checkIn({
    required String organizerId,
    required QrPayload payload,
  }) async {
    final actor = await _actor();
    if (actor != null &&
        (actor.uid != organizerId || !actor.role.canOrganize)) {
      throw const AppException(
        'You do not have permission to check in participants.',
        code: 'event-forbidden',
      );
    }
    final regRef = _firestore
        .collection('registrations')
        .doc(payload.registrationId);

    return _transaction((tx) async {
      final regSnap = await tx.get(regRef);
      if (!regSnap.exists) {
        throw const AppException('Vé không tồn tại trên hệ thống');
      }

      final reg = RegistrationModel.fromFirestore(regSnap);

      // Verify payload integrity with Firestore
      if (reg.eventId != payload.eventId || reg.qrToken != payload.token) {
        throw const AppException('Mã QR không hợp lệ hoặc sai sự kiện');
      }

      if (reg.status != RegistrationStatus.registered) {
        throw const AppException('Vé không ở trạng thái hoạt động để check-in');
      }

      if (reg.checkedInAt != null) {
        throw const AppException(
          'Vé này đã được check-in trước đó (Quét trùng)',
        );
      }

      final eventRef = _firestore.collection('events').doc(payload.eventId);
      final eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) {
        throw const AppException('Sự kiện không tồn tại');
      }

      final event = EventModel.fromFirestore(eventSnap);
      final profile = await tx.get(
        _firestore.collection('users').doc(organizerId),
      );
      final role = profile.data()?['role'];
      if (profile.data()?['status'] != 'active' ||
          (role != 'admin' &&
              (role != 'organizer' || event.organizerId != organizerId))) {
        throw const AppException(
          'You can only check in participants for events you manage.',
          code: 'event-forbidden',
        );
      }
      if (event.status != EventStatus.published) {
        throw const AppException(
          'This event is not open for check-in.',
          code: 'event-cancelled',
        );
      }

      final now = DateTime.now().toUtc();
      tx.update(regRef, {
        'status': RegistrationStatus.checkedIn.name,
        'checkedInAt': FieldValue.serverTimestamp(),
      });

      tx.update(eventRef, {
        'checkedInCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastCheckInRegistrationId': reg.id,
      });

      return reg.copyWith(
        status: RegistrationStatus.checkedIn,
        checkedInAt: now,
      );
    });
  }
}
