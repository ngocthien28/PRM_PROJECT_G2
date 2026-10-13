import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../viewmodels/club_view_model.dart';

class ClubListScreen extends ConsumerWidget {
  const ClubListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clubsProvider);
    final user = ref.watch(currentUserProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Clubs')),
      floatingActionButton: user?.role.canOrganize == true
          ? FloatingActionButton(
              onPressed: () => context.push(RouteNames.createClub),
              child: const Icon(Icons.add),
            )
          : null,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(clubsProvider),
            child: Text('Retry: $error'),
          ),
        ),
        data: (clubs) => clubs.isEmpty
            ? const Center(child: Text('No active Clubs yet.'))
            : LayoutBuilder(
                builder: (_, box) => GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: box.maxWidth >= 700 ? 2 : 1,
                    childAspectRatio: 3,
                  ),
                  itemCount: clubs.length,
                  itemBuilder: (_, index) {
                    final club = clubs[index];
                    return Card(
                      child: ListTile(
                        leading: club.logoUrl == null
                            ? const CircleAvatar(child: Icon(Icons.groups))
                            : CircleAvatar(
                                backgroundImage: NetworkImage(club.logoUrl!),
                              ),
                        title: Text(club.name),
                        subtitle: Text(
                          '${club.memberCount} members\n${club.description}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () =>
                            context.push(RouteNames.clubDetail(club.id)),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
