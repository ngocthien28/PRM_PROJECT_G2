import 'package:campushub/core/routing/route_names.dart';
import 'package:campushub/features/notifications/data/models/app_notification.dart';
import 'package:campushub/features/notifications/domain/usecases/open_related_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UC-091: OpenRelatedContent', () {
    const useCase = OpenRelatedContent();

    AppNotification notification({
      required String type,
      String? referenceId,
    }) {
      return AppNotification(
        id: 'n-1',
        userId: 'u-1',
        title: 'Notice',
        body: 'Details',
        type: type,
        referenceId: referenceId,
        isRead: false,
        createdAt: DateTime.utc(2026, 1, 1),
      );
    }

    test('resolves deep link and action label for club notifications', () {
      final clubNotice = notification(type: 'club', referenceId: 'c123');
      expect(useCase.deepLink(clubNotice), RouteNames.clubDetail('c123'));
      expect(useCase.actionLabel(clubNotice), 'View club');

      final memberNotice = notification(type: 'club_membership', referenceId: 'c123');
      expect(useCase.deepLink(memberNotice), RouteNames.clubDetail('c123'));
      expect(useCase.actionLabel(memberNotice), 'View club');
    });

    test('resolves deep link and action label for event notifications', () {
      for (final type in ['event', 'event_update', 'event_cancelled', 'event_reminder']) {
        final notice = notification(type: type, referenceId: 'e456');
        expect(useCase.deepLink(notice), RouteNames.eventDetail('e456'));
        expect(useCase.actionLabel(notice), 'View event');
      }
    });

    test('resolves deep link and action label for ticket/registration notifications', () {
      final ticketNotice = notification(type: 'ticket', referenceId: 't789');
      expect(useCase.deepLink(ticketNotice), RouteNames.ticketDetail('t789'));
      expect(useCase.actionLabel(ticketNotice), 'View ticket');

      final regNotice = notification(type: 'registration', referenceId: 't789');
      expect(useCase.deepLink(regNotice), RouteNames.ticketDetail('t789'));
      expect(useCase.actionLabel(regNotice), 'View ticket');
    });

    test('resolves deep link and action label for moderation notifications', () {
      final modNotice = notification(type: 'moderation', referenceId: 'case-1');
      expect(useCase.deepLink(modNotice), RouteNames.moderation);
      expect(useCase.actionLabel(modNotice), 'Open moderation');
    });

    test('returns null for empty, whitespace, or null referenceId', () {
      expect(useCase.deepLink(notification(type: 'event', referenceId: null)), isNull);
      expect(useCase.deepLink(notification(type: 'event', referenceId: '')), isNull);
      expect(useCase.deepLink(notification(type: 'event', referenceId: '   ')), isNull);
    });

    test('returns null for unknown notification types', () {
      final unknown = notification(type: 'unknown_type', referenceId: 'xyz');
      expect(useCase.deepLink(unknown), isNull);
      expect(useCase.actionLabel(unknown), 'Open');
    });
  });
}
