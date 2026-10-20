import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/event_categories.dart';
import '../../../favorites/presentation/viewmodels/favorite_view_model.dart';
import '../../../registration/data/models/registration_model.dart';
import '../../../registration/presentation/screens/ticket_screen.dart';
import '../../../registration/presentation/viewmodels/registration_view_model.dart';
import '../../data/models/event_model.dart';
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
    final isFav = ref.watch(isFavoriteProvider(eventId));
    final toggleState = ref.watch(favoriteToggleProvider(eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event details'),
        actions: [
          // ── UC-025: Nút yêu thích ──────────────────────────────────
          toggleState.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  key: const Key('favorite-toggle'),
                  tooltip: isFav
                      ? 'Xóa khỏi yêu thích'
                      : 'Thêm vào yêu thích',
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey(isFav),
                      color: isFav ? Colors.red : null,
                    ),
                  ),
                  onPressed: () async {
                    await ref
                        .read(favoriteToggleProvider(eventId).notifier)
                        .toggle();
                    if (context.mounted &&
                        ref
                                .read(favoriteToggleProvider(eventId))
                                .error !=
                            null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ref
                                .read(favoriteToggleProvider(eventId))
                                .error!,
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else if (context.mounted) {
                      final nowFav = ref.read(isFavoriteProvider(eventId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            nowFav
                                ? '❤️ Đã thêm vào danh sách yêu thích'
                                : '🤍 Đã xóa khỏi danh sách yêu thích',
                          ),
                        ),
                      );
                    }
                  },
                ),
          // ──────────────────────────────────────────────────────────
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
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.6,
                            ),
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
                                value: eventDateTime(
                                  context,
                                  value.startAt,
                                ),
                              ),
                              _Detail(
                                label: 'Ends',
                                value: eventDateTime(
                                  context,
                                  value.endAt,
                                ),
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _JoinEventButton(event: value),
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

class _JoinEventButton extends ConsumerWidget {
  const _JoinEventButton({required this.event});
  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regAsync = ref.watch(eventRegistrationStatusProvider(event.id));
    final actionState = ref.watch(registrationActionProvider);

    final isPast = event.startAt.isBefore(DateTime.now());
    final isFull = event.isFull;

    return regAsync.when(
      loading: () => const SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: null,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) {
        return _buildJoinButton(
          context: context,
          ref: ref,
          isPast: isPast,
          isFull: isFull,
          actionState: actionState,
        );
      },
      data: (reg) {
        if (reg != null && reg.isActive) {
          return SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TicketScreen(
                      registrationId: reg.id,
                      initialRegistration: reg,
                      initialEvent: event,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code),
              label: const Text('Xem Vé QR Của Bạn'),
            ),
          );
        }
        return _buildJoinButton(
          context: context,
          ref: ref,
          isPast: isPast,
          isFull: isFull,
          actionState: actionState,
        );
      },
    );
  }

  Widget _buildJoinButton({
    required BuildContext context,
    required WidgetRef ref,
    required bool isPast,
    required bool isFull,
    required AsyncValue<RegistrationModel?> actionState,
  }) {
    final canJoin = !isPast && !isFull && !actionState.isLoading;
    final label = isPast
        ? 'Sự kiện đã kết thúc'
        : isFull
        ? 'Đã hết chỗ'
        : actionState.isLoading
        ? 'Đang đăng ký...'
        : 'Tham gia sự kiện';

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: canJoin
            ? () async {
                try {
                  final createdReg = await ref
                      .read(registrationActionProvider.notifier)
                      .joinEvent(event);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đăng ký tham gia thành công!'),
                      ),
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TicketScreen(
                          registrationId: createdReg.id,
                          initialRegistration: createdReg,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            : null,
        icon: actionState.isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.confirmation_number_outlined),
        label: Text(label),
      ),
    );
  }
}
