import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../data/models/app_notification.dart';
import '../../data/notification_repository_impl.dart';
import '../../domain/usecases/view_notifications.dart';
import '../../domain/usecases/mark_notification_as_read.dart';
import '../../domain/usecases/view_notification_details.dart';
import '../../../../local/dao/notification_cache_dao.dart';

final notificationCacheProvider = Provider<NotificationCache>(
  (_) => NotificationCacheDao(),
);

final notificationRepositoryProvider = Provider<NotificationRepositoryImpl>(
  (ref) => NotificationRepositoryImpl(
    ref.watch(firestoreProvider),
    cache: ref.watch(notificationCacheProvider),
  ),
);

typedef MarkNotificationAsReadAction = Future<void> Function(
  String notificationId,
);

final markNotificationAsReadActionProvider =
    Provider<MarkNotificationAsReadAction>((ref) {
      final useCase = MarkNotificationAsRead(
        ref.watch(firestoreProvider),
        ref.watch(notificationCacheProvider),
      );
      return useCase.call;
    });

typedef ViewNotificationDetailsAction = Future<AppNotification> Function(
  AppNotification notification,
);

final viewNotificationDetailsActionProvider =
    Provider<ViewNotificationDetailsAction>((ref) {
      final useCase = ViewNotificationDetails(
        ref.watch(notificationRepositoryProvider),
      );
      return useCase.call;
    });

final notificationInboxProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
      final user = ref.watch(currentUserProvider);
      if (user.isLoading) return const Stream.empty();
      final uid = user.asData?.value?.uid;
      if (uid == null) return Stream.value([]);
      return ViewNotifications(
        ref.watch(firestoreProvider),
        ref.watch(notificationCacheProvider),
      )(uid);
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
