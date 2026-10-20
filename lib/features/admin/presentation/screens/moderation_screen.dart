import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/campus_scaffold.dart';

/// UC-065 scaffold. Review and resolution remain UC-077/UC-084.
class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key});
  @override
  Widget build(BuildContext context) => CampusScaffold(
    title: 'Moderation',
    section: CampusSection.moderation,
    role: 'admin',
    onBack: () => context.go(RouteNames.admin),
    body: CampusPage(
      maxWidth: 1000,
      children: [
        const Text(
          'COMMUNITY CARE',
          style: TextStyle(
            letterSpacing: 2,
            fontSize: 10,
            color: CampusColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'A welcoming campus, together.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'The workspace for thoughtful community review.',
          style: TextStyle(color: CampusColors.muted),
        ),
        const SizedBox(height: 28),
        CampusEmptyState(
          icon: Icons.verified_user_outlined,
          title: 'This workspace is taking shape',
          message:
              'The moderation queue and case resolution are planned for the next iteration. Review actions are not available yet.',
          action: FilledButton.icon(
            onPressed: () => context.go(RouteNames.admin),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back to dashboard'),
          ),
        ),
        const SizedBox(height: 24),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What this workspace will support',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.manage_search_rounded,
                    color: CampusColors.teal,
                  ),
                  title: Text('Review the context'),
                  subtitle: Text(
                    'See items awaiting moderation and their current status.',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.fact_check_outlined,
                    color: CampusColors.teal,
                  ),
                  title: Text('Make a clear decision'),
                  subtitle: Text('Resolve a case with the appropriate action.'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.history_rounded,
                    color: CampusColors.teal,
                  ),
                  title: Text('Keep a reliable record'),
                  subtitle: Text('Track the outcome of each reviewed case.'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
