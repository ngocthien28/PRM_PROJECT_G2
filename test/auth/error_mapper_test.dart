import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/errors/error_mapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final code in [
    'email-already-in-use',
    'invalid-email',
    'weak-password',
    'invalid-credential',
    'user-disabled',
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
  test('unidentified native errors do not imply missing configuration', () {
    final source = FirebaseAuthException(
      code: 'unknown-error',
      message: 'An internal error has occurred.',
    );
    final mapped = mapError(source, StackTrace.empty);
    expect(mapped.code, 'unknown-error');
    expect(mapped.message, 'Something went wrong. Please try again.');
  });
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
