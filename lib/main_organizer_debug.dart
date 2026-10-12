import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/organizer_events/data/models/event_form_input.dart';
import 'features/organizer_events/presentation/screens/event_form_screen.dart';

final _debugMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  runApp(const ProviderScope(child: OrganizerFormDebugApp()));
}

class OrganizerFormDebugApp extends StatelessWidget {
  const OrganizerFormDebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusHub – Organizer Form Debug',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _debugMessengerKey,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const _OrganizerFormDebugHome(),
    );
  }
}

class _OrganizerFormDebugHome extends StatelessWidget {
  const _OrganizerFormDebugHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CampusHub – Organizer Form Debug')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Development-only manual testing',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The form uses a delayed debug callback only. No event is saved to Firebase.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => _openForm(context),
                  child: const Text('Test Create Event'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _openForm(
                    context,
                    initialValue: _sampleEventInput(),
                  ),
                  child: const Text('Test Edit Event'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openForm(BuildContext context, {EventFormInput? initialValue}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _IsolatedEventForm(
          initialValue: initialValue,
          onSubmit: _debugSubmit,
        ),
      ),
    );
  }
}

class _IsolatedEventForm extends StatefulWidget {
  const _IsolatedEventForm({
    this.initialValue,
    required this.onSubmit,
  });

  final EventFormInput? initialValue;
  final EventFormSubmitCallback onSubmit;

  @override
  State<_IsolatedEventForm> createState() => _IsolatedEventFormState();
}

class _IsolatedEventFormState extends State<_IsolatedEventForm> {
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _container = ProviderContainer();
  }

  @override
  void dispose() {
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: _container,
      child: EventFormScreen(
        initialValue: widget.initialValue,
        onSubmit: widget.onSubmit,
      ),
    );
  }
}

EventFormInput _sampleEventInput() {
  final date = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 7));
  return EventFormInput(
    title: 'Campus Flutter Workshop',
    description: 'A hands-on workshop covering Flutter form and state patterns.',
    category: 'Technology',
    locationName: 'Innovation Hall A',
    startAt: DateTime(date.year, date.month, date.day, 9),
    endAt: DateTime(date.year, date.month, date.day, 11),
    capacity: 80,
  );
}

Future<void> _debugSubmit(EventFormInput input) async {
  await Future<void>.delayed(const Duration(seconds: 2));
  debugPrint(
    'Organizer form debug submit: '
    'title=${input.title}, category=${input.category}, '
    'location=${input.locationName}, start=${input.startAt.toIso8601String()}, '
    'end=${input.endAt.toIso8601String()}, capacity=${input.capacity}',
  );
  _debugMessengerKey.currentState?.showSnackBar(
    const SnackBar(
      content: Text('Debug callback completed. No event was saved to Firebase.'),
    ),
  );
}
