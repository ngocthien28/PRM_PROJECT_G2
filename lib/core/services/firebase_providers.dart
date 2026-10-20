import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/data/profile_repository_impl.dart';
import '../../features/registration/data/registration_repository.dart';
import '../../features/registration/data/registration_repository_impl.dart';
import '../../local/dao/ticket_dao.dart';
import '../../features/clubs/data/club_repository.dart';
import '../../features/clubs/data/club_repository_impl.dart';
import 'club_logo_service.dart';
import 'cloudinary_club_logo_service.dart';
import '../../features/auth/data/models/app_user.dart';
import '../errors/app_exception.dart';

final firebaseInitializationProvider = FutureProvider<void>((ref) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stack) {
    debugPrint('Firebase initialization failed: ${error.runtimeType}\n$stack');
    rethrow;
  }
});
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

// Fresh authenticated context for security-sensitive repository actions.
final authenticatedActorProvider = Provider<Future<AppUser?> Function()>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  return () async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return null;
    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    if (auth.currentUser?.uid != uid || !snapshot.exists) return null;
    final actor = AppUser.fromMap(snapshot.data()!);
    if (actor.uid != uid) {
      throw const AppException(
        'Your session is invalid. Please sign in again.',
        code: 'unauthenticated',
      );
    }
    return actor;
  };
});
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(firestoreProvider)),
);
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(profileRepositoryProvider),
  ),
);

final registrationRepositoryProvider = Provider<RegistrationRepository>(
  (ref) => RegistrationRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(ticketDaoProvider),
    ref.watch(authenticatedActorProvider),
  ),
);

final clubLogoServiceProvider = Provider<ClubLogoService>(
  (_) => CloudinaryClubLogoService(),
);
final clubRepositoryProvider = Provider<ClubRepository>(
  (ref) => ClubRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(clubLogoServiceProvider),
  ),
);
