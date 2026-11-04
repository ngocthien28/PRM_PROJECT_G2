import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'app_exception.dart';

/// FEATURE: UC-013 - Implement Shared Loading and Error Handling
/// MODULE: App Shell
/// DESCRIPTION: Ánh xạ mã Firebase/domain thành AppException; giữ cause và che chi tiết lỗi không xác định.
/// ROLE: Shared error mapping
/// CALLED FROM: Repositories và view models gọi mapError.
/// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Firebase Core.
AppException mapError(Object error, StackTrace stack) {
  final sourceCode = error is FirebaseException
      ? error.code
      : error is AppException
      ? error.code
      : 'unknown';
  // Some native SDK errors wrap the backend configuration error in an
  // internal/unknown error. Recognize only that explicit backend marker.
  final missingAuthConfiguration =
      error is FirebaseException &&
      ({'unknown', 'unknown-error', 'internal-error'}.contains(sourceCode)) &&
      RegExp(r'\bCONFIGURATION_NOT_FOUND\b').hasMatch(error.message ?? '');
  final code = missingAuthConfiguration
      ? 'configuration-not-found'
      : sourceCode;
  debugPrint('CampusHub: ${error.runtimeType} [$code]\n$stack');
  if (error is AppException) return error;
  final message = switch (code) {
    'invalid-email' => 'Please enter a valid email address.',
    'weak-password' => 'Password does not meet the account password policy.',
    'email-already-in-use' =>
      'This email is already registered. Please sign in.',
    'wrong-password' ||
    'user-not-found' ||
    'invalid-credential' ||
    'INVALID_LOGIN_CREDENTIALS' => 'Email or password is incorrect.',
    'user-disabled' => 'This account has been disabled.',
    'invalid-user-token' ||
    'user-token-expired' => 'Your session has expired. Please sign in again.',
    'network-request-failed' || 'unavailable' || 'deadline-exceeded' =>
      'Cannot connect to the server. Check your connection and try again.',
    'too-many-requests' => 'Too many requests. Please try again later.',
    'permission-denied' => 'You do not have permission to access this data.',
    'operation-not-allowed' =>
      'Email/password sign-in is not enabled. Contact the project administrator.',
    'configuration-not-found' || 'CONFIGURATION_NOT_FOUND' =>
      'Account access is not configured yet. Contact the project administrator.',
    'invalid-api-key' || 'app-not-authorized' =>
      'This app cannot connect to the account service. Contact the project administrator.',
    _ => 'Something went wrong. Please try again.',
  };
  return AppException(message, code: code, cause: error);
}
