import 'dart:convert';
import '../errors/app_exception.dart';

/// Secure, versioned QR payload structure for CampusHub tickets.
/// Avoids embedding raw sensitive information such as user email or password.
class QrPayload {
  const QrPayload({
    this.version = 1,
    required this.registrationId,
    required this.eventId,
    required this.token,
  });

  final int version;
  final String registrationId;
  final String eventId;
  final String token;

  /// Encodes this payload into a compact JSON string for QR code generation.
  String encode() => jsonEncode({
    'v': version,
    'rid': registrationId,
    'eid': eventId,
    't': token,
  });

  /// Decodes and validates a raw QR code string.
  /// Throws [AppException] if the payload is malformed or invalid.
  factory QrPayload.decode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) {
        throw const AppException('Mã QR không đúng định dạng');
      }

      final version = map['v'] as int? ?? 1;
      final registrationId = map['rid'] as String?;
      final eventId = map['eid'] as String?;
      final token = map['t'] as String?;

      if (registrationId == null || registrationId.isEmpty) {
        throw const AppException('Mã vé trong QR không hợp lệ');
      }
      if (eventId == null || eventId.isEmpty) {
        throw const AppException('Mã sự kiện trong QR không hợp lệ');
      }
      if (token == null || token.isEmpty) {
        throw const AppException('Mã xác thực vé không hợp lệ');
      }

      return QrPayload(
        version: version,
        registrationId: registrationId,
        eventId: eventId,
        token: token,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Không thể đọc mã QR: $e');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QrPayload &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          registrationId == other.registrationId &&
          eventId == other.eventId &&
          token == other.token;

  @override
  int get hashCode => Object.hash(version, registrationId, eventId, token);
}
