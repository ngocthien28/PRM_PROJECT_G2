import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
import 'storage_service.dart';

/// FEATURE: UC-002 - Configure Firebase Authentication and Auth State
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Khởi tạo Firebase theo cấu hình nền tảng; cấu hình demo project và host SDK khi bật emulator.
/// ROLE: Riverpod dependency injection
/// CALLED FROM: Các provider hoặc view model phụ thuộc firebaseInitializationProvider.
/// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod, Firebase Auth SDK, Firebase Core, Cloud Firestore SDK, Firebase Storage SDK.
final firebaseInitializationProvider = FutureProvider<void>((ref) async {
  try {
    const useEmulator = bool.fromEnvironment(
      'USE_FIREBASE_EMULATOR',
      defaultValue: false,
    );
    final platform = DefaultFirebaseOptions.currentPlatform;
    // Match the project/bucket used by the existing demo seed and CLI. Merely
    // changing hosts leaves Auth and Firestore in different emulator projects.
    const emulatorProject = String.fromEnvironment(
      'FIREBASE_EMULATOR_PROJECT_ID',
      defaultValue: 'demo-campushub',
    );
    if (useEmulator && !emulatorProject.startsWith('demo-')) {
      throw StateError('Emulator mode requires a demo- project ID.');
    }
    await Firebase.initializeApp(
      options: useEmulator
          ? FirebaseOptions(
              apiKey: platform.apiKey,
              appId: platform.appId,
              messagingSenderId: platform.messagingSenderId,
              projectId: emulatorProject,
              storageBucket: '$emulatorProject.appspot.com',
            )
          : platform,
    );
    if (useEmulator) {
      const host = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      );
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8087);
      // Windows posters use an authenticated emulator HTTP transport because
      // firebase_storage's Windows SDK ignores useStorageEmulator.
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
        await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      }
    }
  } catch (error, stack) {
    debugPrint('Firebase initialization failed: ${error.runtimeType}\n$stack');
    rethrow;
  }
});
/// FEATURE: UC-002 - Configure Firebase Authentication and Auth State
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Cung cấp FirebaseAuth.instance cho AuthRepositoryImpl.
/// ROLE: Riverpod dependency injection
/// CALLED FROM: Các provider hoặc view model phụ thuộc firebaseAuthProvider.
/// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod, Firebase Auth SDK, Firebase Core, Cloud Firestore SDK, Firebase Storage SDK.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);
/// FEATURE: UC-002, UC-008, UC-009, UC-010
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Cung cấp FirebaseFirestore.instance cho repository profile và resolver actor.
/// ROLE: Riverpod dependency injection
/// CALLED FROM: Các provider hoặc view model phụ thuộc firestoreProvider.
/// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod, Firebase Auth SDK, Firebase Core, Cloud Firestore SDK, Firebase Storage SDK.
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

// Fresh authenticated context for security-sensitive repository actions.
/// FEATURE: UC-002, UC-015
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Đọc UID Auth và profile từ Firestore Source.server; kiểm tra UID trước khi cung cấp actor cho Event/Registration.
/// ROLE: Riverpod dependency injection
/// CALLED FROM: Các provider hoặc view model phụ thuộc authenticatedActorProvider.
/// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod, Firebase Auth SDK, Firebase Core, Cloud Firestore SDK, Firebase Storage SDK.
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
/// FEATURE: UC-002, UC-004, UC-008, UC-009, UC-010
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Tiêm ProfileRepositoryImpl dùng Firestore SDK cho auth và profile state.
/// ROLE: Riverpod dependency injection
/// CALLED FROM: Các provider hoặc view model phụ thuộc profileRepositoryProvider.
/// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod, Firebase Auth SDK, Firebase Core, Cloud Firestore SDK, Firebase Storage SDK.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(firestoreProvider)),
);
/// FEATURE: UC-010 - Update Profile Avatar
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Tiêm StorageService dùng FirebaseStorage.instance cho upload avatar.
/// ROLE: Riverpod dependency injection
/// CALLED FROM: Các provider hoặc view model phụ thuộc storageServiceProvider.
/// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod, Firebase Auth SDK, Firebase Core, Cloud Firestore SDK, Firebase Storage SDK.
final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(FirebaseStorage.instance),
);
/// FEATURE: UC-002, UC-004, UC-005, UC-006, UC-007
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Ghép FirebaseAuth và ProfileRepository thành AuthRepositoryImpl.
/// ROLE: Riverpod dependency injection
/// CALLED FROM: Các provider hoặc view model phụ thuộc authRepositoryProvider.
/// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod, Firebase Auth SDK, Firebase Core, Cloud Firestore SDK, Firebase Storage SDK.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(profileRepositoryProvider),
  ),
);

/// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
/// MODULE: Testing & Integration
/// DESCRIPTION: Tiêm resolver actor xác thực để RegistrationRepositoryImpl kiểm tra quyền.
/// ROLE: Riverpod dependency injection
/// CALLED FROM: Các provider hoặc view model phụ thuộc registrationRepositoryProvider.
/// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod, Firebase Auth SDK, Firebase Core, Cloud Firestore SDK, Firebase Storage SDK.
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
