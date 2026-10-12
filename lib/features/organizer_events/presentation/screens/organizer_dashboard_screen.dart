// CampusHub skeleton • lib/features/organizer_events/presentation/screens/organizer_dashboard_screen.dart
import 'package:flutter/material.dart';

/// Minimal organizer entry point until the full dashboard is implemented.
class OrganizerDashboardScreen extends StatelessWidget {
  const OrganizerDashboardScreen({
    super.key,
    required this.onCreateEvent,
  });

  final VoidCallback onCreateEvent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organizer')),
      body: Center(
        child: FilledButton.icon(
          key: const Key('createEventAction'),
          onPressed: onCreateEvent,
          icon: const Icon(Icons.add),
          label: const Text('Create Event'),
        ),
      ),
    );
  }
}
