import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/errors/error_mapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// FEATURE: UC-014 - Test Authentication and Profile
/// MODULE: Testing & Integration
/// DESCRIPTION: Hàm void main: Mã Firebase và che lỗi nội bộ.
/// ROLE: Test entry point / fixture helper
/// CALLED FROM: Các test Auth/Profile/navigation.
/// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
/// TECHNOLOGY: Dart, flutter_test, Firebase Auth SDK.
void main() {
  for (final code in [
    'email-already-in-use',
    'invalid-email',
    'weak-password',
    'invalid-credential',
    'user-disabled',
    'invalid-user-token',
    'user-token-expired',
    'network-request-failed',
    'permission-denied',
    'unavailable',
    'too-many-requests',
    'operation-not-allowed',
    'configuration-not-found',
    'CONFIGURATION_NOT_FOUND',
    'invalid-api-key',
    'app-not-authorized',
  ]) {
    /// FEATURE: UC-014 - Test Authentication and Profile
    /// MODULE: Testing & Integration
    /// DESCRIPTION: Kiểm thử: maps $code to readable error while retaining technical cause.
    /// ROLE: Existing test callback
    /// CALLED FROM: flutter_test runner / main.
    /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
    /// TECHNOLOGY: Dart, flutter_test, Firebase Auth SDK.
    test('maps $code to readable error while retaining technical cause', () {
      final source = FirebaseAuthException(
        code: code,
        message: 'Internal sensitive detail',
      );
      final mapped = mapError(source, StackTrace.empty);
      expect(mapped.code, code);
      expect(mapped.cause, same(source));
      expect(mapped.message, isNot(contains('Internal sensitive detail')));
      expect(mapped.message, isNot('Something went wrong. Please try again.'));
    });
  }
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: native configuration errors are actionable without exposing details.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Firebase Auth SDK.
  test(
    'native configuration errors are actionable without exposing details',
    () {
      for (final code in ['unknown', 'unknown-error', 'internal-error']) {
        final source = FirebaseAuthException(
          code: code,
          message: 'Backend response: CONFIGURATION_NOT_FOUND; private detail',
        );
        final mapped = mapError(source, StackTrace.empty);
        expect(mapped.code, 'configuration-not-found');
        expect(mapped.message, contains('not configured'));
        expect(mapped.message, isNot(contains('private detail')));
        expect(mapped.cause, same(source));
      }
    },
  );
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: unidentified native errors do not imply missing configuration.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Firebase Auth SDK.
  test('unidentified native errors do not imply missing configuration', () {
    final source = FirebaseAuthException(
      code: 'unknown-error',
      message: 'An internal error has occurred.',
    );
    final mapped = mapError(source, StackTrace.empty);
    expect(mapped.code, 'unknown-error');
    expect(mapped.message, 'Something went wrong. Please try again.');
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: unknown error is safe and domain error retains its code.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Firebase Auth SDK.
  test('unknown error is safe and domain error retains its code', () {
    expect(
      mapError(Exception('private detail'), StackTrace.empty).message,
      'Something went wrong. Please try again.',
    );
    const domain = AppException(
      'Retry profile setup.',
      code: 'profile-create-failed',
    );
    expect(mapError(domain, StackTrace.empty), same(domain));
  });
}
