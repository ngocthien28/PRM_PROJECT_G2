import 'package:sqflite/sqflite.dart';
import '../../features/organizer_events/data/models/event_draft.dart';

class EventDraftDao {
  EventDraftDao(this.database);
  final Database database;

  Future<void> saveDraft(EventDraft draft) => database.transaction((tx) async {
    await tx.insert(
      'event_drafts',
      draft.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  });

  Future<EventDraft?> getDraft(String uid) async {
    final rows = await database.query(
      'event_drafts',
      where: 'organizer_id = ?',
      whereArgs: [uid],
    );
    return rows.isEmpty ? null : EventDraft.fromMap(rows.single);
  }

  Future<bool> hasDraft(String uid) async => (await database.query(
    'event_drafts',
    columns: ['id'],
    where: 'organizer_id = ?',
    whereArgs: [uid],
  )).isNotEmpty;

  Future<void> deleteDraft(String uid) async {
    await database.delete(
      'event_drafts',
      where: 'organizer_id = ?',
      whereArgs: [uid],
    );
  }
}
