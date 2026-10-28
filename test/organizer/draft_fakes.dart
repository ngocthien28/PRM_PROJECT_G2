import 'package:campushub/features/organizer_events/data/event_draft_repository.dart';
import 'package:campushub/features/organizer_events/data/models/event_draft.dart';

/// Widgets use a repository override; SQLite durability is verified separately.
class FakeDraftRepository extends EventDraftRepository {
  FakeDraftRepository()
    : super(dao: () => throw UnimplementedError(), currentActor: () => null);
  EventDraft? value;
  int saves = 0;
  @override
  EventDraftRepository scopedTo(String uid) => this;
  @override
  Future<EventDraft?> getDraft() async => value;
  @override
  Future<bool> hasDraft() async => value != null;
  @override
  Future<void> saveDraft(EventDraft draft) async {
    saves++;
    value = draft;
  }

  @override
  Future<void> deleteDraft() async {
    value = null;
  }
}
