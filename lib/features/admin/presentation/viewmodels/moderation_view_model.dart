import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firebase_providers.dart';
import '../../data/models/moderation_case.dart';
import '../../data/moderation_repository.dart';
import '../../data/moderation_repository_impl.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>(
  (ref) => ModerationRepositoryImpl(ref.watch(firestoreProvider)),
);

final moderationCasesProvider =
    StreamProvider.autoDispose<List<ModerationCase>>(
      (ref) => ref.watch(moderationRepositoryProvider).watchCases(),
      retry: (_, _) => null,
    );
