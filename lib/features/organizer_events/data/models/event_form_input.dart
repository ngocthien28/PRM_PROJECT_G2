import '../../../../core/constants/event_categories.dart';

/// Pure-Dart input and validation for the organizer event create/edit form.
///
/// This type deliberately contains only editable form fields. Event identity,
/// ownership, counters, timestamps, and persisted poster URLs remain under the
/// shared event contract.
class EventFormInput {
  const EventFormInput({
    required this.title,
    required this.description,
    required this.category,
    required this.locationName,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    this.posterSelection,
  });

  static const int minTitleLength = 3;
  static const int maxTitleLength = 120;
  static const int minDescriptionLength = 20;
  static const int maxCapacity = 5000;

  final String title;
  final String description;
  final String category;
  final String locationName;
  final DateTime startAt;
  final DateTime endAt;
  final int capacity;
  final EventPosterSelection? posterSelection;

  /// Returns one readable error per invalid form field.
  ///
  /// The keys match the form fields so a future Flutter form can display an
  /// error next to its corresponding input without depending on this class on
  /// Flutter, Riverpod, or a data source.
  /// [requireFutureStart] is used only when publishing a new event. Existing
  /// events may need non-time-sensitive edits after their start time.
  ///
  /// [now] makes the time boundary deterministic for repositories and tests.
  Map<String, String> validate({
    bool requireFutureStart = false,
    DateTime? now,
  }) {
    final errors = <String, String>{};
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();

    if (trimmedTitle.isEmpty) {
      errors['title'] = 'Title is required.';
    } else if (trimmedTitle.length < minTitleLength ||
        trimmedTitle.length > maxTitleLength) {
      errors['title'] =
          'Title must be between $minTitleLength and $maxTitleLength characters.';
    }

    if (trimmedDescription.isEmpty) {
      errors['description'] = 'Description is required.';
    } else if (trimmedDescription.length < minDescriptionLength) {
      errors['description'] =
          'Description must be at least $minDescriptionLength characters.';
    }

    if (category.trim().isEmpty) {
      errors['category'] = 'Category is required.';
    } else if (!EventCategories.labels.containsKey(category.trim())) {
      errors['category'] = 'Select a valid event category.';
    }

    if (locationName.trim().isEmpty) {
      errors['locationName'] = 'Location is required.';
    }

    if (!startAt.isBefore(endAt)) {
      errors['endAt'] = 'End time must be after start time.';
    }
    if (requireFutureStart &&
        !startAt.toUtc().isAfter((now ?? DateTime.now()).toUtc())) {
      errors['startAt'] =
          'Start time must be in the future for a new published event.';
    }

    if (capacity <= 0) {
      errors['capacity'] = 'Capacity must be greater than 0.';
    } else if (capacity > maxCapacity) {
      errors['capacity'] = 'Capacity must not exceed $maxCapacity.';
    }

    return errors;
  }

  bool get isValid => validate().isEmpty;
}

/// A local poster selected for a future upload.
///
/// This is deliberately distinct from an uploaded `EventModel.posterUrl`: it is not an
/// uploaded URL and is never persisted by the event repository in UC-032.
/// UC-040 owns picking, type/size validation and storage upload.
class EventPosterSelection {
  const EventPosterSelection({
    required this.localUri,
    this.mimeType,
    this.byteLength,
  });

  final Uri localUri;
  final String? mimeType;
  final int? byteLength;
}
