import '../../../../core/utils/qr_payload.dart';
import 'models/registration_model.dart';

/// Contract for event registration, ticket management and check-in transactions.
abstract interface class RegistrationRepository {
  /// Registers the student for an event using a Firestore Transaction.
  /// Enforces event availability, capacity limit, and prevents duplicate registration.
  Future<RegistrationModel> joinEvent({
    required String eventId,
    required String userId,
  });

  /// Cancels an existing registration if allowed before the deadline.
  Future<void> cancelRegistration({
    required String registrationId,
    required String userId,
  });

  /// Retrieves all registrations belonging to the specified user.
  Future<List<RegistrationModel>> getMyRegistrations(String userId);

  /// Retrieves registration details for a specific user and event.
  Future<RegistrationModel?> getRegistration(String eventId, String userId);

  /// Retrieves all active participants for an event (for Organizer view).
  Future<List<RegistrationModel>> getEventParticipants(String eventId);

  /// Performs an atomic check-in transaction verifying ticket authenticity.
  Future<RegistrationModel> checkIn({
    required String organizerId,
    required QrPayload payload,
  });
}
