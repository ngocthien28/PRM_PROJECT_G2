import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/presentation/widgets/event_results.dart';

/// A reusable section that renders a titled list of events using the shared
/// [EventResults] widget. Supports a trailing action button and retry logic.
class HomeEventSection extends StatelessWidget {
  const HomeEventSection({
    super.key,
    required this.title,
    required this.events,
    required this.onRetry,
    this.trailing,
    this.maxItems = 4,
  });
  final String title;
  final AsyncValue<List<EventModel>> events;
  final VoidCallback onRetry;
  final Widget? trailing;
  final int maxItems;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ?trailing,
        ],
      ),
      const SizedBox(height: 16),
      EventResults(
        events: events.whenData(
          (items) => items.take(maxItems).toList(),
        ),
        onRetry: onRetry,
      ),
    ],
  );
}
