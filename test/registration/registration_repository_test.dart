import 'package:campushub/core/utils/qr_payload.dart';
import 'package:campushub/features/registration/data/models/registration_model.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QrPayload Tests', () {
    test('encode produces valid JSON payload with version 1', () {
      const payload = QrPayload(
        version: 1,
        registrationId: 'event_01_user_01',
        eventId: 'event_01',
        token: 'uuid-token-xyz',
      );

      final encoded = payload.encode();

      expect(encoded, contains('"v":1'));
      expect(encoded, contains('"rid":"event_01_user_01"'));
      expect(encoded, contains('"eid":"event_01"'));
      expect(encoded, contains('"t":"uuid-token-xyz"'));
    });

    test('decode correctly parses a valid encoded QR payload', () {
      const raw = '{"v":1,"rid":"event_99_user_88","eid":"event_99","t":"random-uuid-123"}';
      final payload = QrPayload.decode(raw);

      expect(payload.version, 1);
      expect(payload.registrationId, 'event_99_user_88');
      expect(payload.eventId, 'event_99');
      expect(payload.token, 'random-uuid-123');
    });

    test('decode throws exception on malformed or invalid QR payload', () {
      expect(() => QrPayload.decode('invalid-json'), throwsException);
      expect(() => QrPayload.decode('{}'), throwsException);
      expect(
        () => QrPayload.decode('{"v":1,"rid":"","eid":"event_01","t":"token"}'),
        throwsException,
      );
    });
  });

  group('RegistrationModel Tests', () {
    test('model correctly reports state and cancel capability', () {
      final reg = RegistrationModel(
        id: 'event_01_user_01',
        eventId: 'event_01',
        userId: 'user_01',
        status: RegistrationStatus.registered,
        qrToken: 'sample-uuid',
        registeredAt: DateTime.now(),
      );

      expect(reg.isActive, isTrue);
      expect(reg.isCheckedIn, isFalse);
      expect(reg.canCancel, isTrue);
      expect(reg.payload.registrationId, 'event_01_user_01');
      expect(reg.encodedQr, isNotEmpty);
    });

    test('checked-in or cancelled registration cannot be cancelled', () {
      final checkedInReg = RegistrationModel(
        id: 'event_01_user_01',
        eventId: 'event_01',
        userId: 'user_01',
        status: RegistrationStatus.checkedIn,
        qrToken: 'sample-uuid',
        registeredAt: DateTime.now(),
        checkedInAt: DateTime.now(),
      );

      expect(checkedInReg.isCheckedIn, isTrue);
      expect(checkedInReg.canCancel, isFalse);

      final cancelledReg = checkedInReg.copyWith(
        status: RegistrationStatus.cancelled,
        checkedInAt: null,
      );

      expect(cancelledReg.isCancelled, isTrue);
      expect(cancelledReg.canCancel, isFalse);
    });
  });
}
