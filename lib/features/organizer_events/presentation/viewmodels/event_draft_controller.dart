import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../data/event_draft_repository.dart';
import '../../data/models/event_draft.dart';

/// Serializes disk operations so an old save cannot resurrect a discarded or
/// successfully submitted draft. Revision guards late restoration.
class EventDraftController {
  EventDraftController({
    required EventDraftRepository repository,
    required this.organizerId,
    this.debounce = const Duration(milliseconds: 750),
    this.onChanged,
  }) : repository = repository.scopedTo(organizerId);
  final EventDraftRepository repository;
  final String organizerId;
  final Duration debounce;
  void Function()? onChanged;
  Timer? _timer;
  Future<void> _queue = Future.value();
  EventDraft? _pending;
  DateTime _createdAt = DateTime.now().toUtc();
  String id = const Uuid().v4();
  int _revision = 0;
  bool _finished = false;
  String message = 'Draft not saved yet';

  Future<EventDraft?> restore() async {
    final revision = _revision;
    message = 'Loading draft...';
    onChanged?.call();
    try {
      final draft = await repository.getDraft();
      if (_finished || revision != _revision) return null;
      if (draft != null) {
        id = draft.id;
        _createdAt = draft.createdAt;
      }
      message = draft == null ? 'Draft not saved yet' : 'Draft restored';
      return draft;
    } catch (_) {
      message = 'Could not restore draft. Retry or discard the local draft.';
      return null;
    } finally {
      onChanged?.call();
    }
  }

  void changed(Map<String, dynamic> fields) {
    if (_finished) return;
    _revision++;
    _pending = EventDraft(
      id: id,
      organizerId: organizerId,
      fields: fields,
      createdAt: _createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    message = 'Unsaved draft changes';
    _timer?.cancel();
    _timer = Timer(debounce, () {
      unawaited(flush());
    });
    onChanged?.call();
  }

  Future<void> flush() {
    _timer?.cancel();
    final draft = _pending;
    final revision = _revision;
    if (_finished || draft == null) return _queue;
    _pending = null;
    message = 'Saving draft...';
    onChanged?.call();
    _queue = _queue.then((_) async {
      try {
        await repository.saveDraft(draft);
        if (revision == _revision && _pending == null) {
          message = 'Draft saved on this device';
        }
      } catch (_) {
        if (revision == _revision) {
          _pending ??= draft;
          message = 'Could not save draft. Tap Save Draft to retry.';
        }
      }
      onChanged?.call();
    });
    return _queue;
  }

  Future<bool> clear({bool submitted = false}) async {
    _timer?.cancel();
    _revision++;
    _finished = true;
    await _queue;
    try {
      await repository.deleteDraft();
      _pending = null;
      if (!submitted) {
        id = const Uuid().v4();
        _createdAt = DateTime.now().toUtc();
        _finished = false;
      }
      message = 'Draft discarded';
      onChanged?.call();
      return true;
    } catch (_) {
      _finished = submitted;
      message = submitted
          ? 'Event created, but local draft cleanup failed.'
          : 'Could not discard draft. Retry.';
      onChanged?.call();
      return false;
    }
  }

  void dispose() {
    onChanged = null;
    _timer?.cancel();
    unawaited(flush());
  }
}
