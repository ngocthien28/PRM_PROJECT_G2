import 'package:campushub/features/admin/data/models/moderation_case.dart';
import 'package:campushub/features/admin/data/moderation_repository.dart';
import 'package:campushub/features/admin/domain/usecases/submit_content_report.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeModerationRepository implements ModerationRepository {
  String? lastTargetType;
  String? lastTargetId;
  String? lastTitle;
  String? lastDescription;
  String? lastReporterId;
  String? lastReporterName;

  @override
  Stream<List<ModerationCase>> watchCases() => const Stream.empty();

  @override
  Future<String> submitReport({
    required String targetType,
    required String targetId,
    required String title,
    required String description,
    required String reporterId,
    required String reporterName,
  }) async {
    lastTargetType = targetType;
    lastTargetId = targetId;
    lastTitle = title;
    lastDescription = description;
    lastReporterId = reporterId;
    lastReporterName = reporterName;
    return 'case-123';
  }

  @override
  Future<void> resolveCase({
    required String caseId,
    required ModerationAction action,
    required String note,
    required String actorId,
  }) async {}
}

void main() {
  group('UC-092: SubmitContentReport', () {
    late _FakeModerationRepository repository;
    late SubmitContentReport useCase;

    setUp(() {
      repository = _FakeModerationRepository();
      useCase = SubmitContentReport(repository);
    });

    test('successfully validates and submits report with formatted title', () async {
      final caseId = await useCase(
        targetType: 'club',
        targetId: 'club-1',
        title: 'Safety concern: Hiking Club',
        description: 'Meeting location is on unsafe terrain after dark.',
        reporterId: 'user-1',
        reporterName: 'John Doe',
      );

      expect(caseId, 'case-123');
      expect(repository.lastTargetType, 'club');
      expect(repository.lastTargetId, 'club-1');
      expect(repository.lastTitle, 'Safety concern: Hiking Club');
      expect(repository.lastDescription, 'Meeting location is on unsafe terrain after dark.');
      expect(repository.lastReporterId, 'user-1');
      expect(repository.lastReporterName, 'John Doe');
    });

    test('truncates titles that exceed 120 characters', () async {
      final veryLongTitle = 'A' * 150;
      await useCase(
        targetType: 'event',
        targetId: 'event-1',
        title: veryLongTitle,
        description: 'This event description is long enough to pass validation.',
        reporterId: 'user-1',
        reporterName: 'John Doe',
      );

      expect(repository.lastTitle?.length, 120);
      expect(repository.lastTitle?.endsWith('...'), isTrue);
    });

    test('throws ArgumentError when description is shorter than 10 characters', () async {
      expect(
        () => useCase(
          targetType: 'event',
          targetId: 'event-1',
          title: 'Spam event',
          description: 'Too short',
          reporterId: 'user-1',
          reporterName: 'John Doe',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
