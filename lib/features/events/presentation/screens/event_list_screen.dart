import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/event_list_view_model.dart';
import '../widgets/event_results.dart';

class EventListScreen extends ConsumerStatefulWidget {
  const EventListScreen({super.key});
  @override
  ConsumerState<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends ConsumerState<EventListScreen> {
  Future<void> _refresh() async {
    try {
      ref.invalidate(eventListProvider);
      await ref.read(eventListProvider.future);
    } catch (_) {
      // The provider exposes the error through EventResults.
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover events'),
        actions: [
          IconButton(
            tooltip: 'Refresh events',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Find your next campus experience',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Explore upcoming events and make room for something new.',
                  ),
                  const SizedBox(height: 24),
                  EventResults(
                    events: events,
                    onRetry: _refresh,
                    emptyTitle: 'No matching events',
                    emptyMessage:
                        'Try another search or clear the filters. New events will appear here when published.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
