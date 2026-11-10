import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/event_categories.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../local/dao/recent_view_dao.dart';
import '../../../../shared/enums/event_status.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../admin/presentation/widgets/report_content_button.dart';
import '../../../favorites/presentation/viewmodels/favorite_view_model.dart';
import '../../../registration/data/models/registration_model.dart';
import '../../../registration/presentation/screens/ticket_screen.dart';
import '../../../registration/presentation/viewmodels/registration_view_model.dart';
import '../../../checkin/presentation/screens/qr_scanner_screen.dart';
import '../../data/models/event_model.dart';
import '../viewmodels/event_detail_view_model.dart';
import '../viewmodels/event_list_view_model.dart';
import '../widgets/event_poster.dart';
import '../widgets/event_results.dart';
import '../widgets/event_format.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.managed = false,
  });
  final String eventId;
  final bool managed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailProvider = managed
        ? managedEventDetailProvider(eventId)
        : eventDetailProvider(eventId);
    final event = ref.watch(detailProvider);
    final isFav = managed ? false : ref.watch(isFavoriteProvider(eventId));
    final toggleState = managed
        ? const FavoriteToggleState()
        : ref.watch(favoriteToggleProvider(eventId));

    // ── UC-086: Record view history for student ─────────────────────────
    if (!managed) {
      final user = ref.watch(currentUserProvider).asData?.value;
      if (user != null) {
        Future.microtask(() async {
          await ref
              .read(recentViewDaoProvider)
              .recordView(eventId: eventId, userId: user.uid);
          ref.invalidate(recentlyViewedEventsProvider);
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(
          fallbackLocation: managed
              ? RouteNames.organizerManagedEvents
              : RouteNames.home,
        ),
        title: const Text('Event details'),
        actions: [
          // ── UC-025: Nút yêu thích ──────────────────────────────────
          if (!managed)
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
                          ref.read(favoriteToggleProvider(eventId)).error !=
                              null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ref.read(favoriteToggleProvider(eventId)).error!,
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
            onPressed: () => ref.invalidate(detailProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: event.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EventFailure(
          error: error,
          onRetry: () => ref.invalidate(detailProvider),
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
                  if (value.status == EventStatus.cancelled) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cancel_rounded,
                            color: Colors.red.shade700,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sự kiện đã bị hủy',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sự kiện này đã bị hủy bởi ban tổ chức hoặc ban quản trị.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                              const SizedBox(height: 20),
                              if (!managed)
                                _JoinEventButton(event: value)
                              else if (value.status !=
                                  EventStatus.cancelled) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    key: const Key('organizerScanQrButton'),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => QrScannerScreen(
                                            eventId: value.id,
                                            eventTitle: value.title,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.qr_code_scanner),
                                    label: const Text(
                                      'Quét QR Check-in Điểm Danh',
                                    ),
                                  ),
                                ),
                              ],
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
                  // ── UC-085: Sự kiện liên quan ──────────────────────────
                  if (!managed) ...[
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ReportContentButton(
                        targetType: 'event',
                        targetId: value.id,
                        targetLabel: value.title,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _RelatedEventsSection(
                      currentEventId: value.id,
                      category: value.category,
                    ),
                  ],
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

    // Cancellation is an event fact, so do not hide its disabled action behind
    // registration/profile loading or an unrelated registration read failure.
    if (event.status == EventStatus.cancelled) {
      return _buildJoinButton(
        context: context,
        ref: ref,
        isPast: isPast,
        isFull: isFull,
        actionState: actionState,
      );
    }

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
        return OutlinedButton.icon(
          onPressed: () =>
              ref.invalidate(eventRegistrationStatusProvider(event.id)),
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại trạng thái đăng ký'),
        );
      },
      data: (reg) {
        if (reg != null && (reg.isActive || reg.isCheckedIn)) {
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
    final isCancelled = event.status == EventStatus.cancelled;
    final canJoin =
        !isPast && !isFull && event.isPublished && !actionState.isLoading;
    final label = isCancelled
        ? 'Sự kiện đã bị hủy'
        : isPast
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
          backgroundColor: isCancelled ? Colors.grey.shade400 : null,
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

// ── UC-085: Provider & Widgets cho Sự kiện liên quan ─────────────────────────

final relatedEventsProvider = FutureProvider.autoDispose
    .family<List<EventModel>, ({String eventId, String category})>((
      ref,
      arg,
    ) async {
      final repo = ref.watch(eventReadRepositoryProvider);
      return repo.getRelatedEvents(
        eventId: arg.eventId,
        category: arg.category,
        limit: 4,
      );
    });

class _RelatedEventsSection extends ConsumerWidget {
  const _RelatedEventsSection({
    required this.currentEventId,
    required this.category,
  });

  final String currentEventId;
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatedAsync = ref.watch(
      relatedEventsProvider((eventId: currentEventId, category: category)),
    );
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return relatedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 48),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Sự kiện liên quan',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${EventCategories.label(category)})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 235,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final related = events[index];
                  return _RelatedEventCard(event: related);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RelatedEventCard extends StatelessWidget {
  const _RelatedEventCard({required this.event});
  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      key: ValueKey('related-${event.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withAlpha(80)),
      ),
      child: InkWell(
        onTap: () => context.push(RouteNames.eventDetail(event.id)),
        child: SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 110,
                child: EventPoster(
                  url: event.posterUrl,
                  category: event.category,
                  height: 110,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            eventDateTime(context, event.startAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.locationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
