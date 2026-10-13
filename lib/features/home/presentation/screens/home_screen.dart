import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/event_categories.dart';
import '../../../../core/routing/route_names.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/data/models/event_filter.dart';
import '../../../events/presentation/viewmodels/event_list_view_model.dart';
import '../../../events/presentation/widgets/event_results.dart';
import '../../../../shared/widgets/role_navigation_actions.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final action = ref.watch(authViewModelProvider);
    final events = ref.watch(homeEventsProvider);
    final colors = Theme.of(context).colorScheme;
    Future<void> refresh() async {
      try {
        ref.invalidate(homeEventsProvider);
        await ref.read(homeEventsProvider.future);
      } catch (_) {
        // The result section displays the provider error with a retry action.
      }
    }

    void browse([String? category]) {
      ref
          .read(eventFilterProvider.notifier)
          .setFilter(EventFilter(category: category));
      context.push(RouteNames.events);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusHub'),
        actions: [
          const RoleNavigationActions(),
          IconButton(
            tooltip: 'Sự kiện của tôi',
            onPressed: () => context.push(RouteNames.myEvents),
            icon: const Icon(Icons.confirmation_number_outlined),
          ),
          TextButton.icon(
            onPressed: action.isLoading
                ? null
                : ref.read(authViewModelProvider.notifier).signOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (action.hasError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        action.error.toString(),
                        key: const Key('auth-error'),
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CAMPUS LIFE',
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome, ${user?.displayName ?? "Student"}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: colors.onPrimaryContainer),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Meet new people. Learn something new.\nFind your next campus event.',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: browse,
                          icon: const Icon(Icons.explore_outlined),
                          label: const Text('Browse events'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Explore by interest',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: EventCategories.labels.entries
                        .map(
                          (category) => ActionChip(
                            label: Text(category.value),
                            onPressed: () => browse(category.key),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Coming up on campus',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh events',
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                      TextButton(
                        onPressed: browse,
                        child: const Text('View all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  EventResults(
                    events: events.whenData((items) => items.take(4).toList()),
                    onRetry: refresh,
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
