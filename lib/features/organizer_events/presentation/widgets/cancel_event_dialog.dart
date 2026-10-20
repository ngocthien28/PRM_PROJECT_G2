import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../events/data/models/event_model.dart';
import '../viewmodels/organizer_events_view_model.dart';

/// Returns true only after the server-backed action confirms cancellation.
Future<bool> showCancelEventDialog(
  BuildContext context,
  EventModel event,
) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _CancelEventDialog(event: event),
    ) ==
    true;

class _CancelEventDialog extends ConsumerStatefulWidget {
  const _CancelEventDialog({required this.event});
  final EventModel event;

  @override
  ConsumerState<_CancelEventDialog> createState() => _CancelEventDialogState();
}

class _CancelEventDialogState extends ConsumerState<_CancelEventDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(organizerEventActionsProvider)
          .cancelEvent(widget.event.id);
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(error);
      });
    }
  }

  String _message(Object error) {
    final code = error is AppException
        ? error.code
        : error is FirebaseException
        ? error.code
        : null;
    return switch (code) {
      'permission-denied' ||
      'event-forbidden' => 'You do not have permission to cancel this event.',
      'unauthenticated' ||
      'session-timeout' => 'Your session is unavailable. Please sign in again.',
      'event-not-found' || 'not-found' =>
        'This event no longer exists. Return to your managed events and refresh.',
      'unavailable' ||
      'deadline-exceeded' ||
      'network-request-failed' ||
      'event-timeout' ||
      'event-cancel-timeout' =>
        'Cancellation could not be confirmed yet. Check your connection and retry.',
      _ =>
        error is AppException
            ? error.message
            : 'Unable to cancel this event. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      key: const Key('cancelEventDialog'),
      title: const Text('Cancel Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cancel “${widget.event.title}”? Students will no longer be able to register. '
              'The event and existing registrations will be kept in your management history.',
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        key: Key('cancelEventLoading'),
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Text('Cancelling…')),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    key: const Key('cancelEventError'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('keepEventButton'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(_error == null ? 'Keep Event' : 'Back'),
        ),
        FilledButton(
          key: const Key('confirmCancelEventButton'),
          onPressed: _busy ? null : _submit,
          child: Text(_error == null ? 'Cancel Event' : 'Retry'),
        ),
      ],
    ),
  );
}
