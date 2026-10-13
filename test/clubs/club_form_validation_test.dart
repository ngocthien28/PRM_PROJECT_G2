import 'package:campushub/features/clubs/presentation/viewmodels/club_form_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Club form validation', () {
    test('name accepts 3-80 trimmed characters', () {
      expect(ClubFormValidators.name('ab'), isNotNull);
      expect(ClubFormValidators.name(' abc '), isNull);
      expect(ClubFormValidators.name('a' * 81), isNotNull);
    });

    test('description accepts 20-1000 trimmed characters', () {
      expect(ClubFormValidators.description('a' * 19), isNotNull);
      expect(ClubFormValidators.description(' ${'a' * 20} '), isNull);
      expect(ClubFormValidators.description('a' * 1001), isNotNull);
    });
  });
}
