import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'app_exception.dart';

AppException mapError(Object error, StackTrace stack) {
  final code = error is FirebaseException
      ? error.code
      : error is AppException
      ? error.code
      : 'unknown';
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
    'network-request-failed' || 'unavailable' || 'deadline-exceeded' =>
      'Cannot connect to the server. Check your connection and try again.',
    'too-many-requests' => 'Too many requests. Please try again later.',
    'permission-denied' => 'You do not have permission to access this data.',
    'operation-not-allowed' =>
      'Email/password sign-in is not enabled. Contact the project administrator.',
    _ => 'Something went wrong. Please try again.',
  };
  return AppException(message, code: code, cause: error);
}
