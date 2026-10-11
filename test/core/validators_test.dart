import 'package:campushub/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email requires a complete email and trims surrounding spaces', () {
    for (final value in [null, '', 'abc', 'a@', '@b.com', 'a b@c.com', 'a@b']) {
      expect(Validators.email(value), isNotNull, reason: '$value');
    }
    expect(Validators.email(' Minh@campus.edu.vn '), isNull);
  });
  test('registration password boundary and spaces are preserved', () {
    expect(Validators.password(''), 'Password is required.');
    expect(Validators.password('1234567'), isNotNull);
    expect(Validators.password('12345678'), isNull);
    expect(Validators.password(' password '), isNull);
    expect(Validators.loginPassword('123456'), isNull);
    expect(Validators.loginPassword(''), isNotNull);
  });
  test('confirmation requires exact match', () {
    expect(Validators.confirmPassword('', 'password'), isNotNull);
    expect(Validators.confirmPassword('password ', 'password'), isNotNull);
    expect(Validators.confirmPassword('password', 'password'), isNull);
  });
  test('name follows blueprint boundaries', () {
    expect(Validators.displayName('A'), isNotNull);
    expect(Validators.displayName('AB'), isNull);
    expect(Validators.displayName('a' * 50), isNull);
    expect(Validators.displayName('a' * 51), isNotNull);
  });
}
