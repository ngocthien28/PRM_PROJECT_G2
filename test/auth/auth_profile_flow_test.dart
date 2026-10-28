import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/routing/route_guards.dart';
import 'package:campushub/features/auth/data/auth_repository.dart';
import 'package:campushub/features/auth/data/auth_repository_impl.dart';
import 'package:campushub/features/profile/data/profile_repository_impl.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Auth extends Mock implements FirebaseAuth {}

void main() {
  test(
    'register, load profile, edit, sign out and sign in across module guards',
    () async {
      final sdk = MockFirebaseAuth();
      final firestore = FakeFirebaseFirestore();
      final profiles = ProfileRepositoryImpl(firestore);
      final auth = AuthRepositoryImpl(sdk, profiles);
      final session = StreamIterator(auth.watchUser());
      addTearDown(session.cancel);
      await session.moveNext();
      expect(session.current, isNull);
      await auth.register(' Minh@Example.com ', ' password ', ' Minh ');
      await session.moveNext();
      final identity = session.current!;
      var profile = (await profiles.watchUser(identity.uid).first)!;
      expect(identity.email, 'minh@example.com');
      expect(profile.role.name, 'student');
      expect(
        sessionRedirect(
          path: '/login',
          auth: AsyncData(identity),
          profile: AsyncData(profile),
        ),
        '/home',
      );
      expect(
        sessionRedirect(
          path: '/organizer/events/create',
          auth: AsyncData(identity),
          profile: AsyncData(profile),
        ),
        '/home',
      );
      await profiles.updateProfile(
        uid: identity.uid,
        displayName: 'Updated name',
        phone: '+84901234567',
      );
      profile = (await profiles.watchUser(identity.uid).first)!;
      expect(profile.displayName, 'Updated name');
      expect(profile.phone, '+84901234567');
      await auth.signOut();
      await session.moveNext();
      expect(session.current, isNull);
      expect(
        sessionRedirect(
          path: '/profile/edit',
          auth: const AsyncData<AuthIdentity?>(null),
          profile: AsyncData(profile),
        ),
        '/login',
      );
      expect(
        (await firestore.collection('users').doc(identity.uid).get()).exists,
        isTrue,
      );
      await auth.signIn(' Minh@Example.com ', ' password ');
      await session.moveNext();
      expect(session.current, isNotNull);
    },
  );

  test(
    'login maps rejected credentials and preserves password whitespace',
    () async {
      final sdk = _Auth();
      when(
        () => sdk.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));
      final auth = AuthRepositoryImpl(
        sdk,
        ProfileRepositoryImpl(FakeFirebaseFirestore()),
      );
      await expectLater(
        auth.signIn(' Minh@Example.com ', ' password '),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'invalid-credential',
          ),
        ),
      );
      verify(
        () => sdk.signInWithEmailAndPassword(
          email: 'minh@example.com',
          password: ' password ',
        ),
      ).called(1);
    },
  );

  test(
    'password reset maps network failure to a recoverable message',
    () async {
      final sdk = _Auth();
      when(
        () => sdk.sendPasswordResetEmail(email: any(named: 'email')),
      ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));
      final auth = AuthRepositoryImpl(
        sdk,
        ProfileRepositoryImpl(FakeFirebaseFirestore()),
      );
      await expectLater(
        auth.resetPassword(' Minh@Example.com '),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Check your connection'),
          ),
        ),
      );
      verify(
        () => sdk.sendPasswordResetEmail(email: 'minh@example.com'),
      ).called(1);
    },
  );
}
