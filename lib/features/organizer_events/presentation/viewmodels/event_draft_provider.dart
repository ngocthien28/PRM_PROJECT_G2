import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../local/app_database.dart';
import '../../../../local/dao/event_draft_dao.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../data/event_draft_repository.dart';

final eventDraftRepositoryProvider = Provider<EventDraftRepository>(
  (ref) => EventDraftRepository(
    dao: () async {
      final db = await AppDatabase.instance.database;
      if (db == null) {
        throw const AppException(
          'SQLite is unavailable on this device.',
          code: 'draft-unavailable',
        );
      }
      return EventDraftDao(db);
    },
    currentActor: () => ref.read(currentUserProvider).asData?.value,
  ),
);
