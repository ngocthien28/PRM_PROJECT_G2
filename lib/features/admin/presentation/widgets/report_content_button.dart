import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/models/app_user.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../viewmodels/moderation_view_model.dart';

enum ReportReason {
  inaccurate('Inaccurate information'),
  inappropriate('Inappropriate content'),
  safety('Safety concern'),
  other('Other concern');

  const ReportReason(this.label);
  final String label;
}

class ReportContentButton extends ConsumerStatefulWidget {
  const ReportContentButton({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    this.expand = false,
  });

  final String targetType;
  final String targetId;
  final String targetLabel;
  final bool expand;

  @override
  ConsumerState<ReportContentButton> createState() =>
      _ReportContentButtonState();
}

class _ReportContentButtonState extends ConsumerState<ReportContentButton> {
  bool _submitting = false;

  Future<void> _report(AppUser? user) async {
    if (_submitting) return;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to report this content.')),
      );
      return;
    }
    final draft = await showDialog<_ReportDraft>(
      context: context,
      builder: (_) => _ReportContentDialog(targetLabel: widget.targetLabel),
    );
    if (draft == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      final title = '${draft.reason.label}: ${widget.targetLabel}';
      await ref
          .read(moderationRepositoryProvider)
          .submitReport(
            targetType: widget.targetType,
            targetId: widget.targetId,
            title: title.length <= 120
                ? title
                : '${title.substring(0, 117)}...',
            description: draft.description,
            reporterId: user.uid,
            reporterName: user.displayName,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report sent. An administrator will review it.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send the report. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final button = OutlinedButton.icon(
      key: ValueKey('report-${widget.targetType}-${widget.targetId}'),
      onPressed: _submitting || currentUser.isLoading
          ? null
          : () => _report(currentUser.asData?.value),
      icon: _submitting
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.flag_outlined, size: 18),
      label: const Text('Report content'),
      style: OutlinedButton.styleFrom(foregroundColor: CampusColors.muted),
    );
    return widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

class _ReportDraft {
  const _ReportDraft(this.reason, this.description);
  final ReportReason reason;
  final String description;
}

class _ReportContentDialog extends StatefulWidget {
  const _ReportContentDialog({required this.targetLabel});
  final String targetLabel;

  @override
  State<_ReportContentDialog> createState() => _ReportContentDialogState();
}

class _ReportContentDialogState extends State<_ReportContentDialog> {
  final _description = TextEditingController();
  ReportReason _reason = ReportReason.inaccurate;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Report content'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.targetLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CampusColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<ReportReason>(
              key: const ValueKey('report-reason'),
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: [
                for (final reason in ReportReason.values)
                  DropdownMenuItem(value: reason, child: Text(reason.label)),
              ],
              onChanged: (value) => setState(() => _reason = value ?? _reason),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('report-description'),
              controller: _description,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'What should we review?',
                hintText: 'Describe the issue and where it appears.',
                helperText: 'Enter at least 10 characters.',
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
        key: const ValueKey('submit-content-report'),
        onPressed: _description.text.trim().length < 10
            ? null
            : () => Navigator.pop(
                context,
                _ReportDraft(_reason, _description.text.trim()),
              ),
        icon: const Icon(Icons.send_outlined, size: 18),
        label: const Text('Send report'),
      ),
    ],
  );
}
