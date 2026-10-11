/// Pure-Dart input and validation for the organizer event create/edit form.
///
/// This type deliberately contains only editable form fields. Event identity,
/// ownership, counters, timestamps, status, and poster handling belong to the
/// shared event contract and later data-layer tasks.
class EventFormInput {
  const EventFormInput({
    required this.title,
    required this.description,
    required this.category,
    required this.locationName,
    required this.startAt,
    required this.endAt,
    required this.capacity,
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

  /// Returns one readable error per invalid form field.
  ///
  /// The keys match the form fields so a future Flutter form can display an
  /// error next to its corresponding input without depending on this class on
  /// Flutter, Riverpod, or a data source.
  Map<String, String> validate() {
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
    }

    if (locationName.trim().isEmpty) {
      errors['locationName'] = 'Location is required.';
    }

    if (!startAt.isBefore(endAt)) {
      errors['endAt'] = 'End time must be after start time.';
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
