import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../data/models/app_notification.dart';
import '../../data/notification_repository_impl.dart';

final notificationRepositoryProvider = Provider<NotificationRepositoryImpl>(
  (ref) => NotificationRepositoryImpl(ref.watch(firestoreProvider)),
);
final notificationInboxProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
      final user = ref.watch(currentUserProvider);
      if (user.isLoading) return const Stream.empty();
      final uid = user.asData?.value?.uid;
      if (uid == null) return Stream.value([]);
      return ref.watch(notificationRepositoryProvider).watchInbox(uid);
    }, retry: (_, _) => null);
final unreadNotificationCountProvider = Provider<int>(
  (ref) =>
      ref
          .watch(notificationInboxProvider)
          .asData
          ?.value
          .where((n) => !n.isRead)
          .length ??
      0,
);
