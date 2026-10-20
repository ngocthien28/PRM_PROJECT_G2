import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final startAt = DateTime(2030, 1, 1, 9);
  final endAt = DateTime(2030, 1, 1, 11);

  EventFormInput validInput({
    String title = 'Flutter Workshop',
    String description =
        'Learn Flutter fundamentals in this hands-on workshop.',
    String category = 'technology',
    String locationName = 'Hall A',
    DateTime? start,
    DateTime? end,
    int capacity = 100,
  }) {
    return EventFormInput(
      title: title,
      description: description,
      category: category,
      locationName: locationName,
      startAt: start ?? startAt,
      endAt: end ?? endAt,
      capacity: capacity,
    );
  }

  test('accepts a valid event form input', () {
    final input = validInput();

    expect(input.validate(), isEmpty);
    expect(input.isValid, isTrue);
  });

  test('rejects an empty title', () {
    final errors = validInput(title: '').validate();

    expect(errors['title'], 'Title is required.');
  });

  test('rejects a whitespace-only title', () {
    final errors = validInput(title: '   ').validate();

    expect(errors['title'], 'Title is required.');
  });

  test('rejects a title shorter than three characters', () {
    final errors = validInput(title: 'Go').validate();

    expect(errors['title'], contains('between 3 and 120'));
  });

  test('rejects a title longer than 120 characters', () {
    final errors = validInput(title: 'a' * 121).validate();

    expect(errors['title'], contains('between 3 and 120'));
  });

  test('rejects an empty description', () {
    final errors = validInput(description: '').validate();

    expect(errors['description'], 'Description is required.');
  });

  test('rejects a description shorter than 20 characters', () {
    final errors = validInput(description: 'Too short').validate();

    expect(errors['description'], contains('at least 20'));
  });

  test('rejects an empty category', () {
    final errors = validInput(category: '').validate();

    expect(errors['category'], 'Category is required.');
  });

  test('rejects a category outside the shared event categories', () {
    final errors = validInput(category: 'other').validate();

    expect(errors['category'], 'Select a valid event category.');
  });

  test('rejects an empty location', () {
    final errors = validInput(locationName: '').validate();

    expect(errors['locationName'], 'Location is required.');
  });

  test('rejects zero capacity', () {
    final errors = validInput(capacity: 0).validate();

    expect(errors['capacity'], 'Capacity must be greater than 0.');
  });

  test('rejects negative capacity', () {
    final errors = validInput(capacity: -1).validate();

    expect(errors['capacity'], 'Capacity must be greater than 0.');
  });

  test('rejects capacity greater than 5000', () {
    final errors = validInput(capacity: 5001).validate();

    expect(errors['capacity'], 'Capacity must not exceed 5000.');
  });

  test('rejects an end time earlier than the start time', () {
    final errors = validInput(start: endAt, end: startAt).validate();

    expect(errors['endAt'], 'End time must be after start time.');
  });

  test('rejects equal start and end times', () {
    final errors = validInput(start: startAt, end: startAt).validate();

    expect(errors['endAt'], 'End time must be after start time.');
  });

  test('rejects a past start when publishing a new event', () {
    final now = DateTime.utc(2030, 1, 1, 9);
    final errors = validInput(
      start: now,
      end: now.add(const Duration(hours: 2)),
    ).validate(requireFutureStart: true, now: now);

    expect(errors['startAt'], contains('future'));
  });

  test('allows an existing event start in the past during an edit', () {
    final now = DateTime.utc(2030, 1, 2);
    final errors = validInput(
      start: DateTime.utc(2030, 1, 1, 9),
      end: DateTime.utc(2030, 1, 1, 11),
    ).validate(now: now);

    expect(errors, isEmpty);
  });

  test(
    'future start compares instants consistently across timezone offsets',
    () {
      final now = DateTime.parse('2030-01-01T09:00:00+07:00');
      expect(
        validInput(
          start: DateTime.parse('2030-01-01T02:00:01Z'),
          end: DateTime.parse('2030-01-01T11:00:00+07:00'),
        ).validate(requireFutureStart: true, now: now),
        isEmpty,
      );
      expect(
        validInput(
          start: DateTime.parse('2030-01-01T08:59:59+07:00'),
          end: DateTime.parse('2030-01-01T04:00:00Z'),
        ).validate(requireFutureStart: true, now: now),
        contains('startAt'),
      );
    },
  );

  test('keeps local poster metadata separate from an uploaded URL', () {
    final selection = EventPosterSelection(
      localUri: Uri.parse('file:///temporary/poster.png'),
      mimeType: 'image/png',
      byteLength: 123,
    );
    final input = EventFormInput(
      title: 'Flutter Workshop',
      description: 'Learn Flutter fundamentals in this hands-on workshop.',
      category: 'technology',
      locationName: 'Hall A',
      startAt: startAt,
      endAt: endAt,
      capacity: 100,
      posterSelection: selection,
    );

    expect(input.posterSelection, same(selection));
    expect(input.validate(), isEmpty);
  });
}
