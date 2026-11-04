import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/presentation/viewmodels/event_list_view_model.dart';
import '../../data/models/organizer_dashboard_summary.dart';

final organizerDashboardClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
/// MODULE: Testing & Integration
/// DESCRIPTION: Yêu cầu actor active có canOrganize và summary.organizerId đúng UID.
/// ROLE: Cross-module role/access integration
/// CALLED FROM: OrganizerDashboardScreen.
/// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod.
final organizerDashboardProvider =
    FutureProvider.autoDispose<OrganizerDashboardSummary>((ref) async {
      // selectAsync observes subsequent profile emissions as well as the first
      // one, without a second request when initial loading becomes data.
      final repository = ref.watch(eventRepositoryProvider);
      final clock = ref.watch(organizerDashboardClockProvider);
      final actor = await ref
          .watch(currentUserProvider.selectAsync((user) => user))
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw const AppException(
              'Your session could not be loaded. Please sign in again.',
              code: 'session-timeout',
            ),
          );
      if (!ref.mounted) {
        throw const AppException(
          'This dashboard session has ended.',
          code: 'session-ended',
        );
      }
      if (actor == null) {
        throw const AppException(
          'Please sign in to view your dashboard.',
          code: 'unauthenticated',
        );
      }
      if (!actor.isActive || !actor.role.canOrganize) {
        throw const AppException(
          'Only active organizers or admins can view this dashboard.',
          code: 'event-forbidden',
        );
      }
      final summary = await repository.getOrganizerDashboard(
        actor: actor,
        asOf: clock().toUtc(),
      );
      if (summary.organizerId != actor.uid) {
        throw const AppException(
          'The dashboard belongs to another organizer.',
          code: 'dashboard-owner-mismatch',
        );
      }
      return summary;
    }, retry: (_, _) => null);
