import 'package:campushub/core/utils/qr_payload.dart';
import 'package:campushub/features/registration/data/models/registration_model.dart';
import 'package:campushub/features/registration/data/registration_repository.dart';
import 'package:campushub/shared/enums/registration_status.dart';

RegistrationModel testRegistration({
  String id = 'reg-1',
  String eventId = 'event-1',
  String userId = 'user-1',
  RegistrationStatus status = RegistrationStatus.registered,
  String qrToken = 'token-1',
  DateTime? registeredAt,
  DateTime? cancelledAt,
  DateTime? checkedInAt,
}) => RegistrationModel(
  id: id,
  eventId: eventId,
  userId: userId,
  status: status,
  qrToken: qrToken,
  registeredAt: registeredAt ?? DateTime.utc(2030, 5, 1, 10),
  cancelledAt: cancelledAt,
  checkedInAt: checkedInAt,
);

class FakeRegistrationRepository implements RegistrationRepository {
  FakeRegistrationRepository([List<RegistrationModel>? initial])
    : registrations = List.of(initial ?? []);

  List<RegistrationModel> registrations;
  Object? failure;

  @override
  Future<List<RegistrationModel>> getEventParticipants(String eventId) async {
    if (failure != null) throw failure!;
    return registrations.where((r) => r.eventId == eventId).toList();
  }

  @override
  Future<RegistrationModel> joinEvent({
    required String eventId,
    required String userId,
  }) async {
    if (failure != null) throw failure!;
    final reg = testRegistration(
      id: 'reg-${registrations.length + 1}',
      eventId: eventId,
      userId: userId,
    );
    registrations.add(reg);
    return reg;
  }

  @override
  Future<void> cancelRegistration({
    required String registrationId,
    required String userId,
  }) async {
    if (failure != null) throw failure!;
    registrations.removeWhere((r) => r.id == registrationId);
  }

  @override
  Future<List<RegistrationModel>> getMyRegistrations(String userId) async {
    if (failure != null) throw failure!;
    return registrations.where((r) => r.userId == userId).toList();
  }

  @override
  Future<RegistrationModel?> getRegistration(
    String eventId,
    String userId,
  ) async {
    if (failure != null) throw failure!;
    return registrations
        .where((r) => r.eventId == eventId && r.userId == userId)
        .firstOrNull;
  }

  @override
  Future<RegistrationModel> checkIn({
    required String organizerId,
    required QrPayload payload,
  }) async {
    if (failure != null) throw failure!;
    final reg = registrations.firstWhere(
      (r) => r.id == payload.registrationId,
      orElse: () => testRegistration(id: payload.registrationId),
    );
    return reg;
  }
}
