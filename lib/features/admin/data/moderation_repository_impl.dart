import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/moderation_case.dart';
import 'moderation_repository.dart';

class ModerationRepositoryImpl implements ModerationRepository {
  const ModerationRepositoryImpl(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Stream<List<ModerationCase>> watchCases() => firestore
      .collection('moderation_cases')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => ModerationCase.fromMap(doc.id, doc.data()))
            .toList(growable: false),
      );

  @override
  Future<void> resolveCase({
    required String caseId,
    required ModerationAction action,
    required String note,
    required String actorId,
  }) async {
    final trimmedNote = note.trim();
    if (trimmedNote.length < 5) {
      throw ArgumentError.value(note, 'note', 'Enter at least 5 characters.');
    }
    if (actorId.trim().isEmpty) {
      throw StateError('An authenticated administrator is required.');
    }

    final reference = firestore.collection('moderation_cases').doc(caseId);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw StateError('This case no longer exists.');
      final data = snapshot.data()!;
      if (data['status'] != ModerationStatus.pending.name) {
        throw StateError('This case has already been reviewed.');
      }
      transaction.update(reference, {
        'status': action == ModerationAction.dismiss
            ? ModerationStatus.dismissed.name
            : ModerationStatus.resolved.name,
        'resolutionAction': action.name,
        'resolution': trimmedNote,
        'resolvedBy': actorId,
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
