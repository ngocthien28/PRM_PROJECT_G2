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
  Future<String> submitReport({
    required String targetType,
    required String targetId,
    required String title,
    required String description,
    required String reporterId,
    required String reporterName,
  }) async {
    const supportedTargets = {'club', 'event', 'user', 'other'};
    final normalizedTarget = targetType.trim().toLowerCase();
    final normalizedId = targetId.trim();
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    final normalizedReporterId = reporterId.trim();
    final normalizedReporterName = reporterName.trim();

    if (!supportedTargets.contains(normalizedTarget)) {
      throw ArgumentError.value(
        targetType,
        'targetType',
        'Unsupported target.',
      );
    }
    if (normalizedId.isEmpty || normalizedReporterId.isEmpty) {
      throw StateError('A target and authenticated reporter are required.');
    }
    if (normalizedTitle.isEmpty || normalizedTitle.length > 120) {
      throw ArgumentError.value(title, 'title', 'Use 1-120 characters.');
    }
    if (normalizedDescription.length < 10 ||
        normalizedDescription.length > 1000) {
      throw ArgumentError.value(
        description,
        'description',
        'Use 10-1000 characters.',
      );
    }

    final reference = firestore.collection('moderation_cases').doc();
    await reference.set({
      'targetType': normalizedTarget,
      'targetId': normalizedId,
      'title': normalizedTitle,
      'description': normalizedDescription,
      'reporterId': normalizedReporterId,
      'reporterName': normalizedReporterName.isEmpty
          ? 'Campus member'
          : normalizedReporterName,
      'status': ModerationStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }

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
