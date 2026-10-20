import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../data/models/event_model.dart';
import 'event_list_view_model.dart';

/// Management reads must retain the repository's owner/admin checks.
final managedEventDetailProvider = FutureProvider.autoDispose
    .family<EventModel, String>((ref, id) async {
      final user = await ref.watch(currentUserProvider.future);
      if (!ref.mounted ||
          user == null ||
          !user.isActive ||
          !user.role.canOrganize) {
        throw const AppException(
          'You cannot manage this event.',
          code: 'permission-denied',
        );
      }
      return ref.watch(eventRepositoryProvider).getEventById(id, actor: user);
    }, retry: (_, _) => null);

final eventDetailProvider = FutureProvider.autoDispose
    .family<EventModel, String>((ref, id) async {
      final identity = await ref.watch(authStateProvider.future);
      if (!ref.mounted || identity == null) {
        throw const AppException(
          'Please sign in to view this event.',
          code: 'session-ended',
        );
      }
      return ref.watch(eventRepositoryProvider).getEventById(id);
    });
