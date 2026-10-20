import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/event_categories.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/campus_scaffold.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/data/models/event_filter.dart';
import '../../../events/presentation/viewmodels/event_list_view_model.dart';
import '../../../events/presentation/widgets/event_results.dart';
import '../../../../shared/widgets/role_navigation_actions.dart';
import '../../../notifications/presentation/viewmodels/notification_view_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final action = ref.watch(authViewModelProvider);
    final events = ref.watch(homeEventsProvider);
    Future<void> refresh() async {
      try {
        ref.invalidate(homeEventsProvider);
        await ref.read(homeEventsProvider.future);
      } catch (_) {}
    }

    void browse([String? category]) {
      ref
          .read(eventFilterProvider.notifier)
          .setFilter(EventFilter(category: category));
      context.push(RouteNames.events);
    }

    return CampusScaffold(
      title: 'CampusHub',
      section: CampusSection.home,
      userName: user?.displayName ?? 'Student',
      role: user?.role.name ?? 'student',
      unreadCount: ref.watch(unreadNotificationCountProvider),
      onSignOut: ref.read(authViewModelProvider.notifier).signOut,
      signingOut: action.isLoading,
      actions: [
        const RoleNavigationActions(),
        IconButton(
          tooltip: 'My profile',
          onPressed: () => context.push(RouteNames.profile),
          icon: const Icon(Icons.account_circle_outlined, size: 22),
        ),
        IconButton(
          tooltip: 'My events',
          onPressed: () => context.go(RouteNames.myEvents),
          icon: const Icon(Icons.confirmation_number_outlined, size: 22),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: refresh,
        child: CampusPage(
          children: [
            if (action.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  action.error.toString(),
                  key: const Key('auth-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MAKE YOURSELF AT HOME',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 2,
                          color: CampusColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Welcome, ${user?.displayName ?? "Student"}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.waving_hand_outlined,
                  color: Color(0xFFBA8A37),
                  size: 27,
                ),
              ],
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, box) => Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: CampusColors.ink,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Stack(
                  children: [
                    if (box.maxWidth > 610)
                      const Positioned(
                        right: 12,
                        top: 2,
                        bottom: 2,
                        width: 310,
                        child: CampusArtwork(),
                      ),
                    Padding(
                      padding: EdgeInsets.all(box.maxWidth < 600 ? 26 : 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF5D7F6D),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'A CAMPUS FULL OF POSSIBILITIES',
                              style: TextStyle(
                                color: CampusColors.gold,
                                fontSize: 8,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Your next chapter\nstarts on campus.',
                            style: TextStyle(
                              fontSize: box.maxWidth < 600 ? 31 : 43,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.6,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'New interests. Familiar faces. A place to belong.',
                            style: TextStyle(
                              color: Color(0xFFC2D6CC),
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: browse,
                                style: FilledButton.styleFrom(
                                  backgroundColor: CampusColors.gold,
                                  foregroundColor: CampusColors.ink,
                                ),
                                icon: const Icon(
                                  Icons.arrow_outward_rounded,
                                  size: 18,
                                ),
                                label: const Text('Browse events'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.push(RouteNames.favorites),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Color(0xFF5D7F6D),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.favorite_border,
                                  size: 18,
                                ),
                                label: const Text('Favorites'),
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
            const SizedBox(height: 28),
            const SectionHeading(
              title: 'Follow your curiosity',
              subtitle: 'Explore by interest',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: EventCategories.labels.entries
                  .map(
                    (category) => ActionChip(
                      avatar: Icon(
                        switch (category.key) {
                          'technology' => Icons.memory_rounded,
                          'sport' => Icons.sports_basketball_outlined,
                          'workshop' => Icons.lightbulb_outline_rounded,
                          _ => Icons.music_note_outlined,
                        },
                        size: 18,
                        color: CampusColors.teal,
                      ),
                      label: Text(category.value),
                      onPressed: () => browse(category.key),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 28),
            SectionHeading(
              title: 'Coming up on campus',
              subtitle: 'Good plans are better with good company.',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Refresh events',
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                  TextButton(onPressed: browse, child: const Text('View all')),
                ],
              ),
            ),
            const SizedBox(height: 18),
            EventResults(
              events: events.whenData((items) => items.take(4).toList()),
              onRetry: refresh,
            ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: CampusColors.mint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final text = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Find a little more belonging.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Meet the people who share your interests.',
                        style: TextStyle(
                          fontSize: 12,
                          color: CampusColors.muted,
                        ),
                      ),
                    ],
                  );
                  final button = OutlinedButton.icon(
                    onPressed: () => context.push(RouteNames.clubs),
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('Explore clubs'),
                  );
                  if (box.maxWidth < 500) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [text, const SizedBox(height: 16), button],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: text),
                      const SizedBox(width: 16),
                      button,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
