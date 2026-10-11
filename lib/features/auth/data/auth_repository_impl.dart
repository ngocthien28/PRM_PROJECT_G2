import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_mapper.dart';
import '../../profile/data/profile_repository.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth auth;
  final ProfileRepository profiles;
  AuthRepositoryImpl(this.auth, this.profiles);
  @override
  Stream<AuthIdentity?> watchUser() async* {
    try {
      // Validate restored sessions, including accounts disabled on the server.
      // Reload once before listening, avoiding a userChanges/reload loop.
      final restoredUser = auth.currentUser;
      if (restoredUser != null) await restoredUser.reload();
      await for (final user in auth.userChanges()) {
        yield user == null
            ? null
            : AuthIdentity(
                uid: user.uid,
                email: user.email ?? '',
                displayName: user.displayName,
              );
      }
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  Future<void> _request(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> signIn(String email, String password) => _request(() async {
    await auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  });
  @override
  Future<void> register(
    String email,
    String password,
    String displayName,
  ) => _request(() async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = credential.user!;
    try {
      await user.updateDisplayName(displayName.trim());
      await profiles.ensureInitialProfile(
        uid: user.uid,
        email: user.email!,
        displayName: displayName,
      );
    } catch (error, stack) {
      final failure = mapError(error, stack);
      // Auth + Firestore are not atomic. Retain the account for idempotent retry.
      throw AppException(
        'Your account was created, but profile setup failed. '
        'Retry profile setup or sign in again later. ${failure.message}',
        code: 'profile-create-failed',
        cause: failure,
      );
    }
  });
  @override
  Future<void> resetPassword(String email) => _request(
    () => auth.sendPasswordResetEmail(email: email.trim().toLowerCase()),
  );
  @override
  Future<void> signOut() => _request(auth.signOut);
}
