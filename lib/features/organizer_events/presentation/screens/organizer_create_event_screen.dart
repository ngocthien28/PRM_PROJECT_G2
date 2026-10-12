import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../events/data/models/event_model.dart';
import '../../data/models/event_form_input.dart';
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

class OrganizerEditEventScreen extends ConsumerWidget {
  const OrganizerEditEventScreen({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EventFormScreen(
      initialValue: EventFormInput(
        title: event.title,
        description: event.description,
        category: event.category,
        locationName: event.locationName,
        startAt: event.startAt,
        endAt: event.endAt,
        capacity: event.capacity,
      ),
      onSubmit: (input) => ref
          .read(organizerEventActionsProvider)
          .updateEvent(event.id, input),
      onSuccess: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully.')),
        );
        context.go('/organizer');
      },
    );
  }
}
