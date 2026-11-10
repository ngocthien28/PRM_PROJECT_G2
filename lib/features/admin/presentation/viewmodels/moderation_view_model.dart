import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firebase_providers.dart';
import '../../data/models/moderation_case.dart';
import '../../data/moderation_repository.dart';
import '../../data/moderation_repository_impl.dart';
import '../../domain/usecases/submit_content_report.dart';
import '../../domain/usecases/view_moderation_queue.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>(
  (ref) => ModerationRepositoryImpl(ref.watch(firestoreProvider)),
);

final viewModerationQueueProvider = Provider<ViewModerationQueue>(
  (ref) => ViewModerationQueue(ref.watch(moderationRepositoryProvider)),
);

final moderationCasesProvider =
    StreamProvider.autoDispose<List<ModerationCase>>(
      (ref) => ref.watch(viewModerationQueueProvider).call(),
      retry: (_, _) => null,
    );

typedef SubmitContentReportAction = Future<String> Function({
  required String targetType,
  required String targetId,
  required String title,
  required String description,
  required String reporterId,
  required String reporterName,
});

final submitContentReportActionProvider =
    Provider<SubmitContentReportAction>((ref) {
      final useCase = SubmitContentReport(
        ref.watch(moderationRepositoryProvider),
      );
      return useCase.call;
    });
