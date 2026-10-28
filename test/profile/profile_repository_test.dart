import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/profile/data/profile_repository_impl.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProfileRepositoryImpl repository;
  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ProfileRepositoryImpl(firestore);
  });

  test(
    'profile setup creates an active student and preserves existing roles',
    () async {
      await repository.ensureInitialProfile(
        uid: 'u1',
        email: ' User@Example.com ',
        displayName: ' Minh ',
      );
      final doc = firestore.collection('users').doc('u1');
      var data = (await doc.get()).data()!;
      expect(data['role'], 'student');
      expect(data['status'], 'active');
      expect(data['email'], 'user@example.com');
      expect(data['displayName'], 'Minh');
      await doc.update({'role': 'admin', 'status': 'disabled'});
      await repository.ensureInitialProfile(
        uid: 'u1',
        email: 'other@example.com',
        displayName: 'Other',
      );
      data = (await doc.get()).data()!;
      expect(data['role'], 'admin');
      expect(data['status'], 'disabled');
      expect(data['displayName'], 'Minh');
    },
  );

  test(
    'editing name, phone and avatar preserves authorization fields and other users',
    () async {
      for (final uid in ['u1', 'u2']) {
        await firestore
            .collection('users')
            .doc(uid)
            .set(
              AppUser(
                uid: uid,
                email: '$uid@example.com',
                displayName: 'Original',
                role: UserRole.organizer,
                status: 'active',
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
              ).toMap(),
            );
      }
      await repository.updateProfile(
        uid: 'u1',
        displayName: ' Updated ',
        phone: ' 0901234567 ',
      );
      await repository.updateAvatar(
        uid: 'u1',
        avatarUrl: 'https://example.com/avatar.png',
      );
      final updated = (await firestore.collection('users').doc('u1').get())
          .data()!;
      expect(updated['displayName'], 'Updated');
      expect(updated['phone'], '0901234567');
      expect(updated['avatarUrl'], 'https://example.com/avatar.png');
      expect(updated['role'], 'organizer');
      expect(updated['status'], 'active');
      expect((await repository.watchUser('u2').first)!.displayName, 'Original');
      await repository.updateProfile(
        uid: 'u1',
        displayName: 'Updated',
        phone: ' ',
      );
      expect((await repository.watchUser('u1').first)!.phone, isNull);
    },
  );

  test('missing and mismatched profiles fail safely', () async {
    expect(await repository.watchUser('missing').first, isNull);
    await firestore
        .collection('users')
        .doc('u1')
        .set(
          AppUser(
            uid: 'another-user',
            email: 'user@example.com',
            displayName: 'Wrong profile',
            role: UserRole.admin,
            status: 'active',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ).toMap(),
        );
    await expectLater(
      repository.watchUser('u1').first,
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'invalid-profile',
        ),
      ),
    );
  });
}
