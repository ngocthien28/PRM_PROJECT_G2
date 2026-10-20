import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/auth/data/auth_repository.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/profile/data/profile_repository.dart';
import 'package:campushub/shared/enums/user_role.dart';

AppUser testUser({
  String uid = 'uid',
  UserRole role = UserRole.student,
  String status = 'active',
}) => AppUser(
  uid: uid,
  email: '$uid@example.com',
  displayName: 'Minh',
  role: role,
  status: status,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
const testIdentity = AuthIdentity(
  uid: 'uid',
  email: 'uid@example.com',
  displayName: 'Minh',
);

class FakeProfiles implements ProfileRepository {
  final users = <String, AppUser>{};
  final changes = StreamController<String>.broadcast();
  Object? failure;
  int creates = 0;
  @override
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String phone,
  }) async {}
  @override
  Future<void> updateAvatar({
    required String uid,
    required String avatarUrl,
  }) async {}
  @override
  Stream<AppUser?> watchUser(String uid) async* {
    if (failure != null) throw failure!;
    yield users[uid];
    yield* changes.stream.where((id) => id == uid).map((_) => users[uid]);
  }

  @override
  Future<void> ensureInitialProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    creates++;
    if (failure != null) throw failure!;
    users.putIfAbsent(uid, () => testUser(uid: uid));
    changes.add(uid);
  }

  void update(AppUser user) {
    users[user.uid] = user;
    changes.add(user.uid);
  }

  Future<void> dispose() => changes.close();
}

class FakeAuth implements AuthRepository {
  final FakeProfiles profiles;
  final changes = StreamController<AuthIdentity?>.broadcast();
  AuthIdentity? identity;
  Object? failure;
  Completer<void>? pending;
  int calls = 0;
  String? lastEmail;
  String? lastPassword;
  FakeAuth(this.profiles);
  @override
  Stream<AuthIdentity?> watchUser() async* {
    yield identity;
    yield* changes.stream;
  }

  void emit(AuthIdentity? value) {
    identity = value;
    changes.add(value);
  }

  Future<void> request() async {
    calls++;
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> signIn(String email, String password) async {
    lastEmail = email;
    lastPassword = password;
    await request();
    emit(testIdentity);
  }

  @override
  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    await request();
    emit(testIdentity);
    try {
      await profiles.ensureInitialProfile(
        uid: 'uid',
        email: email,
        displayName: displayName,
      );
    } catch (error) {
      throw AppException(
        'Your account was created, but profile setup failed.',
        code: 'profile-create-failed',
        cause: error,
      );
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    lastEmail = email;
    await request();
  }

  @override
  Future<void> signOut() async {
    await request();
    emit(null);
  }

  Future<void> dispose() => changes.close();
}
