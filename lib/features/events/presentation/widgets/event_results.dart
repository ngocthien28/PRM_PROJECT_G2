import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/models/event_model.dart';
import 'event_card.dart';

class EventResults extends StatelessWidget {
  const EventResults({
    super.key,
    required this.events,
    required this.onRetry,
    this.emptyTitle = 'No upcoming events yet',
    this.emptyMessage = 'Check back soon for new campus activities.',
  });
  final AsyncValue<List<EventModel>> events;
  final VoidCallback onRetry;
  final String emptyTitle, emptyMessage;

  @override
  Widget build(BuildContext context) => events.when(
    skipLoadingOnRefresh: false,
    loading: () => const Padding(
      padding: EdgeInsets.all(48),
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (error, _) => EventFailure(error: error, onRetry: onRetry),
    data: (items) => items.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                const Icon(Icons.event_available_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  emptyTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(emptyMessage, textAlign: TextAlign.center),
              ],
            ),
          )
        : EventGrid(events: items),
  );
}

class EventGrid extends StatelessWidget {
  const EventGrid({super.key, required this.events});
  final List<EventModel> events;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 600 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 20) / columns;
      return Wrap(
        key: ValueKey('event-grid-$columns'),
        spacing: 20,
        runSpacing: 20,
        children: events
            .map(
              (event) => SizedBox(
                width: width,
                child: EventCard(key: ValueKey(event.id), event: event),
              ),
            )
            .toList(),
      );
    },
  );
}

class EventFailure extends StatelessWidget {
  const EventFailure({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 16),
          Text(
            error is AppException
                ? (error as AppException).message
                : 'Unable to load events. Please try again.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
