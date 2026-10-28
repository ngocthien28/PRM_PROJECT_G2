import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/qr_payload.dart';
import '../../../../shared/enums/registration_status.dart';

/// CampusHub Event Registration entity.
/// Stores registration state, ticket verification token, and check-in status.
class RegistrationModel {
  const RegistrationModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    required this.qrToken,
    required this.registeredAt,
    this.cancelledAt,
    this.checkedInAt,
    this.isFromCache = false,
  });

  final String id;
  final String eventId;
  final String userId;
  final RegistrationStatus status;
  final String qrToken;
  final DateTime registeredAt;
  final DateTime? cancelledAt;
  final DateTime? checkedInAt;
  final bool isFromCache;

  bool get isActive => status == RegistrationStatus.registered;
  bool get isCancelled => status == RegistrationStatus.cancelled;
  bool get isCheckedIn => status == RegistrationStatus.checkedIn;
  bool get canCancel => isActive && checkedInAt == null;

  /// Generates the QR payload structure for this registration.
  QrPayload get payload =>
      QrPayload(registrationId: id, eventId: eventId, token: qrToken);

  /// Compact JSON string to be encoded in QrImageView.
  String get encodedQr => payload.encode();

  factory RegistrationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw const FormatException('Registration does not exist.');
    }
    return RegistrationModel.fromMap(doc.id, data);
  }

  factory RegistrationModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate().toUtc();
      if (value is String) return DateTime.tryParse(value)?.toUtc();
      return null;
    }

    final registeredAt =
        parseDate(data['registeredAt']) ?? DateTime.now().toUtc();
    final cancelledAt = parseDate(data['cancelledAt']);
    final checkedInAt = parseDate(data['checkedInAt']);

    final statusStr = data['status'] as String?;
    final status = RegistrationStatus.fromString(statusStr);

    return RegistrationModel(
      id: id,
      eventId: data['eventId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      status: status,
      qrToken: data['qrToken'] as String? ?? '',
      registeredAt: registeredAt,
      cancelledAt: cancelledAt,
      checkedInAt: checkedInAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'eventId': eventId,
    'userId': userId,
    'status': status.name,
    'qrToken': qrToken,
    'registeredAt': Timestamp.fromDate(registeredAt.toUtc()),
    'cancelledAt': cancelledAt != null
        ? Timestamp.fromDate(cancelledAt!.toUtc())
        : null,
    'checkedInAt': checkedInAt != null
        ? Timestamp.fromDate(checkedInAt!.toUtc())
        : null,
  };

  Map<String, dynamic> toCreateMap() => {
    'eventId': eventId,
    'userId': userId,
    'status': status.name,
    'qrToken': qrToken,
    'registeredAt': FieldValue.serverTimestamp(),
    'cancelledAt': null,
    'checkedInAt': null,
  };

  RegistrationModel copyWith({
    String? id,
    String? eventId,
    String? userId,
    RegistrationStatus? status,
    String? qrToken,
    DateTime? registeredAt,
    DateTime? cancelledAt,
    DateTime? checkedInAt,
  }) {
    return RegistrationModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      qrToken: qrToken ?? this.qrToken,
      registeredAt: registeredAt ?? this.registeredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      isFromCache: isFromCache,
    );
  }
}
