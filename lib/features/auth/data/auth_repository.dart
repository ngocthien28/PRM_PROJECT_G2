class AuthIdentity {
  final String uid;
  final String email;
  final String? displayName;
  const AuthIdentity({
    required this.uid,
    required this.email,
    this.displayName,
  });
}

abstract class AuthRepository {
  Stream<AuthIdentity?> watchUser();
  Future<void> signIn(String email, String password);
  Future<void> register(String email, String password, String displayName);
  Future<void> resetPassword(String email);
  Future<void> signOut();
}
