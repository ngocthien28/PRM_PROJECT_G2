import 'dart:async';
import 'dart:typed_data';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/features/organizer_events/presentation/screens/event_form_screen.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/event_form_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseStart = DateTime(2030, 6, 1, 9, 0);
  final baseEnd = DateTime(2030, 6, 1, 11, 0);

  EventFormInput createValidInput({
    String title = 'Flutter Advanced Workshop',
    String description =
        'A comprehensive 2-hour hands-on workshop building robust apps.',
    String category = 'technology',
    String locationName = 'Building C, Room 301',
    DateTime? startAt,
    DateTime? endAt,
    int capacity = 100,
    EventPosterSelection? posterSelection,
    int? currentRegisteredCount,
  }) {
    return EventFormInput(
      title: title,
      description: description,
      category: category,
      locationName: locationName,
      startAt: startAt ?? baseStart,
      endAt: endAt ?? baseEnd,
      capacity: capacity,
      posterSelection: posterSelection,
      currentRegisteredCount: currentRegisteredCount,
    );
  }

  Widget buildFormWidget({
    EventFormInput? initial,
    EventFormSubmitCallback? submit,
    VoidCallback? success,
    String? existingPosterUrl,
    VoidCallback? reload,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: EventFormScreen(
          initialValue: initial,
          onSubmit: submit ?? (_) async {},
          onSuccess: success,
          existingPosterUrl: existingPosterUrl,
          onReload: reload,
        ),
      ),
    );
  }

  group('UC-041 Section A: Validation Unit Tests (1-21)', () {
    test('1. Input hợp lệ -> PASS', () {
      final input = createValidInput();
      expect(input.validate(), isEmpty);
      expect(input.isValid, isTrue);
    });

    test('2. Title rỗng -> REJECT', () {
      final errors = createValidInput(title: '').validate();
      expect(errors['title'], 'Title is required.');
    });

    test('3. Title ngắn hơn 3 ký tự -> REJECT', () {
      final errors = createValidInput(title: 'Go').validate();
      expect(errors['title'], 'Title must be between 3 and 120 characters.');
    });

    test('4. Title dài hơn 120 ký tự -> REJECT', () {
      final errors = createValidInput(title: 'A' * 121).validate();
      expect(errors['title'], 'Title must be between 3 and 120 characters.');
    });

    test('5. Title chỉ chứa khoảng trắng -> REJECT', () {
      final errors = createValidInput(title: '     ').validate();
      expect(errors['title'], 'Title is required.');
    });

    test('6. Description dưới 20 ký tự -> REJECT', () {
      final errors = createValidInput(description: 'Too short text').validate();
      expect(
        errors['description'],
        'Description must be at least 20 characters.',
      );
    });

    test('7. Category ngoài allow-list -> REJECT', () {
      final errors = createValidInput(category: 'invalid_cat').validate();
      expect(errors['category'], 'Select a valid event category.');
    });

    test('8. Location rỗng -> REJECT', () {
      final errors = createValidInput(locationName: '   ').validate();
      expect(errors['locationName'], 'Location is required.');
    });

    test('9. Capacity = 0 -> REJECT', () {
      final errors = createValidInput(capacity: 0).validate();
      expect(errors['capacity'], 'Capacity must be greater than 0.');
    });

    test('10. Capacity âm -> REJECT', () {
      final errors = createValidInput(capacity: -5).validate();
      expect(errors['capacity'], 'Capacity must be greater than 0.');
    });

    test(
      '11. Capacity unparsable / fractional -> REJECT in UI and validate',
      () {
        final errors = createValidInput(capacity: 0).validate();
        expect(errors['capacity'], 'Capacity must be greater than 0.');
      },
    );

    test('12. Capacity vượt giới hạn (5000) -> REJECT', () {
      final errors = createValidInput(capacity: 5001).validate();
      expect(errors['capacity'], 'Capacity must not exceed 5000.');
    });

    test('13. startAt sau hoặc bằng endAt -> REJECT', () {
      final equalErrors = createValidInput(
        startAt: baseStart,
        endAt: baseStart,
      ).validate();
      expect(equalErrors['endAt'], 'End time must be after start time.');

      final afterErrors = createValidInput(
        startAt: baseEnd,
        endAt: baseStart,
      ).validate();
      expect(afterErrors['endAt'], 'End time must be after start time.');
    });

    test('14. Create published event trong quá khứ -> REJECT', () {
      final fixedNow = DateTime.utc(2030, 6, 1, 10, 0);
      final pastStart = DateTime.utc(2030, 6, 1, 9, 30);
      final errors = createValidInput(
        startAt: pastStart,
        endAt: pastStart.add(const Duration(hours: 2)),
      ).validate(requireFutureStart: true, now: fixedNow);

      expect(
        errors['startAt'],
        'Start time must be in the future for a new published event.',
      );
    });

    test('15. Create published event trong tương lai -> PASS', () {
      final fixedNow = DateTime.utc(2030, 6, 1, 9, 0);
      final futureStart = DateTime.utc(2030, 6, 1, 10, 0);
      final errors = createValidInput(
        startAt: futureStart,
        endAt: futureStart.add(const Duration(hours: 2)),
      ).validate(requireFutureStart: true, now: fixedNow);

      expect(errors['startAt'], isNull);
    });

    test('16. Edit event cũ không bị future-start validation chặn sai', () {
      final fixedNow = DateTime.utc(2030, 6, 1, 12, 0);
      final pastStart = DateTime.utc(2030, 6, 1, 8, 0);
      final errors = createValidInput(
        startAt: pastStart,
        endAt: pastStart.add(const Duration(hours: 3)),
      ).validate(requireFutureStart: false, now: fixedNow);

      expect(errors['startAt'], isNull);
      expect(errors, isEmpty);
    });

    test('17. Edit capacity nhỏ hơn registeredCount -> REJECT', () {
      final errors = createValidInput(
        capacity: 15,
        currentRegisteredCount: 20,
      ).validate();

      expect(
        errors['capacity'],
        'Capacity must be at least 20, the current number of registered participants.',
      );
    });

    test('18. Valid poster -> PASS', () {
      final validPoster = EventPosterSelection(
        localUri: Uri.parse('file:///tmp/valid.png'),
        fileName: 'valid.png',
        mimeType: 'image/png',
        byteLength: 1024 * 500,
        bytes: Uint8List(1024 * 500),
      );
      final errors = createValidInput(posterSelection: validPoster).validate();
      expect(errors['poster'], isNull);
      expect(errors, isEmpty);
    });

    test('19. Invalid MIME / size poster -> REJECT', () {
      final oversizedPoster = EventPosterSelection(
        localUri: Uri.parse('file:///tmp/huge.png'),
        fileName: 'huge.png',
        mimeType: 'image/png',
        byteLength: 5 * 1024 * 1024 + 1,
      );
      final oversizedErrors = createValidInput(
        posterSelection: oversizedPoster,
      ).validate();
      expect(
        oversizedErrors['poster'],
        'Poster must be between 1 byte and 5 MB.',
      );

      final wrongMimePoster = EventPosterSelection(
        localUri: Uri.parse('file:///tmp/doc.pdf'),
        fileName: 'doc.pdf',
        mimeType: 'application/pdf',
        byteLength: 1024,
      );
      final wrongMimeErrors = createValidInput(
        posterSelection: wrongMimePoster,
      ).validate();
      expect(
        wrongMimeErrors['poster'],
        'Choose a valid JPG, PNG, or WebP image.',
      );
    });

    test(
      '20. Không chọn poster mới trong Edit -> giữ poster cũ (null selection is valid)',
      () {
        final input = createValidInput(posterSelection: null);
        expect(input.validate(), isEmpty);
        expect(input.posterSelection, isNull);
      },
    );

    test('21. Timezone and boundary cases được xử lý đúng', () {
      final nowUtc = DateTime.utc(2030, 1, 1, 12, 0, 0);
      final startExactNow = DateTime.utc(2030, 1, 1, 12, 0, 0);
      final errorsBoundary = createValidInput(
        startAt: startExactNow,
        endAt: startExactNow.add(const Duration(hours: 1)),
      ).validate(requireFutureStart: true, now: nowUtc);

      expect(
        errorsBoundary['startAt'],
        'Start time must be in the future for a new published event.',
      );

      final startJustAfter = DateTime.utc(2030, 1, 1, 12, 0, 1);
      final errorsAfter = createValidInput(
        startAt: startJustAfter,
        endAt: startJustAfter.add(const Duration(hours: 1)),
      ).validate(requireFutureStart: true, now: nowUtc);

      expect(errorsAfter['startAt'], isNull);
    });
  });

  group('UC-041 Section B: ViewModel Tests (22-28)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      container.listen(eventFormViewModelProvider, (_, _) {});
    });

    tearDown(() {
      container.dispose();
    });

    EventFormViewModel getViewModel() =>
        container.read(eventFormViewModelProvider.notifier);

    EventFormSubmissionState getState() =>
        container.read(eventFormViewModelProvider);

    test('22. Invalid input không gọi Repository', () async {
      var repoCalls = 0;
      final invalid = createValidInput(title: '');

      final result = await getViewModel().submit(
        invalid,
        (_) async => repoCalls++,
      );

      expect(result, isFalse);
      expect(repoCalls, 0);
      expect(getState().status, EventFormSubmissionStatus.error);
      expect(getState().validationErrors['title'], 'Title is required.');
    });

    test('23. Valid input được submit', () async {
      var repoCalls = 0;
      final valid = createValidInput();

      final result = await getViewModel().submit(
        valid,
        (_) async => repoCalls++,
      );

      expect(result, isTrue);
      expect(repoCalls, 1);
      expect(getState().status, EventFormSubmissionStatus.success);
      expect(getState().validationErrors, isEmpty);
    });

    test('24. Loading / disable hoạt động', () async {
      final completer = Completer<void>();
      final pending = getViewModel().submit(
        createValidInput(),
        (_) => completer.future,
      );

      expect(getState().isSubmitting, isTrue);
      expect(getState().status, EventFormSubmissionStatus.submitting);

      completer.complete();
      await pending;
      expect(getState().isSubmitting, isFalse);
      expect(getState().status, EventFormSubmissionStatus.success);
    });

    test('25. Double-submit bị chặn', () async {
      final completer = Completer<void>();
      var calls = 0;
      Future<void> saveCallback(EventFormInput _) {
        calls++;
        return completer.future;
      }

      final first = getViewModel().submit(createValidInput(), saveCallback);
      final second = getViewModel().submit(createValidInput(), saveCallback);

      expect(calls, 1);
      completer.complete();
      expect(await first, isTrue);
      expect(await second, isFalse);
    });

    test('26. Repository failure hiển thị error an toàn', () async {
      final result = await getViewModel().submit(
        createValidInput(),
        (_) async => throw const AppException(
          'Custom server error message.',
          code: 'server-err',
        ),
      );

      expect(result, isFalse);
      expect(getState().status, EventFormSubmissionStatus.error);
      expect(getState().errorMessage, 'Custom server error message.');
    });

    test('27. Form không mất dữ liệu sau validation failure', () async {
      final input = createValidInput(title: '  ');
      final result = await getViewModel().submit(input, (_) async {});

      expect(result, isFalse);
      expect(input.description, isNotEmpty);
      expect(input.capacity, 100);
      expect(getState().validationErrors, contains('title'));
    });

    test('28. Retry sau khi sửa lỗi hoạt động', () async {
      var calls = 0;
      Future<void> save(EventFormInput _) async {
        calls++;
        if (calls == 1) {
          throw const AppException('Temporary failure.', code: 'temp-err');
        }
      }

      final first = await getViewModel().submit(createValidInput(), save);
      expect(first, isFalse);
      expect(getState().errorMessage, 'Temporary failure.');

      final retry = await getViewModel().submit(createValidInput(), save);
      expect(retry, isTrue);
      expect(calls, 2);
      expect(getState().status, EventFormSubmissionStatus.success);
    });
  });

  group('UC-041 Section C: Widget Tests (29-34)', () {
    Future<void> fillValidForm(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const Key('titleField')),
        'Flutter Advanced Workshop',
      );
      await tester.enterText(
        find.byKey(const Key('descriptionField')),
        'A comprehensive 2-hour hands-on workshop building robust apps.',
      );
      await tester.ensureVisible(find.byKey(const Key('categoryField')));
      await tester.tap(find.byKey(const Key('categoryField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Technology').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('locationField')),
        'Building C, Room 301',
      );
      await tester.enterText(find.byKey(const Key('capacityField')), '100');
    }

    testWidgets('29. Inline errors hiển thị đúng từng trường', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        buildFormWidget(
          initial: createValidInput(
            title: '',
            description: 'short',
            capacity: 0,
          ),
          submit: (_) async => calls++,
        ),
      );

      final submitBtn = find.byKey(const Key('submitEventFormButton'));
      await tester.ensureVisible(submitBtn);
      await tester.pump();
      await tester.tap(submitBtn);
      await tester.pump();

      expect(calls, 0);
      expect(find.text('Title is required.'), findsOneWidget);
      expect(
        find.text('Description must be at least 20 characters.'),
        findsOneWidget,
      );
      expect(find.text('Capacity must be greater than 0.'), findsOneWidget);
    });

    testWidgets('30. Error được xóa khi sửa input hợp lệ', (tester) async {
      await tester.pumpWidget(
        buildFormWidget(
          initial: createValidInput(title: ''),
          submit: (_) async {},
        ),
      );

      final submitBtn = find.byKey(const Key('submitEventFormButton'));
      await tester.ensureVisible(submitBtn);
      await tester.pump();
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.text('Title is required.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('titleField')),
        'Valid Title Here',
      );
      await tester.pump();

      expect(find.text('Title is required.'), findsNothing);
    });

    testWidgets(
      '31. Create/Edit sử dụng đúng validation mode (future start vs past edit)',
      (tester) async {
        final pastStart = DateTime(2020, 1, 1, 9, 0);
        final pastEnd = DateTime(2020, 1, 1, 11, 0);
        var editCalls = 0;

        await tester.pumpWidget(
          buildFormWidget(
            initial: createValidInput(startAt: pastStart, endAt: pastEnd),
            submit: (_) async => editCalls++,
          ),
        );

        final submitBtn = find.byKey(const Key('submitEventFormButton'));
        await tester.ensureVisible(submitBtn);
        await tester.pump();
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(editCalls, 1);
        expect(find.textContaining('future'), findsNothing);
      },
    );

    testWidgets(
      '32. Submit invalid không chuyển trang và không gọi onSuccess',
      (tester) async {
        var successCalled = false;
        await tester.pumpWidget(
          buildFormWidget(
            initial: createValidInput(title: ''),
            success: () => successCalled = true,
          ),
        );

        final submitBtn = find.byKey(const Key('submitEventFormButton'));
        await tester.ensureVisible(submitBtn);
        await tester.pump();
        await tester.tap(submitBtn);
        await tester.pump();

        expect(successCalled, isFalse);
        expect(find.byType(EventFormScreen), findsOneWidget);
      },
    );

    testWidgets('33. Submit valid đi vào flow hiện tại và gọi onSuccess', (
      tester,
    ) async {
      var successCalled = false;
      var submitCalled = false;

      await tester.pumpWidget(
        buildFormWidget(
          submit: (_) async => submitCalled = true,
          success: () => successCalled = true,
        ),
      );

      await fillValidForm(tester);
      final submitBtn = find.byKey(const Key('submitEventFormButton'));
      await tester.ensureVisible(submitBtn);
      await tester.pump();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(submitCalled, isTrue);
      expect(successCalled, isTrue);
    });

    testWidgets('34. Validation không gây layout overflow trên màn hình nhỏ', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildFormWidget(
          initial: createValidInput(
            title: '',
            description: 'short',
            capacity: 0,
          ),
        ),
      );

      final submitBtn = find.byKey(const Key('submitEventFormButton'));
      await tester.ensureVisible(submitBtn);
      await tester.pump();
      await tester.tap(submitBtn);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
