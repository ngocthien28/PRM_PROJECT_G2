import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../data/models/event_model.dart';
import 'event_list_view_model.dart';

/// Management reads must retain the repository's owner/admin checks.
/// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
/// MODULE: Testing & Integration
/// DESCRIPTION: Chặn user thiếu/không active/không canOrganize trước khi đọc event có actor.
/// ROLE: Cross-module role/access integration
/// CALLED FROM: EventDetailScreen managed mode.
/// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod.
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
