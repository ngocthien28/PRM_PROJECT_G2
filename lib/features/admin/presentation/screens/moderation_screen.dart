import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/campus_scaffold.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../notifications/presentation/viewmodels/notification_view_model.dart';
import '../../data/models/moderation_case.dart';
import '../viewmodels/moderation_view_model.dart';

class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  ModerationStatus? _filter = ModerationStatus.pending;

  Future<void> _review(ModerationCase moderationCase) async {
    final decision = await showDialog<_ReviewDecision>(
      context: context,
      builder: (_) => _ReviewDialog(moderationCase: moderationCase),
    );
    if (decision == null || !mounted) return;

    final actor = ref.read(currentUserProvider).asData?.value;
    if (actor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your admin session is unavailable.')),
      );
      return;
    }
    try {
      await ref.read(resolveModerationCaseActionProvider)(
        caseId: moderationCase.id,
        action: decision.action,
        note: decision.note,
        actorId: actor.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${decision.action.label} saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save this decision: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cases = ref.watch(moderationCasesProvider);
    final user = ref.watch(currentUserProvider).asData?.value;
    final unread = ref.watch(unreadNotificationCountProvider);
    return CampusScaffold(
      title: 'Moderation',
      section: CampusSection.moderation,
      userName: user?.displayName ?? 'Administrator',
      role: 'admin',
      unreadCount: unread,
      onBack: () => context.go(RouteNames.admin),
      actions: [
        IconButton(
          tooltip: 'Refresh moderation queue',
          onPressed: () => ref.invalidate(moderationCasesProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: CampusPage(
        maxWidth: 1240,
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
            'Review with context and confidence.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          const Text(
            'Prioritize pending reports, inspect their details, and keep a clear decision record.',
            style: TextStyle(color: CampusColors.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          cases.when(
            skipLoadingOnRefresh: false,
            loading: () => const _ModerationLoading(),
            error: (_, _) => CampusEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load the moderation queue',
              message:
                  'Check the connection and your administrator permissions, then retry.',
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(moderationCasesProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
            data: (items) => _ModerationContent(
              items: items,
              filter: _filter,
              onFilterChanged: (value) => setState(() => _filter = value),
              onReview: _review,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModerationContent extends StatelessWidget {
  const _ModerationContent({
    required this.items,
    required this.filter,
    required this.onFilterChanged,
    required this.onReview,
  });

  final List<ModerationCase> items;
  final ModerationStatus? filter;
  final ValueChanged<ModerationStatus?> onFilterChanged;
  final ValueChanged<ModerationCase> onReview;

  @override
  Widget build(BuildContext context) {
    final visible = items
        .where((item) => filter == null || item.status == filter)
        .toList(growable: false);
    int count(ModerationStatus status) =>
        items.where((item) => item.status == status).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              label: 'Pending',
              value: count(ModerationStatus.pending),
              icon: Icons.pending_actions_outlined,
              color: const Color(0xFFB07918),
            ),
            _MetricCard(
              label: 'Resolved',
              value: count(ModerationStatus.resolved),
              icon: Icons.task_alt_rounded,
              color: CampusColors.teal,
            ),
            _MetricCard(
              label: 'Dismissed',
              value: count(ModerationStatus.dismissed),
              icon: Icons.remove_circle_outline_rounded,
              color: CampusColors.muted,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(
                    'Show',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ChoiceChip(
                  label: Text('Pending (${count(ModerationStatus.pending)})'),
                  selected: filter == ModerationStatus.pending,
                  onSelected: (_) => onFilterChanged(ModerationStatus.pending),
                ),
                ChoiceChip(
                  label: Text('Resolved (${count(ModerationStatus.resolved)})'),
                  selected: filter == ModerationStatus.resolved,
                  onSelected: (_) => onFilterChanged(ModerationStatus.resolved),
                ),
                ChoiceChip(
                  label: Text(
                    'Dismissed (${count(ModerationStatus.dismissed)})',
                  ),
                  selected: filter == ModerationStatus.dismissed,
                  onSelected: (_) =>
                      onFilterChanged(ModerationStatus.dismissed),
                ),
                ChoiceChip(
                  label: Text('All (${items.length})'),
                  selected: filter == null,
                  onSelected: (_) => onFilterChanged(null),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (visible.isEmpty)
          CampusEmptyState(
            icon: filter == ModerationStatus.pending
                ? Icons.verified_outlined
                : Icons.inbox_outlined,
            title: filter == ModerationStatus.pending
                ? 'The pending queue is clear'
                : 'No cases in this view',
            message: filter == ModerationStatus.pending
                ? 'There are no reports waiting for a decision.'
                : 'Choose another filter to review the case history.',
          )
        else
          ...visible.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModerationCaseCard(
                moderationCase: item,
                onReview: () => onReview(item),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              foregroundColor: color,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CampusColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModerationCaseCard extends StatelessWidget {
  const _ModerationCaseCard({
    required this.moderationCase,
    required this.onReview,
  });
  final ModerationCase moderationCase;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          final information = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusChip(status: moderationCase.status),
                  Text(
                    '${moderationCase.targetType.toUpperCase()} • ${moderationCase.targetId}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: CampusColors.muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                moderationCase.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                moderationCase.description,
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: CampusColors.muted, height: 1.5),
              ),
              const SizedBox(height: 13),
              Text(
                'Reported by ${moderationCase.reporterName} • ${DateFormat('dd MMM yyyy, HH:mm').format(moderationCase.createdAt.toLocal())}',
                style: const TextStyle(fontSize: 11, color: CampusColors.muted),
              ),
              if (moderationCase.resolution case final resolution?) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CampusColors.canvas,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Decision note: $resolution',
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ],
          );
          final button = moderationCase.status == ModerationStatus.pending
              ? FilledButton.icon(
                  key: ValueKey('review-case-${moderationCase.id}'),
                  onPressed: onReview,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Review case'),
                )
              : null;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                information,
                if (button != null) ...[const SizedBox(height: 18), button],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: information),
              if (button != null) ...[const SizedBox(width: 20), button],
            ],
          );
        },
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ModerationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ModerationStatus.pending => ('Pending review', const Color(0xFF9B6C17)),
      ModerationStatus.resolved => ('Resolved', CampusColors.teal),
      ModerationStatus.dismissed => ('Dismissed', CampusColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReviewDecision {
  const _ReviewDecision(this.action, this.note);
  final ModerationAction action;
  final String note;
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.moderationCase});
  final ModerationCase moderationCase;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _note = TextEditingController();
  ModerationAction _action = ModerationAction.resolve;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Review moderation case'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.moderationCase.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.moderationCase.description,
              style: const TextStyle(color: CampusColors.muted, height: 1.5),
            ),
            const SizedBox(height: 22),
            const Text(
              'Decision',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            RadioGroup<ModerationAction>(
              groupValue: _action,
              onChanged: (value) => setState(() => _action = value!),
              child: Column(
                children: [
                  for (final action in ModerationAction.values)
                    RadioListTile<ModerationAction>(
                      contentPadding: EdgeInsets.zero,
                      value: action,
                      title: Text(action.label),
                      subtitle: Text(action.description),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('moderation-note'),
              controller: _note,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Decision note',
                hintText: 'Explain what was reviewed and why.',
                helperText: 'Enter at least 5 characters before saving.',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        key: const ValueKey('save-moderation-decision'),
        onPressed: _note.text.trim().length < 5
            ? null
            : () => Navigator.pop(
                context,
                _ReviewDecision(_action, _note.text.trim()),
              ),
        icon: const Icon(Icons.save_outlined, size: 18),
        label: const Text('Save decision'),
      ),
    ],
  );
}

class _ModerationLoading extends StatelessWidget {
  const _ModerationLoading();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 72),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}
