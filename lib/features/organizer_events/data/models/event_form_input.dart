import 'dart:typed_data';

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
    this.createRequestId,
    this.currentRegisteredCount,
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

  /// Stable for the lifetime of one create form, including poster retries.
  final String? createRequestId;

  /// The number of registered participants for an existing event being edited.
  /// Used to ensure capacity cannot be reduced below current registrations.
  final int? currentRegisteredCount;

  EventFormInput copyWith({
    String? title,
    String? description,
    String? category,
    String? locationName,
    DateTime? startAt,
    DateTime? endAt,
    int? capacity,
    EventPosterSelection? posterSelection,
    String? createRequestId,
    int? currentRegisteredCount,
  }) {
    return EventFormInput(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      locationName: locationName ?? this.locationName,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      capacity: capacity ?? this.capacity,
      posterSelection: posterSelection ?? this.posterSelection,
      createRequestId: createRequestId ?? this.createRequestId,
      currentRegisteredCount:
          currentRegisteredCount ?? this.currentRegisteredCount,
    );
  }

  /// Returns one readable error per invalid form field.
  ///
  /// The keys match the form fields so a future Flutter form can display an
  /// error next to its corresponding input without depending on this class on
  /// Flutter, Riverpod, or a data source.
  /// [requireFutureStart] is used only when publishing a new event. Existing
  /// events may need non-time-sensitive edits after their start time.
  ///
  /// [now] makes the time boundary deterministic for repositories and tests.
  ///
  /// [currentRegisteredCount] enforces that capacity is not reduced below
  /// existing registrations in edit mode.
  Map<String, String> validate({
    bool requireFutureStart = false,
    DateTime? now,
    int? currentRegisteredCount,
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

    final minRegistered = currentRegisteredCount ?? this.currentRegisteredCount;
    if (capacity <= 0) {
      errors['capacity'] = 'Capacity must be greater than 0.';
    } else if (capacity > maxCapacity) {
      errors['capacity'] = 'Capacity must not exceed $maxCapacity.';
    } else if (minRegistered != null && capacity < minRegistered) {
      errors['capacity'] =
          'Capacity must be at least $minRegistered, the current number of registered participants.';
    }

    if (posterSelection != null) {
      final poster = posterSelection!;
      const maxBytes = 5 * 1024 * 1024;
      if (poster.byteLength != null &&
          (poster.byteLength! <= 0 || poster.byteLength! > maxBytes)) {
        errors['poster'] = 'Poster must be between 1 byte and 5 MB.';
      } else if (poster.bytes != null &&
          (poster.bytes!.isEmpty || poster.bytes!.length > maxBytes)) {
        errors['poster'] = 'Poster must be between 1 byte and 5 MB.';
      } else if (poster.fileName != null) {
        final ext = poster.fileName!.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
          errors['poster'] = 'Choose a valid JPG, PNG, or WebP image.';
        }
      } else if (poster.mimeType != null) {
        final mime = poster.mimeType!.toLowerCase();
        if (!['image/jpeg', 'image/png', 'image/webp'].contains(mime)) {
          errors['poster'] = 'Choose a valid JPG, PNG, or WebP image.';
        }
      }
    }

    return errors;
  }

  bool get isValid => validate().isEmpty;
}

/// A local poster selected for a future upload.
///
/// This is deliberately distinct from an uploaded `EventModel.posterUrl`: it is not an
/// uploaded URL. Only the Storage service's download URL may be persisted.
class EventPosterSelection {
  const EventPosterSelection({
    required this.localUri,
    this.mimeType,
    this.byteLength,
    this.fileName,
    this.bytes,
  });

  final Uri localUri;
  final String? mimeType;
  final int? byteLength;
  final String? fileName;
  final Uint8List? bytes;
}
