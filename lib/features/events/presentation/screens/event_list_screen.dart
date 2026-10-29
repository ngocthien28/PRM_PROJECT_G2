import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/event_categories.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../data/models/event_filter.dart';
import '../viewmodels/event_list_view_model.dart';
import '../widgets/event_results.dart';
import '../widgets/event_filter_sheet.dart';

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
        leading: const AppBackButton(fallbackLocation: RouteNames.home),
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
                  const SizedBox(height: 12),

                  // ── UC-024: Sort bar ─────────────────────────────────
                  _SortBar(currentSort: filter.sort),
                  const SizedBox(height: 8),
                  // ────────────────────────────────────────────────────

                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await showEventFilterSheet(
                            context,
                            filter,
                          );
                          if (result != null && mounted) {
                            ref
                                .read(eventFilterProvider.notifier)
                                .setFilter(result);
                          }
                        },
                        icon: const Icon(Icons.tune),
                        label: const Text('Filters'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(RouteNames.favorites),
                        icon: const Icon(Icons.favorite_border, size: 18),
                        label: const Text('Saved'),
                      ),
                      if (filter.category != null)
                        Chip(
                          label: Text(EventCategories.label(filter.category!)),
                        ),
                      if (filter.onlyAvailable)
                        const Chip(label: Text('Places available')),
                      if (filter.fromDate != null || filter.toDate != null)
                        const Chip(label: Text('Date range')),
                      if (filter.hasFilters || filter.keyword.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            _search.clear();
                            _debouncer.cancel();
                            ref.read(eventFilterProvider.notifier).reset();
                          },
                          child: const Text('Clear all'),
                        ),
                    ],
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

/// UC-024: Sort bar — hiển thị các lựa chọn sắp xếp dạng chip ngang.
class _SortBar extends ConsumerWidget {
  const _SortBar({required this.currentSort});
  final EventSort currentSort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            'Sắp xếp:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          ...EventSort.values.map((sort) {
            final selected = currentSort == sort;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('sort-${sort.name}'),
                label: Text(sort.label),
                selected: selected,
                selectedColor: colors.primaryContainer,
                onSelected: (_) => ref
                    .read(eventFilterProvider.notifier)
                    .setSort(sort),
                avatar: Icon(
                  switch (sort) {
                    EventSort.nearest => Icons.access_time_rounded,
                    EventSort.popular => Icons.trending_up_rounded,
                    EventSort.available => Icons.event_seat_outlined,
                  },
                  size: 16,
                  color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
