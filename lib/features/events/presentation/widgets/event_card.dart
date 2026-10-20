import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/event_categories.dart';
import '../../../../core/routing/route_names.dart';
import '../../../favorites/presentation/viewmodels/favorite_view_model.dart';
import '../../data/models/event_model.dart';
import 'event_poster.dart';
import 'event_format.dart';

class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event});
  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isFav = ref.watch(isFavoriteProvider(event.id));
    final toggleState = ref.watch(favoriteToggleProvider(event.id));

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(RouteNames.eventDetail(event.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                EventPoster(
                  url: event.posterUrl,
                  category: event.category,
                  height: 150,
                ),
                // ── UC-025: Nút yêu thích trên card ─────────────────
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withAlpha(100),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: toggleState.isLoading
                          ? null
                          : () => ref
                              .read(favoriteToggleProvider(event.id).notifier)
                              .toggle(),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: toggleState.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  key: ValueKey(isFav),
                                  size: 20,
                                  color: isFav ? Colors.red : Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                // ────────────────────────────────────────────────────
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    EventCategories.label(event.category).toUpperCase(),
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _Info(
                    icon: Icons.schedule_outlined,
                    text: eventDateTime(context, event.startAt),
                  ),
                  const SizedBox(height: 8),
                  _Info(
                    icon: Icons.place_outlined,
                    text: event.locationName,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.isFull
                              ? 'Fully booked'
                              : '${event.availablePlaces} places left',
                          style: TextStyle(
                            color: event.isFull
                                ? colors.error
                                : colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}
