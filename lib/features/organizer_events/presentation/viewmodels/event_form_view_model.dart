import '../../data/models/event_form_input.dart';

/// Submission states for the organizer event form.
enum EventFormSubmissionStatus { idle, validating, submitting, success, error }

/// Pure-Dart state that a future Riverpod EventFormViewModel can expose.
class EventFormSubmissionState {
  const EventFormSubmissionState({
    required this.status,
    this.validationErrors = const {},
    this.errorMessage,
  });

  const EventFormSubmissionState.idle()
      : status = EventFormSubmissionStatus.idle,
        validationErrors = const {},
        errorMessage = null;

  final EventFormSubmissionStatus status;
  final Map<String, String> validationErrors;
  final String? errorMessage;

  bool get isSubmitting => status == EventFormSubmissionStatus.submitting;
}

typedef EventFormSaveCallback = Future<void> Function(EventFormInput input);

/// Coordinates validation and an injected async save operation.
///
/// This has no Riverpod, Firebase, repository, or UI dependency. It is a
/// temporary coordinator to be wrapped by the production ViewModel later.
class EventFormSubmissionController {
  EventFormSubmissionState _state = const EventFormSubmissionState.idle();
  bool _submissionLocked = false;

  EventFormSubmissionState get state => _state;

  Future<bool> submit(EventFormInput input, EventFormSaveCallback save) async {
    if (_submissionLocked) return false;

    _state = const EventFormSubmissionState(
      status: EventFormSubmissionStatus.validating,
    );
    final errors = input.validate();
    if (errors.isNotEmpty) {
      _state = EventFormSubmissionState(
        status: EventFormSubmissionStatus.error,
        validationErrors: Map.unmodifiable(errors),
      );
      return false;
    }

    _submissionLocked = true;
    _state = const EventFormSubmissionState(
      status: EventFormSubmissionStatus.submitting,
    );
    try {
      await save(input);
      _state = const EventFormSubmissionState(
        status: EventFormSubmissionStatus.success,
      );
      return true;
    } catch (_) {
      _state = const EventFormSubmissionState(
        status: EventFormSubmissionStatus.error,
        errorMessage: 'Unable to save event. Please try again.',
      );
      return false;
    } finally {
      _submissionLocked = false;
    }
  }
}
