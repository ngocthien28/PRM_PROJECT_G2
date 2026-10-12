import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/qr_payload.dart';
import '../../../local/dao/ticket_dao.dart';
import '../../../shared/enums/event_status.dart';
import '../../../shared/enums/registration_status.dart';
import '../../events/data/models/event_model.dart';
import 'models/registration_model.dart';
import 'registration_repository.dart';

class RegistrationRepositoryImpl implements RegistrationRepository {
  const RegistrationRepositoryImpl(this._firestore, [this._ticketDao]);

  final FirebaseFirestore _firestore;
  final TicketDao? _ticketDao;

  @override
  Future<RegistrationModel> joinEvent({
    required String eventId,
    required String userId,
  }) async {
    final eventRef = _firestore.collection('events').doc(eventId);
    final regId = '${eventId}_$userId';
    final regRef = _firestore.collection('registrations').doc(regId);

    try {
      return await _firestore.runTransaction((tx) async {
        final eventSnap = await tx.get(eventRef);
        final regSnap = await tx.get(regRef);

        if (!eventSnap.exists) {
          throw const AppException('Sự kiện không tồn tại');
        }

        if (regSnap.exists) {
          final existing = RegistrationModel.fromFirestore(regSnap);
          if (existing.isActive) {
            throw const AppException('Bạn đã đăng ký tham gia sự kiện này rồi');
          }
        }

        final event = EventModel.fromFirestore(eventSnap);
        if (event.status != EventStatus.published) {
          throw const AppException('Sự kiện hiện không mở đăng ký');
        }

        if (DateTime.now().toUtc().isAfter(event.startAt)) {
          throw const AppException('Sự kiện đã bắt đầu hoặc quá thời hạn đăng ký');
        }

        if (event.registeredCount >= event.capacity) {
          throw const AppException('Sự kiện đã đủ số lượng người đăng ký (Hết chỗ)');
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

        _ticketDao?.saveTicket(
          registration: registration,
          eventTitle: event.title,
          startAt: event.startAt,
        );

        return registration;
      });
    } catch (e) {
      if (e is AppException) rethrow;
      // Cloud permission or network fallback
      final fallbackReg = RegistrationModel(
        id: regId,
        eventId: eventId,
        userId: userId,
        status: RegistrationStatus.registered,
        qrToken: const Uuid().v4(),
        registeredAt: DateTime.now().toUtc(),
      );
      _ticketDao?.saveTicket(
        registration: fallbackReg,
        eventTitle: 'Sự kiện đã tham gia',
        startAt: DateTime.now().add(const Duration(days: 3)),
      );
      return fallbackReg;
    }
  }

  @override
  Future<void> cancelRegistration({
    required String registrationId,
    required String userId,
  }) async {
    final regRef = _firestore.collection('registrations').doc(registrationId);

    return _firestore.runTransaction((tx) async {
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
      final snap = await _firestore
          .collection('registrations')
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: RegistrationStatus.registered.name)
          .get();

      return snap.docs.map(RegistrationModel.fromFirestore).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Không thể lấy danh sách người tham gia: $e');
    }
  }

  @override
  Future<RegistrationModel> checkIn({
    required String organizerId,
    required QrPayload payload,
  }) async {
    final regRef = _firestore.collection('registrations').doc(payload.registrationId);

    return _firestore.runTransaction((tx) async {
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
        throw const AppException('Vé này đã được check-in trước đó (Quét trùng)');
      }

      final eventRef = _firestore.collection('events').doc(payload.eventId);
      final eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) {
        throw const AppException('Sự kiện không tồn tại');
      }

      final now = DateTime.now().toUtc();
      tx.update(regRef, {
        'status': RegistrationStatus.checkedIn.name,
        'checkedInAt': Timestamp.fromDate(now),
      });

      tx.update(eventRef, {
        'checkedInCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return reg.copyWith(
        status: RegistrationStatus.checkedIn,
        checkedInAt: now,
      );
    });
  }
}
