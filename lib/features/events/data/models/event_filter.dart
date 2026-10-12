import 'event_model.dart';

enum EventSort { nearest, popular }

class EventFilter {
  const EventFilter({
    this.keyword = '',
    this.category,
    this.fromDate,
    this.toDate,
    this.onlyAvailable = false,
    this.sort = EventSort.nearest,
  });
  final String keyword;
  final String? category;
  // Local calendar dates; the end date is inclusive.
  final DateTime? fromDate, toDate;
  final bool onlyAvailable;
  final EventSort sort;

  bool get hasFilters =>
      category != null ||
      fromDate != null ||
      toDate != null ||
      onlyAvailable ||
      sort != EventSort.nearest;

  EventFilter withKeyword(String value) => EventFilter(
    keyword: value,
    category: category,
    fromDate: fromDate,
    toDate: toDate,
    onlyAvailable: onlyAvailable,
    sort: sort,
  );

  List<EventModel> apply(Iterable<EventModel> events) {
    final query = keyword.trim().toLowerCase();
    final from = fromDate == null
        ? null
        : DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
    final until = toDate == null
        ? null
        : DateTime(toDate!.year, toDate!.month, toDate!.day + 1);
    final result = events.where((event) {
      final start = event.startAt.toLocal();
      return (query.isEmpty || event.titleLower.contains(query)) &&
          (category == null || event.category == category) &&
          (from == null || !start.isBefore(from)) &&
          (until == null || start.isBefore(until)) &&
          (!onlyAvailable || !event.isFull);
    }).toList();
    result.sort((a, b) {
      if (sort == EventSort.popular) {
        final popularity = b.registeredCount.compareTo(a.registeredCount);
        if (popularity != 0) return popularity;
      }
      final date = a.startAt.compareTo(b.startAt);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    return List.unmodifiable(result);
  }
}
