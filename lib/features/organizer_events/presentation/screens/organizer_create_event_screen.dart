import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    );
  }
}
