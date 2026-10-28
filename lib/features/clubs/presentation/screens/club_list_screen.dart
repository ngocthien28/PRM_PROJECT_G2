import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/campus_scaffold.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../notifications/presentation/viewmodels/notification_view_model.dart';
import '../../data/models/club_model.dart';
import '../viewmodels/club_view_model.dart';

class ClubListScreen extends ConsumerStatefulWidget {
  const ClubListScreen({super.key});
  @override
  ConsumerState<ClubListScreen> createState() => _ClubListScreenState();
}

class _ClubListScreenState extends ConsumerState<ClubListScreen> {
  String _query = '';
  bool _popular = false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clubsProvider);
    final user = ref.watch(currentUserProvider).asData?.value;
    final canCreate = user?.role.canOrganize == true;
    return CampusScaffold(
      title: 'Clubs',
      section: CampusSection.clubs,
      userName: user?.displayName ?? 'Campus member',
      role: user?.role.name ?? 'student',
      unreadCount: ref.watch(unreadNotificationCountProvider),
      onBack: () => context.go(campusHome(user?.role.name ?? 'student')),
      body: CampusPage(
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: CampusColors.ink,
              borderRadius: BorderRadius.circular(24),
            ),
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  if (box.maxWidth > 620)
                    const Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 300,
                      child: CampusArtwork(),
                    ),
                  Padding(
                    padding: EdgeInsets.all(box.maxWidth < 600 ? 24 : 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FIND YOUR PEOPLE',
                          style: TextStyle(
                            color: CampusColors.gold,
                            fontSize: 10,
                            letterSpacing: 2.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Small interests.\nBig connections.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: box.maxWidth < 600 ? 32 : 40,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Find a community that feels like you.',
                          style: TextStyle(
                            color: Color(0xFFC2D6CC),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: CampusColors.gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${state.asData?.value.length ?? 0} active clubs to explore',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
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
          const SizedBox(height: 28),
          SectionHeading(
            title: 'Explore communities',
            subtitle: 'A shared interest is all it takes to get started.',
            trailing: canCreate
                ? FilledButton.icon(
                    onPressed: () => context.push(RouteNames.createClub),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Club'),
                  )
                : null,
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, box) {
              final search = TextField(
                key: const Key('club-search'),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search for your next community',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              );
              final filters = Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All clubs'),
                    selected: !_popular,
                    onSelected: (_) => setState(() => _popular = false),
                  ),
                  ChoiceChip(
                    label: const Text('Most members'),
                    selected: _popular,
                    onSelected: (_) => setState(() => _popular = true),
                  ),
                ],
              );
              if (box.maxWidth < 650) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [search, const SizedBox(height: 12), filters],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 18),
                  filters,
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          state.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(64),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => CampusEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'A little connection hiccup',
              message:
                  'We could not load the club directory. Check your connection and try again.',
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(clubsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
            data: (clubs) {
              final visible = clubs
                  .where(
                    (c) =>
                        c.name.toLowerCase().contains(_query) ||
                        c.description.toLowerCase().contains(_query),
                  )
                  .toList();
              if (_popular) {
                visible.sort((a, b) => b.memberCount.compareTo(a.memberCount));
              }
              if (visible.isEmpty) {
                return CampusEmptyState(
                  icon: Icons.groups_outlined,
                  title: _query.isEmpty
                      ? 'Great communities start with someone'
                      : 'No clubs found',
                  message: _query.isEmpty
                      ? 'There are no active clubs yet. Come back soon to find your people.'
                      : 'Try a different name or interest to find a community.',
                  action: canCreate && _query.isEmpty
                      ? FilledButton.icon(
                          onPressed: () => context.push(RouteNames.createClub),
                          icon: const Icon(Icons.add),
                          label: const Text('Create the first club'),
                        )
                      : null,
                );
              }
              return LayoutBuilder(
                builder: (context, box) {
                  final columns = box.maxWidth >= 960
                      ? 3
                      : box.maxWidth >= 580
                      ? 2
                      : 1;
                  final width = (box.maxWidth - (columns - 1) * 18) / columns;
                  return Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      for (final club in visible)
                        SizedBox(
                          width: width,
                          child: _ClubCard(club: club),
                        ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 15,
                color: CampusColors.muted,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Built around shared interests. Open to new connections.',
                  style: TextStyle(color: CampusColors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({required this.club});
  final ClubModel club;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push(RouteNames.clubDetail(club.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 155,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClubCover(name: club.name, url: club.logoUrl),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 6, color: CampusColors.teal),
                        SizedBox(width: 5),
                        Text(
                          'Open community',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  club.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CampusColors.muted,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline_rounded,
                      color: CampusColors.teal,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${club.memberCount} ${club.memberCount == 1 ? 'member' : 'members'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Text(
                      'Explore',
                      style: TextStyle(
                        color: CampusColors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_outward_rounded,
                      size: 17,
                      color: CampusColors.teal,
                    ),
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

class ClubCover extends StatelessWidget {
  const ClubCover({super.key, required this.name, this.url});
  final String name;
  final String? url;
  @override
  Widget build(BuildContext context) {
    final palette = [
      CampusColors.ink,
      const Color(0xFF365561),
      const Color(0xFF756448),
    ];
    final colorIndex =
        name.runes.fold<int>(0, (sum, value) => sum + value) % palette.length;
    final fallback = Container(
      color: palette[colorIndex],
      child: Stack(
        children: [
          const Positioned.fill(child: CampusArtwork()),
          Positioned(
            left: 24,
            bottom: 20,
            child: Text(
              name.trim().isEmpty
                  ? 'C'
                  : name.trim().substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 58,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
