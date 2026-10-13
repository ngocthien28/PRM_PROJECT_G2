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
          final membershipAsync = user == null
              ? null
              : ref.watch(
                  clubMembershipProvider((clubId: club.id, userId: user.uid)),
                );
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
              if (user?.role.name == 'student' && membershipAsync != null)
                membershipAsync.when(
                  loading: () => const FilledButton(
                    onPressed: null,
                    child: Text('Checking membership...'),
                  ),
                  error: (error, _) => OutlinedButton.icon(
                    onPressed: () => ref.invalidate(
                      clubMembershipProvider((
                        clubId: club.id,
                        userId: user!.uid,
                      )),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry membership status'),
                  ),
                  data: (membership) => FilledButton(
                    onPressed: busy
                        ? null
                        : () => action(() async {
                            final repository = ref.read(clubRepositoryProvider);
                            if (membership?.isActive == true) {
                              await repository.leaveClub(
                                clubId: club.id,
                                actor: user!,
                              );
                            } else {
                              await repository.joinClub(
                                clubId: club.id,
                                actor: user!,
                              );
                            }
                            ref.invalidate(
                              clubMembershipProvider((
                                clubId: club.id,
                                userId: user.uid,
                              )),
                            );
                            ref.invalidate(clubProvider(club.id));
                          }),
                    child: Text(
                      membership?.isActive == true ? 'Leave Club' : 'Join Club',
                    ),
                  ),
                ),
              if (manage) ...[
                OutlinedButton(
                  onPressed: () =>
                      context.push(RouteNames.editClub(club.id), extra: club),
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
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(RouteNames.clubs);
                              }
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
