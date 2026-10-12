import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/debouncer.dart';
import '../viewmodels/event_list_view_model.dart';
import '../widgets/event_results.dart';

class EventListScreen extends ConsumerStatefulWidget {
  const EventListScreen({super.key});
  @override
  ConsumerState<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends ConsumerState<EventListScreen> {
  final _search = TextEditingController();
  final _debouncer = Debouncer();

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(eventFilterProvider).keyword;
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _search.dispose();
    super.dispose();
  }

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
    final filter = ref.watch(eventFilterProvider);
    final events = ref.watch(filteredEventsProvider);
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
                  TextField(
                    key: const Key('event-search'),
                    controller: _search,
                    onChanged: (value) => _debouncer.run(
                      () => ref
                          .read(eventFilterProvider.notifier)
                          .setKeyword(value),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Search events',
                      hintText: 'Search by title',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                _debouncer.cancel();
                                ref
                                    .read(eventFilterProvider.notifier)
                                    .setKeyword('');
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
