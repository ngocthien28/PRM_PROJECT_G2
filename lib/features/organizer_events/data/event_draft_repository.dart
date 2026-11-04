import '../../../core/errors/app_exception.dart';
import '../../../local/dao/event_draft_dao.dart';
import '../../auth/data/models/app_user.dart';
import 'models/event_draft.dart';

/// The application cannot choose an arbitrary user's draft: every operation
/// resolves the authenticated account, including after asynchronous DB opening.
class EventDraftRepository {
  EventDraftRepository({
    required this.dao,
    required this.currentActor,
    this.organizerId,
  });
  final Future<EventDraftDao> Function() dao;
  final AppUser? Function() currentActor;
  final String? organizerId;

  EventDraftRepository scopedTo(String uid) => EventDraftRepository(
    dao: dao,
    currentActor: currentActor,
    organizerId: uid,
  );

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Yêu cầu organizer/admin active và UID đúng scope trước truy cập draft local.
  /// ROLE: Cross-module role/access integration
  /// CALLED FROM: EventDraftRepository._run.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  String _uid() {
    final actor = currentActor();
    if (actor == null || !actor.isActive || !actor.role.canOrganize) {
      throw const AppException(
        'An active organizer account is required.',
        code: 'draft-forbidden',
      );
    }
    if (organizerId != null && actor.uid != organizerId) {
      throw const AppException(
        'Draft session has ended.',
        code: 'draft-forbidden',
      );
    }
    return actor.uid;
  }

  Future<T> _run<T>(
    Future<T> Function(EventDraftDao dao, String uid) action,
  ) async {
    final uid = _uid();
    try {
      final source = await dao();
      if (_uid() != uid) throw StateError('Account changed');
      final result = await action(source, uid);
      if (_uid() != uid) throw StateError('Account changed');
      return result;
    } catch (error) {
      if (error is AppException) rethrow;
      throw AppException(
        'Local draft could not be accessed. Please retry.',
        code: 'draft-storage',
        cause: error,
      );
    }
  }

  Future<EventDraft?> getDraft() => _run((dao, uid) => dao.getDraft(uid));
  Future<bool> hasDraft() => _run((dao, uid) => dao.hasDraft(uid));
  Future<void> saveDraft(EventDraft draft) => _run((dao, uid) async {
    if (draft.organizerId != uid) {
      throw const AppException(
        'Draft account changed.',
        code: 'draft-forbidden',
      );
    }
    await dao.saveDraft(draft);
  });
  Future<void> deleteDraft() => _run((dao, uid) => dao.deleteDraft(uid));
}
