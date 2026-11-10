import '../../../../core/routing/route_names.dart';
import '../../data/models/app_notification.dart';

/// UC-091: Open Related Content from Notification.
/// Resolves deep links and action labels for notifications targeting events,
/// clubs, tickets, and moderation screens.
class OpenRelatedContent {
  const OpenRelatedContent();

  String? deepLink(AppNotification item) {
    final referenceId = item.referenceId?.trim();
    if (referenceId == null || referenceId.isEmpty) return null;
    return switch (item.type) {
      'club' || 'club_membership' => RouteNames.clubDetail(referenceId),
      'event' ||
      'event_update' ||
      'event_cancelled' ||
      'event_reminder' => RouteNames.eventDetail(referenceId),
      'ticket' || 'registration' => RouteNames.ticketDetail(referenceId),
      'moderation' => RouteNames.moderation,
      _ => null,
    };
  }

  String actionLabel(AppNotification item) => switch (item.type) {
    'club' || 'club_membership' => 'View club',
    'event' ||
    'event_update' ||
    'event_cancelled' ||
    'event_reminder' => 'View event',
    'ticket' || 'registration' => 'View ticket',
    'moderation' => 'Open moderation',
    _ => 'Open',
  };
}
