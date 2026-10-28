import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/event_poster_service.dart';
import '../../data/cloudinary_event_poster_service.dart';
import '../../data/models/event_form_input.dart';
import '../../data/emulator_event_poster_service.dart';

final eventPosterPickerProvider = Provider<EventPosterPicker>(
  (ref) => EventPosterPicker(),
);

final eventPosterServiceProvider = Provider<EventPosterService>((ref) {
  if (const bool.fromEnvironment('USE_FIREBASE_EMULATOR')) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final service = EmulatorEventPosterService(
        bucket: Firebase.app().options.storageBucket!,
        idToken: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
        host: const String.fromEnvironment(
          'FIREBASE_EMULATOR_HOST',
          defaultValue: '127.0.0.1',
        ),
        onProgress: (progress) {
          if (ref.mounted) {
            ref.read(eventPosterProgressProvider.notifier).report(progress);
          }
        },
      );
      ref.onDispose(service.close);
      return service;
    }
    return FirebaseEventPosterService(
      FirebaseStorage.instance,
      onProgress: (progress) {
        if (ref.mounted) {
          ref.read(eventPosterProgressProvider.notifier).report(progress);
        }
      },
    );
  }
  final service = CloudinaryEventPosterService(
    onProgress: (progress) {
      if (ref.mounted) {
        ref.read(eventPosterProgressProvider.notifier).report(progress);
      }
    },
  );
  ref.onDispose(service.close);
  return service;
});

final eventPosterProgressProvider =
    NotifierProvider<EventPosterProgress, double?>(EventPosterProgress.new);

class EventPosterProgress extends Notifier<double?> {
  @override
  double? build() => null;
  void report(double? progress) => state = progress;
}

class EventPosterState {
  const EventPosterState({this.selection, this.selecting = false, this.error});
  final EventPosterSelection? selection;
  final bool selecting;
  final String? error;
}

final eventPosterViewModelProvider =
    NotifierProvider.autoDispose<EventPosterViewModel, EventPosterState>(
      EventPosterViewModel.new,
    );

class EventPosterViewModel extends Notifier<EventPosterState> {
  @override
  EventPosterState build() => const EventPosterState();

  Future<void> select() async {
    if (state.selecting) return;
    final previous = state.selection;
    state = EventPosterState(selection: previous, selecting: true);
    try {
      final selected = await ref.read(eventPosterPickerProvider).pick();
      if (!ref.mounted) return;
      state = EventPosterState(selection: selected ?? previous);
    } catch (error) {
      if (!ref.mounted) return;
      final message = error is AppException
          ? error.message
          : error is PlatformException && error.code.contains('denied')
          ? 'Photo access was denied. Allow access in device settings and try again.'
          : 'Could not open this image. Choose another poster or try again.';
      state = EventPosterState(selection: previous, error: message);
    }
  }
}
