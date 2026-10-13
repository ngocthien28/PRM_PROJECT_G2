import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/campus_scaffold.dart';
import '../../../auth/data/models/app_user.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../admin/presentation/widgets/report_content_button.dart';
import '../../../notifications/presentation/viewmodels/notification_view_model.dart';
import '../../data/models/club_membership.dart';
import '../../data/models/club_model.dart';
import '../../domain/usecases/deactivate_club.dart';
import '../viewmodels/club_view_model.dart';
import 'club_list_screen.dart';

class ClubDetailScreen extends ConsumerStatefulWidget {
  const ClubDetailScreen({super.key, required this.clubId});
  final String clubId;
  @override
  ConsumerState<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends ConsumerState<ClubDetailScreen> {
  bool _busy = false;
  Future<void> _action(Future<void> Function() work) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await work();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(ClubModel club, AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const Icon(
          Icons.pause_circle_outline_rounded,
          color: Color(0xFFB15C39),
          size: 32,
        ),
        title: const Text('Cancel Club?'),
        content: Text(
          '${club.name} will be hidden from the club directory. Membership history will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep club'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Cancel Club'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _action(() async {
      await DeactivateClub(
        ref.read(firestoreProvider),
      )(clubId: club.id, actor: user);
      if (!mounted) return;
      context.go(RouteNames.clubs);
    });
  }

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Tính quyền quản lý từ role organizer/admin và owner để chọn UI quản lý club.
  /// ROLE: Cross-module role/access integration
  /// CALLED FROM: ClubDetailScreen state.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, Riverpod, go_router.
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final state = ref.watch(clubProvider(widget.clubId));
    final membership = user == null
        ? null
        : ref.watch(
            clubMembershipProvider((clubId: widget.clubId, userId: user.uid)),
          );
    return CampusScaffold(
      title: 'Club Detail',
      section: CampusSection.clubs,
      role: user?.role.name ?? 'student',
      userName: user?.displayName ?? 'Campus member',
      unreadCount: ref.watch(unreadNotificationCountProvider),
      onBack: () => context.go(RouteNames.clubs),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => CampusPage(
          children: [
            CampusEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'We could not load this club',
              message: 'Check your connection and try again.',
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(clubProvider(widget.clubId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
        data: (club) {
          if (club == null) {
            return const CampusPage(
              children: [
                CampusEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Club not found',
                  message:
                      'This community may no longer be available in the directory.',
                ),
              ],
            );
          }
          final manage =
              user != null &&
              user.role.canOrganize &&
              (user.role.name == 'admin' || club.ownerId == user.uid);
          return CampusPage(
            children: [
              const Text(
                'COMMUNITIES / CLUB PROFILE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.7,
                  color: CampusColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: SizedBox(
                  height:
                      258 +
                      (MediaQuery.textScalerOf(context).scale(35) - 35).clamp(
                            0,
                            100,
                          ) *
                          3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClubCover(name: club.name, url: club.logoUrl),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x35173832), Color(0xEF173832)],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                club.isActive
                                    ? 'CAMPUS COMMUNITY'
                                    : 'INACTIVE COMMUNITY',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  letterSpacing: 1.6,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              club.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 35,
                                letterSpacing: -1.2,
                                fontWeight: FontWeight.w800,
                                height: 1.12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.people_outline_rounded,
                                      size: 17,
                                      color: CampusColors.gold,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      '${club.memberCount} ${club.memberCount == 1 ? 'member' : 'members'}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: CampusColors.gold,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      club.isActive
                                          ? 'Open to connections'
                                          : 'Not accepting members',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
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
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, box) {
                  final about = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.short_text_rounded,
                                    color: CampusColors.teal,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'About this club',
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                club.description,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.8,
                                  color: Color(0xFF586B61),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 24,
                                runSpacing: 12,
                                children: [
                                  _DetailFact(
                                    icon: Icons.calendar_today_outlined,
                                    label: 'On CampusHub since',
                                    value: DateFormat(
                                      'MMM yyyy',
                                    ).format(club.createdAt.toLocal()),
                                  ),
                                  _DetailFact(
                                    icon: Icons.verified_outlined,
                                    label: 'Community status',
                                    value: club.isActive
                                        ? 'Active club'
                                        : 'Inactive club',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: CampusColors.mint,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.favorite_border_rounded,
                              size: 21,
                              color: CampusColors.teal,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'A community is better with you in it.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Be curious, be kind, and bring your own perspective.',
                                    style: TextStyle(
                                      color: CampusColors.muted,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final panel = _membershipPanel(
                    club,
                    user,
                    membership,
                    manage,
                  );
                  if (box.maxWidth < 740) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [panel, const SizedBox(height: 18), about],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: about),
                      const SizedBox(width: 22),
                      SizedBox(width: 300, child: panel),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Dựng Join/Leave cho student; Edit/Cancel cho nhánh manage đã tính từ role/owner.
  /// ROLE: Cross-module role/access integration
  /// CALLED FROM: ClubDetailScreen.build.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, Riverpod, go_router.
  Widget _membershipPanel(
    ClubModel club,
    AppUser? user,
    AsyncValue<ClubMembership?>? membership,
    bool manage,
  ) {
    final joined = membership?.asData?.value?.isActive == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CampusColors.mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  manage
                      ? Icons.tune_rounded
                      : joined
                      ? Icons.check_circle_outline_rounded
                      : Icons.waving_hand_outlined,
                  color: CampusColors.teal,
                  size: 27,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              manage
                  ? 'Your club workspace'
                  : joined
                  ? 'You belong here.'
                  : 'Make yourself at home.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              manage
                  ? 'Keep your community details fresh and welcoming.'
                  : joined
                  ? 'You are an active member of this community. Your membership is saved to your account.'
                  : 'Join the club to be part of this campus community. You can leave whenever you need to.',
              style: const TextStyle(
                color: CampusColors.muted,
                fontSize: 13,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 22),
            if (user?.role.name == 'student' && membership != null)
              membership.when(
                loading: () => const FilledButton(
                  onPressed: null,
                  child: Text('Checking membership...'),
                ),
                error: (_, _) => OutlinedButton.icon(
                  onPressed: () => ref.invalidate(
                    clubMembershipProvider((
                      clubId: club.id,
                      userId: user!.uid,
                    )),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry membership status'),
                ),
                data: (value) => FilledButton.icon(
                  style: value?.isActive == true
                      ? FilledButton.styleFrom(
                          backgroundColor: CampusColors.mint,
                          foregroundColor: CampusColors.teal,
                        )
                      : null,
                  onPressed: _busy || !club.isActive
                      ? null
                      : () => _action(() async {
                          final repo = ref.read(clubRepositoryProvider);
                          if (value?.isActive == true) {
                            await repo.leaveClub(clubId: club.id, actor: user!);
                          } else {
                            await repo.joinClub(clubId: club.id, actor: user!);
                          }
                          if (!mounted) return;
                          // The existing Firestore listeners deliver the committed
                          // changes; reconnecting them causes a redundant reload.
                        }),
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          value?.isActive == true
                              ? Icons.logout_rounded
                              : Icons.add_rounded,
                          size: 18,
                        ),
                  label: Text(
                    value?.isActive == true ? 'Leave Club' : 'Join Club',
                  ),
                ),
              ),
            if (manage && user != null) ...[
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => context.push(
                        RouteNames.editClub(club.id),
                        extra: club,
                      ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Club'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy || !club.isActive
                    ? null
                    : () => _cancel(club, user),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFA44E36),
                ),
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                label: const Text('Cancel Club'),
              ),
            ],
            if (user != null && !manage) ...[
              const SizedBox(height: 10),
              ReportContentButton(
                targetType: 'club',
                targetId: club.id,
                targetLabel: club.name,
                expand: true,
              ),
            ],
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 15),
            const Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: CampusColors.muted,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Connected to your CampusHub account',
                    style: TextStyle(color: CampusColors.muted, fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailFact extends StatelessWidget {
  const _DetailFact({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20, color: CampusColors.teal),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: CampusColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ],
  );
}
