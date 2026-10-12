import 'event_model.dart';

class EventFilter {
  const EventFilter({
    this.keyword = '',
  });
  final String keyword;

  EventFilter withKeyword(String value) => EventFilter(
    keyword: value,
  );

  List<EventModel> apply(Iterable<EventModel> events) {
    final query = keyword.trim().toLowerCase();
    final result = events.where((event) {
      return query.isEmpty || event.titleLower.contains(query);
    }).toList();
    result.sort((a, b) {
      final date = a.startAt.compareTo(b.startAt);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    return List.unmodifiable(result);
  }
}
