import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'event_form_screen.dart';
import '../viewmodels/organizer_events_view_model.dart';

/// Production create-event route. It keeps Firebase out of the form widget by
/// injecting a save callback from the organizer presentation layer.
class OrganizerCreateEventScreen extends ConsumerWidget {
  const OrganizerCreateEventScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EventFormScreen(
      onSubmit: ref.read(organizerEventActionsProvider).createEvent,
      onSuccess: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully.')),
        );
        context.go('/organizer');
      },
    );
  }
}
