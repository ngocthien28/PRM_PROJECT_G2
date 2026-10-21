import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/events/presentation/widgets/event_poster.dart';
import 'package:campushub/features/organizer_events/data/event_poster_service.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/features/organizer_events/presentation/screens/event_form_screen.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/event_poster_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'poster_fixtures.dart';

class FakePicker extends EventPosterPicker {
  EventPosterSelection? result = posterSelection();
  Object? failure;
  @override
  Future<EventPosterSelection?> pick() async {
    if (failure != null) throw failure!;
    return result;
  }
}

void main() {
  late FakePicker picker;
  late ProviderContainer container;
  setUp(() {
    picker = FakePicker();
    container = ProviderContainer(
      overrides: [eventPosterPickerProvider.overrideWithValue(picker)],
    );
  });
  tearDown(() => container.dispose());
  Future<void> mount(
    WidgetTester t, {
    EventFormSubmitCallback? save,
    VoidCallback? success,
  }) async {
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: EventFormScreen(
            initialValue: EventFormInput(
              title: 'Workshop',
              description: 'A practical workshop for campus students.',
              category: 'technology',
              locationName: 'Hall A',
              startAt: DateTime(2030),
              endAt: DateTime(2030, 1, 1, 2),
              capacity: 80,
            ),
            existingPosterUrl: 'https://example.invalid/old.png',
            onSubmit: save ?? (_) async {},
            onSuccess: success,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, String key) async {
    final target = find.byKey(Key(key));
    await t.ensureVisible(target);
    await t.pump();
    await t.tap(target);
    await t.pump();
  }

  testWidgets(
    'edit shows current poster; selection previews and retains other fields',
    (t) async {
      EventFormInput? submitted;
      await mount(
        t,
        save: (input) async {
          submitted = input;
        },
      );
      expect(
        t.widget<EventPoster>(find.byType(EventPoster)).url,
        'https://example.invalid/old.png',
      );
      await tap(t, 'selectPosterButton');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('posterPreview')), findsOneWidget);
      expect(find.byType(EventPoster), findsNothing);
      await tap(t, 'submitEventFormButton');
      await t.pumpAndSettle();
      expect(submitted!.posterSelection, same(picker.result));
      expect(submitted!.title, 'Workshop');
    },
  );
  testWidgets('cancel picker retains existing poster and a prior selection', (
    t,
  ) async {
    picker.result = null;
    await mount(t);
    await tap(t, 'selectPosterButton');
    await t.pumpAndSettle();
    expect(find.byType(EventPoster), findsOneWidget);
    picker.result = posterSelection();
    await tap(t, 'selectPosterButton');
    await t.pumpAndSettle();
    final previous = container.read(eventPosterViewModelProvider).selection;
    picker.result = null;
    await tap(t, 'selectPosterButton');
    await t.pumpAndSettle();
    expect(
      container.read(eventPosterViewModelProvider).selection,
      same(previous),
    );
    expect(find.byKey(const Key('posterPreview')), findsOneWidget);
  });
  testWidgets(
    'invalid image and denied permission show errors without removing old poster',
    (t) async {
      await mount(t);
      for (final failure in [
        const AppException('Choose a valid image.'),
        PlatformException(code: 'photo_access_denied'),
      ]) {
        picker.failure = failure;
        await tap(t, 'selectPosterButton');
        await t.pumpAndSettle();
        expect(find.byKey(const Key('posterError')), findsOneWidget);
        expect(find.byType(EventPoster), findsOneWidget);
        expect(container.read(eventPosterViewModelProvider).selection, isNull);
      }
    },
  );
  testWidgets(
    'upload progress locks submit and picker until save completes; success fires once',
    (t) async {
      final gate = Completer<void>();
      var calls = 0;
      var successes = 0;
      await mount(
        t,
        save: (_) async {
          calls++;
          container.read(eventPosterProgressProvider.notifier).report(0.4);
          await gate.future;
          container.read(eventPosterProgressProvider.notifier).report(null);
        },
        success: () => successes++,
      );
      await tap(t, 'selectPosterButton');
      await t.pumpAndSettle();
      await tap(t, 'submitEventFormButton');
      expect(
        t
            .widget<FilledButton>(
              find.byKey(const Key('submitEventFormButton')),
            )
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const Key('selectPosterButton')))
            .onPressed,
        isNull,
      );
      expect(find.byKey(const Key('posterUploadProgress')), findsOneWidget);
      expect(successes, 0);
      gate.complete();
      await t.pumpAndSettle();
      expect(calls, 1);
      expect(successes, 1);
    },
  );
  testWidgets(
    'failure retains preview and values; retry uses the same create request',
    (t) async {
      var calls = 0;
      final requests = <String?>[];
      await mount(
        t,
        save: (input) async {
          calls++;
          requests.add(input.createRequestId);
          if (calls == 1) throw const AppException('Upload failed. Try again.');
        },
      );
      await tap(t, 'selectPosterButton');
      await t.pumpAndSettle();
      await tap(t, 'submitEventFormButton');
      await t.pumpAndSettle();
      expect(find.text('Upload failed. Try again.'), findsOneWidget);
      expect(find.byKey(const Key('posterPreview')), findsOneWidget);
      await tap(t, 'submitEventFormButton');
      await t.pumpAndSettle();
      expect(calls, 2);
      expect(requests[0], requests[1]);
    },
  );
}
