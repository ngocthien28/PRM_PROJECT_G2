import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../shared/widgets/campus_scaffold.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/presentation/viewmodels/event_list_view_model.dart';
import '../../../notifications/presentation/viewmodels/notification_view_model.dart';
import '../../data/models/registration_model.dart';
import '../viewmodels/registration_view_model.dart';
import '../widgets/registration_status_chip.dart';
import 'ticket_screen.dart';

class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) ref.invalidate(myRegistrationsProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(myRegistrationsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registrationsAsync = ref.watch(myRegistrationsProvider);
    final user = ref.watch(currentUserProvider).asData?.value;

    return CampusScaffold(
      title: 'My Events',
      section: CampusSection.myEvents,
      userName: user?.displayName ?? 'Student',
      role: user?.role.name ?? 'student',
      unreadCount: ref.watch(unreadNotificationCountProvider),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: () => ref.read(myRegistrationsProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh_rounded, size: 21),
        ),
      ],
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: SectionHeading(
                  title: 'Sự kiện của tôi',
                  subtitle: 'Quản lý các sự kiện đã đăng ký và vé tham gia.',
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Sắp tới'),
                  Tab(text: 'Đã check-in'),
                  Tab(text: 'Đã hủy'),
                ],
              ),
              Expanded(
                child: registrationsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          Text('Lỗi: $error', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => ref
                                .read(myRegistrationsProvider.notifier)
                                .refresh(),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (registrations) {
                    final upcoming = registrations
                        .where((r) => r.isActive)
                        .toList();
                    final checkedIn = registrations
                        .where((r) => r.isCheckedIn)
                        .toList();
                    final cancelled = registrations
                        .where((r) => r.isCancelled)
                        .toList();

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(
                          upcoming,
                          'Bạn chưa đăng ký sự kiện sắp tới nào',
                        ),
                        _buildList(
                          checkedIn,
                          'Chưa có sự kiện nào được check-in',
                        ),
                        _buildList(cancelled, 'Không có sự kiện đã hủy'),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<RegistrationModel> items, String emptyMessage) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => context.go(RouteNames.events),
                child: const Text('Khám phá sự kiện ngay'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(myRegistrationsProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final reg = items[index];
          return _RegistrationCard(registration: reg);
        },
      ),
    );
  }
}

class _RegistrationCard extends ConsumerWidget {
  const _RegistrationCard({required this.registration});

  final RegistrationModel registration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<EventModel>(
      future: ref
          .read(eventRepositoryProvider)
          .getEventById(registration.eventId),
      builder: (context, snapshot) {
        final event = snapshot.data;

        return Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () =>
                context.push(RouteNames.eventDetail(registration.eventId)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RegistrationStatusChip(status: registration.status),
                      if (registration.isFromCache) const Text('Offline'),
                      Text(
                        DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(registration.registeredAt.toLocal()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event?.title ?? 'Đang tải thông tin sự kiện...',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (event != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.locationName,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(event.startAt.toLocal()),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (registration.canCancel && !registration.isFromCache)
                        TextButton.icon(
                          key: const Key('myEventsCancelTicketButton'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                          ),
                          onPressed: () => _confirmCancelRegistration(
                            context,
                            ref,
                            registration,
                          ),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Hủy vé'),
                        ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TicketScreen(
                                registrationId: registration.id,
                                initialRegistration: registration,
                                initialEvent: event,
                              ),
                            ),
                          );
                          if (context.mounted) {
                            ref.invalidate(myRegistrationsProvider);
                          }
                        },
                        icon: const Icon(Icons.qr_code, size: 18),
                        label: const Text('Xem Vé QR'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmCancelRegistration(
    BuildContext context,
    WidgetRef ref,
    RegistrationModel registration,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đăng ký sự kiện?'),
        content: const Text(
          'Bạn có chắc chắn muốn hủy vé đăng ký sự kiện này không? Chỗ trống sẽ được nhường cho sinh viên khác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(registrationActionProvider.notifier)
            .cancelRegistration(
              registrationId: registration.id,
              eventId: registration.eventId,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hủy đăng ký thành công')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
