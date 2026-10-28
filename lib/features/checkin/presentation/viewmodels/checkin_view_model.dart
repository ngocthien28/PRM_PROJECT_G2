import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../../core/utils/qr_payload.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../registration/data/models/registration_model.dart';
import '../../../organizer_events/presentation/viewmodels/participant_summary_view_model.dart';
import '../../../organizer_events/presentation/viewmodels/organizer_dashboard_view_model.dart';
import '../../../events/presentation/viewmodels/event_detail_view_model.dart';
import '../../../events/presentation/viewmodels/event_list_view_model.dart';
import '../../../registration/presentation/viewmodels/registration_view_model.dart';

/// Represents the detailed outcome of a check-in attempt.
class CheckinResult {
  const CheckinResult({
    required this.isSuccess,
    required this.message,
    this.registration,
    this.participantName,
    this.participantEmail,
    this.eventTitle,
    this.checkedInAt,
    this.errorCode,
  });

  final bool isSuccess;
  final String message;
  final RegistrationModel? registration;
  final String? participantName;
  final String? participantEmail;
  final String? eventTitle;
  final DateTime? checkedInAt;
  final String? errorCode;
}

enum CheckinStatus { idle, processing, success, error }

class CheckinState {
  const CheckinState({
    this.status = CheckinStatus.idle,
    this.result,
    this.errorMessage,
    this.isLocked = false,
  });

  final CheckinStatus status;
  final CheckinResult? result;
  final String? errorMessage;
  final bool isLocked;

  CheckinState copyWith({
    CheckinStatus? status,
    CheckinResult? result,
    String? errorMessage,
    bool? isLocked,
  }) {
    return CheckinState(
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

final checkinViewModelProvider =
    NotifierProvider<CheckinViewModel, CheckinState>(CheckinViewModel.new);

class CheckinViewModel extends Notifier<CheckinState> {
  @override
  CheckinState build() => const CheckinState();

  /// Processes a scanned raw QR string or manually entered payload.
  /// Locks the scanner until [unlockScanner] is explicitly called.
  Future<CheckinResult> processBarcode(
    String rawData, {
    String? expectedEventId,
    String? expectedEventTitle,
  }) async {
    // If currently locked or processing, ignore repeated detections
    if (state.isLocked) {
      return state.result ??
          const CheckinResult(
            isSuccess: false,
            message: 'Đang xử lý mã QR khác...',
          );
    }

    state = state.copyWith(
      status: CheckinStatus.processing,
      isLocked: true,
      errorMessage: null,
    );

    try {
      // 1. Validate and decode the QR Payload
      final QrPayload payload;
      try {
        payload = QrPayload.decode(rawData);
      } catch (e) {
        final failure = CheckinResult(
          isSuccess: false,
          message:
              'Mã QR không đúng định dạng của CampusHub hoặc đã bị biến đổi.',
          errorCode: 'invalid_qr',
        );
        state = state.copyWith(
          status: CheckinStatus.error,
          result: failure,
          errorMessage: failure.message,
        );
        return failure;
      }

      // 2. Business Rule: Check for wrong event ticket
      if (expectedEventId != null &&
          expectedEventId.isNotEmpty &&
          payload.eventId != expectedEventId) {
        final failure = CheckinResult(
          isSuccess: false,
          message: 'Mã vé không thuộc sự kiện này! (Vé thuộc sự kiện khác)',
          errorCode: 'wrong_event',
        );
        state = state.copyWith(
          status: CheckinStatus.error,
          result: failure,
          errorMessage: failure.message,
        );
        return failure;
      }

      // 3. Organizer authentication & status check
      final currentUser = ref.read(currentUserProvider).asData?.value;
      final authState = ref.read(authStateProvider).asData?.value;
      final organizerId = currentUser?.uid ?? authState?.uid;

      if (organizerId == null) {
        final failure = const CheckinResult(
          isSuccess: false,
          message: 'Vui lòng đăng nhập với quyền Ban tổ chức để check-in.',
          errorCode: 'unauthenticated',
        );
        state = state.copyWith(
          status: CheckinStatus.error,
          result: failure,
          errorMessage: failure.message,
        );
        return failure;
      }

      if (currentUser != null && !currentUser.isActive) {
        final failure = const CheckinResult(
          isSuccess: false,
          message: 'Tài khoản của bạn đã bị khóa hoặc chưa kích hoạt.',
          errorCode: 'inactive_account',
        );
        state = state.copyWith(
          status: CheckinStatus.error,
          result: failure,
          errorMessage: failure.message,
        );
        return failure;
      }

      // 4. Perform check-in transaction via repository
      final repo = ref.read(registrationRepositoryProvider);
      final updatedReg = await repo.checkIn(
        organizerId: organizerId,
        payload: payload,
      );
      if (ref.mounted) {
        ref.invalidate(participantSummaryProvider(payload.eventId));
        ref.invalidate(organizerDashboardProvider);
        ref.invalidate(managedEventDetailProvider(payload.eventId));
        ref.invalidate(eventDetailProvider(payload.eventId));
        ref.invalidate(eventListProvider);
        ref.invalidate(myRegistrationsProvider);
        ref.invalidate(eventRegistrationStatusProvider(payload.eventId));
      }

      // 5. Look up participant display name and email for the result screen
      String? participantName;
      String? participantEmail;
      try {
        final firestore = ref.read(firestoreProvider);
        final userDoc = await firestore
            .collection('users')
            .doc(updatedReg.userId)
            .get()
            .timeout(const Duration(seconds: 2));
        if (userDoc.exists) {
          final data = userDoc.data();
          participantName = data?['displayName'] as String?;
          participantEmail = data?['email'] as String?;
        }
      } catch (_) {
        // Fallback gracefully without breaking check-in flow
      }

      final success = CheckinResult(
        isSuccess: true,
        message: 'Check-in thành công!',
        registration: updatedReg,
        participantName: participantName ?? 'Sinh viên (${updatedReg.userId})',
        participantEmail: participantEmail,
        eventTitle: expectedEventTitle ?? 'Sự kiện #${payload.eventId}',
        checkedInAt: updatedReg.checkedInAt ?? DateTime.now(),
      );

      state = state.copyWith(status: CheckinStatus.success, result: success);

      return success;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      String errorCode = 'checkin_failed';

      if (msg.contains('Quét trùng') || msg.contains('check-in trước đó')) {
        errorCode = 'duplicate_checkin';
      } else if (msg.contains('sai sự kiện') || msg.contains('không hợp lệ')) {
        errorCode = 'wrong_event';
      } else if (msg.contains('không tồn tại')) {
        errorCode = 'not_found';
      } else if (msg.contains('quyền')) {
        errorCode = 'permission_denied';
      } else if (msg.contains('không mở') || msg.contains('kết thúc')) {
        errorCode = 'event_cancelled';
      }

      final failure = CheckinResult(
        isSuccess: false,
        message: msg,
        errorCode: errorCode,
      );

      state = state.copyWith(
        status: CheckinStatus.error,
        result: failure,
        errorMessage: msg,
      );
      return failure;
    }
  }

  /// Unlocks the scanner to allow subsequent barcode reads.
  void unlockScanner() {
    state = const CheckinState();
  }

  /// Resets state back to initial idle.
  void reset() {
    state = const CheckinState();
  }
}
