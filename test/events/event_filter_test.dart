import 'package:campushub/features/events/data/models/event_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'event_fakes.dart';

void main() {
  test('search trims and ignores case, combines category and capacity', () {
    final events = [
      testEvent(),
      testEvent(id: 'full', title: 'Flutter Advanced', registeredCount: 100),
      testEvent(id: 'music', title: 'Flutter Music', category: 'music'),
    ];
    final result = const EventFilter(
      keyword: ' FLUTTER ',
      category: 'technology',
      onlyAvailable: true,
    ).apply(events);
    expect(result.map((e) => e.id), ['event-1']);
    expect(const EventFilter(keyword: 'no result').apply(events), isEmpty);
  });

  test(
    'inclusive local calendar dates keep evening events on the last day',
    () {
      final first = DateTime(2030, 5, 20);
      final last = DateTime(2030, 5, 21);
      final events = [
        testEvent(
          id: 'before',
          startAt: first.subtract(const Duration(seconds: 1)).toUtc(),
        ),
        testEvent(id: 'start', startAt: first.toUtc()),
        testEvent(id: 'end', startAt: DateTime(2030, 5, 21, 23, 59).toUtc()),
        testEvent(id: 'after', startAt: DateTime(2030, 5, 22).toUtc()),
      ];
      expect(
        EventFilter(
          fromDate: first,
          toDate: last,
        ).apply(events).map((e) => e.id),
        ['start', 'end'],
      );
    },
  );

  test(
    'popular sorts descending with stable date/id tie breaks and does not mutate input',
    () {
      final events = [
        testEvent(
          id: 'later',
          startAt: DateTime.utc(2030, 6),
          registeredCount: 40,
        ),
        testEvent(id: 'z', registeredCount: 40),
        testEvent(id: 'a', registeredCount: 40),
        testEvent(id: 'quiet', registeredCount: 1),
      ];
      expect(
        const EventFilter(
          sort: EventSort.popular,
        ).apply(events).map((e) => e.id),
        ['a', 'z', 'later', 'quiet'],
      );
      expect(events.first.id, 'later');
    },
  );
}
