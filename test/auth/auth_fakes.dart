import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/auth/data/auth_repository.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/profile/data/profile_repository.dart';
import 'package:campushub/features/profile/data/local_profile_cache.dart';
import 'package:campushub/shared/enums/user_role.dart';

/// FEATURE: UC-014 - Test Authentication and Profile
/// MODULE: Testing & Integration
/// DESCRIPTION: Hàm AppUser testUser: Fixture identity, profile stream, cache và lỗi.
/// ROLE: Test entry point / fixture helper
/// CALLED FROM: Các test Auth/Profile/navigation.
/// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
/// TECHNOLOGY: Dart.
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

class FakeLocalProfileCache extends LocalProfileCache {
  final users = <String, AppUser>{};

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;AppUser?&gt; readProfile: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
  @override
  Future<AppUser?> readProfile(String uid) async => users[uid];

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; saveProfile: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
  @override
  Future<void> saveProfile(AppUser user) async {
    users[user.uid] = user;
  }
}

class FakeProfiles implements ProfileRepository {
  final users = <String, AppUser>{};
  final changes = StreamController<String>.broadcast();
  Object? failure;
  int creates = 0;
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; updateProfile: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
  @override
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String phone,
  }) async {}
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; updateAvatar: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
  @override
  Future<void> updateAvatar({
    required String uid,
    required String avatarUrl,
  }) async {}
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Stream&lt;AppUser?&gt; watchUser: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
  @override
  Stream<AppUser?> watchUser(String uid) async* {
    if (failure != null) throw failure!;
    yield users[uid];
    yield* changes.stream.where((id) => id == uid).map((_) => users[uid]);
  }

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; ensureInitialProfile: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
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

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm void update: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
  void update(AppUser user) {
    users[user.uid] = user;
    changes.add(user.uid);
  }

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; dispose: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
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
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Stream&lt;AuthIdentity?&gt; watchUser: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
  @override
  Stream<AuthIdentity?> watchUser() async* {
    yield identity;
    yield* changes.stream;
  }

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm void emit: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
  void emit(AuthIdentity? value) {
    identity = value;
    changes.add(value);
  }

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; request: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
  Future<void> request() async {
    calls++;
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
  }

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; signIn: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
  @override
  Future<void> signIn(String email, String password) async {
    lastEmail = email;
    lastPassword = password;
    await request();
    emit(testIdentity);
  }

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; register: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
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

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; resetPassword: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
  @override
  Future<void> resetPassword(String email) async {
    lastEmail = email;
    await request();
  }

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; signOut: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
  @override
  Future<void> signOut() async {
    await request();
    emit(null);
  }

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; dispose: Fixture identity, profile stream, cache và lỗi.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart.
  Future<void> dispose() => changes.close();
}
