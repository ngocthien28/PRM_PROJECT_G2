import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/campus_scaffold.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../data/models/app_notification.dart';
import '../viewmodels/notification_view_model.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});
  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  final Set<String> _saving = {};
  bool _unreadOnly = false;

  Future<void> _open(AppNotification item) async {
    if (_saving.contains(item.id)) return;
    if (!item.isRead) {
      setState(() => _saving.add(item.id));
      try {
        await ref.read(notificationRepositoryProvider).markRead(item.id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not mark as read. Please retry.'),
            ),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _saving.remove(item.id));
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const CircleAvatar(
          backgroundColor: CampusColors.mint,
          child: Icon(Icons.groups_outlined, color: CampusColors.teal),
        ),
        title: Text(item.title),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.body, style: const TextStyle(height: 1.7)),
            const SizedBox(height: 20),
            Text(
              DateFormat(
                'dd MMM yyyy · HH:mm',
              ).format(item.createdAt.toLocal()),
              style: const TextStyle(fontSize: 11, color: CampusColors.muted),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(notificationInboxProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final user = ref.watch(currentUserProvider).asData?.value;
    return CampusScaffold(
      title: 'Notifications',
      section: CampusSection.inbox,
      userName: user?.displayName ?? 'Campus member',
      role: user?.role.name ?? 'student',
      unreadCount: unread,
      onBack: () => context.go(campusHome(user?.role.name ?? 'student')),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(notificationInboxProvider),
          icon: const Icon(Icons.refresh_rounded, size: 21),
        ),
      ],
      body: CampusPage(
        children: [
          const Text(
            'YOUR PERSONAL INBOX',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              color: CampusColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your campus, in the loop.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          const Text(
            'Small updates that keep you connected to your communities.',
            style: TextStyle(color: CampusColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, box) {
              final main = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('All updates'),
                            selected: !_unreadOnly,
                            onSelected: (_) =>
                                setState(() => _unreadOnly = false),
                          ),
                          FilterChip(
                            label: const Text('Unread only'),
                            selected: _unreadOnly,
                            onSelected: (value) =>
                                setState(() => _unreadOnly = value),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0D5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFFAE7D24),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '$unread unread',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF91691E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  inbox.when(
                    skipLoadingOnRefresh: false,
                    loading: () => const Padding(
                      padding: EdgeInsets.all(64),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => CampusEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Could not load notifications.',
                      message:
                          'Your updates are safe. Check your connection and give it another try.',
                      action: FilledButton.icon(
                        onPressed: () =>
                            ref.invalidate(notificationInboxProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ),
                    data: (items) {
                      final visible = items
                          .where((n) => !_unreadOnly || !n.isRead)
                          .toList();
                      if (visible.isEmpty) {
                        return CampusEmptyState(
                          icon: _unreadOnly
                              ? Icons.done_all_rounded
                              : Icons.mark_email_unread_outlined,
                          title: _unreadOnly
                              ? 'You are all caught up'
                              : 'No notifications yet',
                          message: _unreadOnly
                              ? 'A clear inbox, a little peace of mind. New updates will appear here.'
                              : 'Join a club and make your first connection. Your membership updates will appear here.',
                          action: !_unreadOnly
                              ? OutlinedButton.icon(
                                  onPressed: () =>
                                      context.push(RouteNames.clubs),
                                  icon: const Icon(
                                    Icons.groups_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Explore clubs'),
                                )
                              : null,
                        );
                      }
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < visible.length;
                              index++
                            ) ...[
                              if (index > 0) const Divider(),
                              _InboxRow(
                                item: visible[index],
                                saving: _saving.contains(visible[index].id),
                                onTap: () => _open(visible[index]),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 13,
                          color: CampusColors.muted,
                        ),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Only you can see the notifications in this inbox.',
                            style: TextStyle(
                              fontSize: 10,
                              color: CampusColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final aside = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: CampusColors.ink,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 135, child: CampusArtwork()),
                        const SizedBox(height: 14),
                        const Text(
                          'Good things\nkeep you connected.',
                          style: TextStyle(
                            fontSize: 25,
                            height: 1.15,
                            letterSpacing: -.8,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Club memberships, campus moments, and the updates that matter to you.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.7,
                            color: Color(0xFFBCD1C5),
                          ),
                        ),
                        const SizedBox(height: 22),
                        OutlinedButton.icon(
                          onPressed: () => context.push(RouteNames.clubs),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CampusColors.gold,
                            side: const BorderSide(color: Color(0xFF597B69)),
                          ),
                          icon: const Icon(
                            Icons.arrow_outward_rounded,
                            size: 17,
                          ),
                          label: const Text('Find a community'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.touch_app_outlined,
                            color: CampusColors.teal,
                            size: 25,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'A simpler inbox',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap an update to read the full message. It is marked as read and saved across your devices.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.7,
                              color: CampusColors.muted,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Divider(),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Saved updates',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: CampusColors.muted,
                                  ),
                                ),
                              ),
                              Text(
                                '${inbox.asData?.value.length ?? 0}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
              if (box.maxWidth < 860) return main;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: main),
                  const SizedBox(width: 24),
                  SizedBox(width: 280, child: aside),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.item,
    required this.saving,
    required this.onTap,
  });
  final AppNotification item;
  final bool saving;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: item.isRead ? Colors.white : const Color(0xFFF1F7F2),
    child: InkWell(
      key: ValueKey('notification-${item.id}'),
      onTap: saving ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: item.isRead ? CampusColors.canvas : CampusColors.mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                item.type == 'club_membership'
                    ? Icons.groups_outlined
                    : Icons.notifications_outlined,
                size: 22,
                color: CampusColors.teal,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: item.isRead
                          ? FontWeight.w600
                          : FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.body,
                    style: const TextStyle(
                      color: Color(0xFF6D7D73),
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        DateFormat(
                          'dd MMM · HH:mm',
                        ).format(item.createdAt.toLocal()),
                        style: const TextStyle(
                          color: CampusColors.muted,
                          fontSize: 10,
                        ),
                      ),
                      if (item.isRead)
                        const Text(
                          'Read',
                          style: TextStyle(
                            color: CampusColors.teal,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (saving)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (!item.isRead)
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Icon(Icons.circle, size: 7, color: CampusColors.teal),
              )
            else
              const Icon(
                Icons.done_all_rounded,
                size: 17,
                color: CampusColors.muted,
              ),
          ],
        ),
      ),
    ),
  );
}
