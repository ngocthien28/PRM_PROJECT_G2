import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/auth/data/auth_repository_impl.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/profile/data/profile_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'auth_fakes.dart';

class MockAuth extends Mock implements FirebaseAuth {}

class MockAuthUser extends Mock implements User {}

void main() {
  for (final code in [
    'invalid-user-token',
    'user-token-expired',
    'user-not-found',
  ]) {
    test('restored $code session signs out and returns to login', () async {
      final auth = MockAuth();
      final user = MockAuthUser();
      final profiles = FakeProfiles();
      addTearDown(profiles.dispose);
      when(() => auth.currentUser).thenReturn(user);
      when(user.reload).thenThrow(FirebaseAuthException(code: code));
      when(auth.signOut).thenAnswer((_) async {});
      when(auth.userChanges).thenAnswer((_) => Stream.value(null));

      expect(
        await AuthRepositoryImpl(auth, profiles).watchUser().first,
        isNull,
      );
      verify(auth.signOut).called(1);
      expect(profiles.creates, 0);
    });
  }

  test(
    'network failure while restoring a session preserves the session',
    () async {
      final auth = MockAuth();
      final user = MockAuthUser();
      final profiles = FakeProfiles();
      addTearDown(profiles.dispose);
      when(() => auth.currentUser).thenReturn(user);
      when(
        user.reload,
      ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));
      await expectLater(
        AuthRepositoryImpl(auth, profiles).watchUser().first,
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'network-request-failed',
          ),
        ),
      );
      verifyNever(auth.signOut);
    },
  );

  test('restored disabled account fails before profile access', () async {
    final auth = MockAuth();
    final user = MockAuthUser();
    final profiles = FakeProfiles();
    when(() => auth.currentUser).thenReturn(user);
    when(user.reload).thenThrow(FirebaseAuthException(code: 'user-disabled'));
    await expectLater(
      AuthRepositoryImpl(auth, profiles).watchUser().first,
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'user-disabled'),
      ),
    );
    expect(profiles.creates, 0);
    await profiles.dispose();
  });
  test(
    'unidentified restore failure offers recovery without signing out',
    () async {
      final auth = MockAuth();
      final user = MockAuthUser();
      final profiles = FakeProfiles();
      addTearDown(profiles.dispose);
      when(() => auth.currentUser).thenReturn(user);
      when(user.reload).thenThrow(FirebaseAuthException(code: 'unknown-error'));
      await expectLater(
        AuthRepositoryImpl(auth, profiles).watchUser().first,
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('saved session'),
          ),
        ),
      );
      verifyNever(auth.signOut);
    },
  );
  test(
    'profile creation writes agreed schema and never stores a password',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = ProfileRepositoryImpl(db);
      await repo.ensureInitialProfile(
        uid: 'uid',
        email: ' Minh@Example.com ',
        displayName: ' Minh ',
      );
      final data = (await db.collection('users').doc('uid').get()).data()!;
      expect(
        data.keys,
        unorderedEquals([
          'uid',
          'email',
          'displayName',
          'avatarUrl',
          'role',
          'status',
          'createdAt',
          'updatedAt',
        ]),
      );
      expect(data['email'], 'minh@example.com');
      expect(data['role'], 'student');
      expect(data['status'], 'active');
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['displayName'], 'Minh');
      final user = await repo.watchUser('uid').first;
      expect(user?.uid, 'uid');
      expect(AppUser.fromMap(user!.toMap()).role, user.role);
    },
  );
  test(
    'recovery does not overwrite existing elevated or disabled profile',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = ProfileRepositoryImpl(db);
      final doc = db.collection('users').doc('uid');
      await doc.set({
        ...testUser().toMap(),
        'role': 'admin',
        'status': 'disabled',
      });
      final before = (await doc.get()).data();
      await repo.ensureInitialProfile(
        uid: 'uid',
        email: 'new@example.com',
        displayName: 'Other',
      );
      expect((await doc.get()).data(), before);
    },
  );
  test('missing profile and invalid role fail closed', () async {
    final db = FakeFirebaseFirestore();
    final repo = ProfileRepositoryImpl(db);
    expect(await repo.watchUser('missing').first, isNull);
    await db.collection('users').doc('uid').set({
      ...testUser().toMap(),
      'role': 'superadmin',
    });
    await expectLater(
      repo.watchUser('uid').first,
      throwsA(isA<AppException>()),
    );
  });
  test('Firebase registration creates initial profile', () async {
    final auth = MockFirebaseAuth();
    final db = FakeFirebaseFirestore();
    final repo = AuthRepositoryImpl(auth, ProfileRepositoryImpl(db));
    await repo.register(' Minh@Example.com ', ' password ', 'Minh');
    expect(auth.currentUser?.email, 'minh@example.com');
    expect(auth.currentUser?.displayName, 'Minh');
    final profile =
        (await db.collection('users').doc(auth.currentUser!.uid).get()).data()!;
    expect(profile['role'], 'student');
    expect(profile['uid'], auth.currentUser!.uid);
    await repo.signOut();
    expect(auth.currentUser, isNull);
    expect(
      (await db.collection('users').doc(profile['uid']).get()).exists,
      isTrue,
    );
  });
  test(
    'Firestore failure after real repository registration is recoverable',
    () async {
      final auth = MockFirebaseAuth();
      final profiles = FakeProfiles();
      profiles.failure = const AppException('Server unavailable.');
      final repo = AuthRepositoryImpl(auth, profiles);
      await expectLater(
        repo.register('minh@example.com', 'password', 'Minh'),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'profile-create-failed',
          ),
        ),
      );
      expect(auth.currentUser, isNotNull);
      profiles.failure = null;
      await profiles.ensureInitialProfile(
        uid: auth.currentUser!.uid,
        email: auth.currentUser!.email!,
        displayName: auth.currentUser!.displayName!,
      );
      expect(profiles.users[auth.currentUser!.uid], isNotNull);
      await profiles.dispose();
    },
  );
  test(
    'login normalizes email, preserves password and maps auth errors',
    () async {
      final auth = MockAuth();
      final profiles = FakeProfiles();
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));
      final repo = AuthRepositoryImpl(auth, profiles);
      await expectLater(
        repo.signIn(' Minh@Example.com ', ' password '),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Email or password is incorrect.',
          ),
        ),
      );
      verify(
        () => auth.signInWithEmailAndPassword(
          email: 'minh@example.com',
          password: ' password ',
        ),
      ).called(1);
      await profiles.dispose();
    },
  );
  test('reset uses Firebase email API and maps network error', () async {
    final auth = MockAuth();
    final profiles = FakeProfiles();
    when(
      () => auth.sendPasswordResetEmail(email: any(named: 'email')),
    ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));
    await expectLater(
      AuthRepositoryImpl(auth, profiles).resetPassword(' Minh@Example.com '),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          'network-request-failed',
        ),
      ),
    );
    verify(
      () => auth.sendPasswordResetEmail(email: 'minh@example.com'),
    ).called(1);
    await profiles.dispose();
  });
}
