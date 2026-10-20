import 'event_model.dart';

/// Sort options for the Event Discovery screen (UC-024).
enum EventSort {
  /// Sắp xếp theo thời gian sắp diễn ra (gần nhất trước).
  nearest,

  /// Sắp xếp theo mức độ phổ biến (nhiều đăng ký nhất trước).
  popular,

  /// Sắp xếp sự kiện còn chỗ trống lên đầu (tiêu chí phù hợp).
  available,
}

extension EventSortLabel on EventSort {
  String get label => switch (this) {
    EventSort.nearest => 'Sắp diễn ra',
    EventSort.popular => 'Phổ biến nhất',
    EventSort.available => 'Còn chỗ trống',
  };
}

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

  EventFilter withSort(EventSort value) => EventFilter(
    keyword: keyword,
    category: category,
    fromDate: fromDate,
    toDate: toDate,
    onlyAvailable: onlyAvailable,
    sort: value,
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
      switch (sort) {
        case EventSort.popular:
          final popularity = b.registeredCount.compareTo(a.registeredCount);
          if (popularity != 0) return popularity;
        case EventSort.available:
          // Sắp xếp theo số chỗ trống còn lại (nhiều chỗ trống hơn lên trước)
          final avail = b.availablePlaces.compareTo(a.availablePlaces);
          if (avail != 0) return avail;
        case EventSort.nearest:
          break;
      }
      final date = a.startAt.compareTo(b.startAt);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    return List.unmodifiable(result);
  }
}
