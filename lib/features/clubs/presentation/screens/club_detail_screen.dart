import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../viewmodels/club_view_model.dart';

class ClubDetailScreen extends ConsumerStatefulWidget {
  const ClubDetailScreen({super.key, required this.clubId});
  final String clubId;
  @override
  ConsumerState<ClubDetailScreen> createState() => _State();
}

class _State extends ConsumerState<ClubDetailScreen> {
  bool busy = false;
  Future<void> action(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(clubProvider(widget.clubId)),
        user = ref.watch(currentUserProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Club Detail')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (club) {
          if (club == null) return const Center(child: Text('Club not found.'));
          final manage =
              user != null &&
              (user.role.name == 'admin' || club.ownerId == user.uid);
          final membership = user == null
              ? null
              : ref
                    .watch(
                      clubMembershipProvider((
                        clubId: club.id,
                        userId: user.uid,
                      )),
                    )
                    .asData
                    ?.value;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (club.logoUrl != null)
                Image.network(club.logoUrl!, height: 180),
              Text(
                club.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(club.description),
              Text('${club.memberCount} members'),
              const SizedBox(height: 20),
              if (user?.role.name == 'student')
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => action(
                          () => membership?.isActive == true
                              ? ref
                                    .read(clubRepositoryProvider)
                                    .leaveClub(clubId: club.id, actor: user!)
                              : ref
                                    .read(clubRepositoryProvider)
                                    .joinClub(clubId: club.id, actor: user!),
                        ),
                  child: Text(
                    membership?.isActive == true ? 'Leave Club' : 'Join Club',
                  ),
                ),
              if (manage) ...[
                OutlinedButton(
                  onPressed: () =>
                      context.go(RouteNames.editClub(club.id), extra: club),
                  child: const Text('Edit Club'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Cancel Club?'),
                              content: const Text(
                                'This keeps history but hides the Club.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('No'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Cancel Club'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await action(() async {
                              await ref
                                  .read(clubRepositoryProvider)
                                  .cancelClub(clubId: club.id, actor: user);
                              if (!context.mounted) return;
                              context.go(RouteNames.clubs);
                            });
                          }
                        },
                  child: const Text('Cancel Club'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
