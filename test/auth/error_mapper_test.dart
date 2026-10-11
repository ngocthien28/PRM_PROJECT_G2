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
