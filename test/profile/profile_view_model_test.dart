import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/auth/data/auth_repository.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/profile/data/profile_repository.dart';
import 'package:campushub/features/profile/presentation/viewmodels/profile_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _Profiles extends Mock implements ProfileRepository {}

class _Picker extends Mock implements ImagePicker {}

void main() {
  late ProviderContainer container;
  late _Profiles profiles;
  late _Picker picker;
  late StreamController<AuthIdentity?> sessions;

  setUp(() async {
    profiles = _Profiles();
    picker = _Picker();
    sessions = StreamController<AuthIdentity?>();
    container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => sessions.stream),
        profileRepositoryProvider.overrideWithValue(profiles),
        profileImagePickerProvider.overrideWithValue(picker),
      ],
    );
    container.listen(authStateProvider, (_, _) {});
    container.listen(profileActionProvider, (_, _) {});
    final ready = container.read(authStateProvider.future);
    sessions.add(const AuthIdentity(uid: 'u1', email: 'user@example.com'));
    await ready;
  });

  tearDown(() async {
    container.dispose();
    await sessions.close();
  });

  test('duplicate saves are suppressed and success is reported', () async {
    final pending = Completer<void>();
    when(
      () => profiles.updateProfile(uid: 'u1', displayName: 'Minh', phone: ''),
    ).thenAnswer((_) => pending.future);
    final vm = container.read(profileActionProvider.notifier);
    final saving = vm.updateProfile('Minh', '');
    expect(container.read(profileActionProvider).isLoading, isTrue);
    await vm.updateProfile('Minh', '');
    verify(
      () => profiles.updateProfile(uid: 'u1', displayName: 'Minh', phone: ''),
    ).called(1);
    pending.complete();
    await saving;
    expect(
      container.read(profileActionProvider).requireValue,
      'Profile updated.',
    );
  });

  test('invalid input is rejected before a repository write', () async {
    await container
        .read(profileActionProvider.notifier)
        .updateProfile('', 'invalid');
    expect(container.read(profileActionProvider).hasError, isTrue);
    verifyNever(
      () => profiles.updateProfile(
        uid: any(named: 'uid'),
        displayName: any(named: 'displayName'),
        phone: any(named: 'phone'),
      ),
    );
  });

  test('repository failure becomes readable feedback', () async {
    when(
      () => profiles.updateProfile(uid: 'u1', displayName: 'Minh', phone: ''),
    ).thenThrow(const AppException('Check your connection.'));
    await container
        .read(profileActionProvider.notifier)
        .updateProfile('Minh', '');
    expect(
      container.read(profileActionProvider).error.toString(),
      'Check your connection.',
    );
  });

  test(
    'cancelling avatar selection clears loading and makes no profile write',
    () async {
      when(
        () => picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1200,
        ),
      ).thenAnswer((_) async => null);
      await container.read(profileActionProvider.notifier).chooseAvatar();
      expect(container.read(profileActionProvider).isLoading, isFalse);
      expect(container.read(profileActionProvider).requireValue, isNull);
      verifyNever(
        () => profiles.updateAvatar(
          uid: any(named: 'uid'),
          avatarUrl: any(named: 'avatarUrl'),
        ),
      );
    },
  );

  test(
    'a completed save cannot publish feedback into a different account',
    () async {
      final pending = Completer<void>();
      when(
        () => profiles.updateProfile(uid: 'u1', displayName: 'Minh', phone: ''),
      ).thenAnswer((_) => pending.future);
      final saving = container
          .read(profileActionProvider.notifier)
          .updateProfile('Minh', '');
      sessions.add(const AuthIdentity(uid: 'u2', email: 'other@example.com'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(profileActionProvider).asData?.value, isNull);
      pending.complete();
      await saving;
      expect(container.read(profileActionProvider).requireValue, isNull);
    },
  );
}
