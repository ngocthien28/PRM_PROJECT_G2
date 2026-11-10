import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../viewmodels/event_form_view_model.dart';
import '../viewmodels/event_poster_view_model.dart';
import '../../data/models/event_form_input.dart';
import 'event_form_screen.dart';
import '../viewmodels/organizer_events_view_model.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

/// Production create-event route. It keeps Firebase out of the form widget by
/// injecting a save callback from the organizer presentation layer.
class OrganizerCreateEventScreen extends ConsumerWidget {
  const OrganizerCreateEventScreen({super.key});

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Chỉ gắn draftOrganizerId cho actor active có canOrganize; repository còn kiểm tra quyền tạo event.
  /// ROLE: Cross-module role/access integration
  /// CALLED FROM: Route organizerCreateEvent.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, Riverpod, go_router.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(currentUserProvider).asData?.value;
    return ProviderScope(
      key: ValueKey(actor?.uid),
      overrides: [
        eventFormViewModelProvider.overrideWith(EventFormViewModel.new),
        eventPosterViewModelProvider.overrideWith(EventPosterViewModel.new),
      ],
      child: EventFormScreen(
        draftOrganizerId:
            actor != null && actor.isActive && actor.role.canOrganize
            ? actor.uid
            : null,
        onSubmit: ref.read(organizerEventActionsProvider).createEvent,
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event created successfully.')),
          );
          context.go(RouteNames.organizerManagedEvents);
        },
      ),
    );
  }
}

class OrganizerEditEventScreen extends ConsumerWidget {
  const OrganizerEditEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(organizerEditEventProvider(eventId));
    return load.when(
      skipLoadingOnRefresh: false,
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Edit Event')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) {
        final failure = error is AppException ? error : mapError(error, stack);
        return Scaffold(
          appBar: AppBar(title: const Text('Edit Event')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(failure.message, key: const Key('editEventLoadError')),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(organizerEditEventProvider(eventId)),
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.go(RouteNames.organizerManagedEvents),
                    child: const Text('Back to managed events'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      data: (event) => ProviderScope(
        key: ValueKey((event.id, event.organizerId, event.updatedAt)),
        overrides: [
          eventFormViewModelProvider.overrideWith(EventFormViewModel.new),
          eventPosterViewModelProvider.overrideWith(EventPosterViewModel.new),
        ],
        child: EventFormScreen(
          key: ValueKey(event.id),
          existingPosterUrl: event.posterUrl,
          initialValue: EventFormInput(
            title: event.title,
            description: event.description,
            category: event.category,
            locationName: event.locationName,
            startAt: event.startAt,
            endAt: event.endAt,
            capacity: event.capacity,
            currentRegisteredCount: event.registeredCount,
            status: event.status,
          ),
          onSubmit: (input) => ref
              .read(organizerEventActionsProvider)
              .updateEvent(event.id, input, expectedUpdatedAt: event.updatedAt),
          onReload: () async {
            final discard = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Reload latest event?'),
                content: const Text(
                  'This discards your unsaved changes and loads the latest event.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Keep editing'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Reload'),
                  ),
                ],
              ),
            );
            if (discard == true && context.mounted) {
              ref.invalidate(organizerEditEventProvider(eventId));
            }
          },
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Event updated successfully.')),
            );
            context.go(RouteNames.organizerManagedEvents);
          },
        ),
      ),
    );
  }
}
