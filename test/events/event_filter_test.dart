import 'package:campushub/features/events/data/models/event_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'event_fakes.dart';

void main() {
  test('search filter matches case-insensitively and trims whitespace', () {
    final events = [
      testEvent(id: '1', title: 'Tech Talk: Flutter'),
      testEvent(id: '2', title: 'Music Festival'),
    ];
    final result = const EventFilter(
      keyword: ' flutter ',
    ).apply(events);
    expect(result.map((e) => e.id), ['1']);
  });
}
