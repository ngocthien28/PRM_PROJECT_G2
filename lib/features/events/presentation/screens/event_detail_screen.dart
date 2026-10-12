import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/event_categories.dart';
import '../viewmodels/event_detail_view_model.dart';
import '../widgets/event_poster.dart';
import '../widgets/event_results.dart';
import '../widgets/event_format.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(eventDetailProvider(eventId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event details'),
        actions: [
          IconButton(
            tooltip: 'Refresh event',
            onPressed: () => ref.invalidate(eventDetailProvider(eventId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: event.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EventFailure(
          error: error,
          onRetry: () => ref.invalidate(eventDetailProvider(eventId)),
        ),
        data: (value) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: EventPoster(
                      url: value.posterUrl,
                      category: value.category,
                      height: 240,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    EventCategories.label(value.category).toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final description = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About this event',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            value.description,
                            style: const TextStyle(fontSize: 16, height: 1.6),
                          ),
                        ],
                      );
                      final information = Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Detail(
                                label: 'Starts',
                                value: eventDateTime(context, value.startAt),
                              ),
                              _Detail(
                                label: 'Ends',
                                value: eventDateTime(context, value.endAt),
                              ),
                              _Detail(
                                label: 'Location',
                                value: value.locationName,
                              ),
                              _Detail(
                                label: 'Capacity',
                                value:
                                    '${value.registeredCount} / ${value.capacity} places booked',
                              ),
                              Text(
                                value.startAt.isBefore(DateTime.now())
                                    ? 'This event has already started.'
                                    : value.isFull
                                    ? 'Fully booked'
                                    : '${value.availablePlaces} places available',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (constraints.maxWidth < 600) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            information,
                            const SizedBox(height: 24),
                            description,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: description),
                          const SizedBox(width: 32),
                          Expanded(flex: 2, child: information),
                        ],
                      );
                    },
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

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
