import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campushub/features/clubs/data/models/club_membership.dart';
import 'package:campushub/features/clubs/data/models/club_model.dart';
import 'package:campushub/features/notifications/data/models/app_notification.dart';
import 'package:campushub/shared/enums/club_status.dart';
import 'package:campushub/shared/enums/membership_status.dart';

void main() {
  final created = DateTime.utc(2026, 10, 1);
  final updated = DateTime.utc(2026, 10, 2);

  test('ClubModel round-trips Firestore fields', () {
    final club = ClubModel.fromMap('club-1', {
      'ownerId': 'organizer-1',
      'name': 'F-Code',
      'nameLower': 'f-code',
      'description': 'Flutter and software engineering community.',
      'logoUrl': 'https://res.cloudinary.com/demo/logo.png',
      'logoPublicId': 'campushub/club_logos/logo',
      'memberCount': 12,
      'status': 'active',
      'createdAt': Timestamp.fromDate(created),
      'updatedAt': Timestamp.fromDate(updated),
    });

    expect(club.status, ClubStatus.active);
    expect(club.nameLower, 'f-code');
    expect(club.toMap(), {
      'ownerId': 'organizer-1',
      'name': 'F-Code',
      'nameLower': 'f-code',
      'description': 'Flutter and software engineering community.',
      'logoUrl': 'https://res.cloudinary.com/demo/logo.png',
      'logoPublicId': 'campushub/club_logos/logo',
      'memberCount': 12,
      'status': 'active',
      'createdAt': Timestamp.fromDate(created),
      'updatedAt': Timestamp.fromDate(updated),
    });
  });

  test('ClubModel tolerates pending null timestamps', () {
    final club = ClubModel.fromMap('pending', {
      'ownerId': 'organizer-1',
      'name': 'Pending Club',
      'nameLower': 'pending club',
      'description': 'A valid pending club description.',
      'logoUrl': null,
      'logoPublicId': null,
      'memberCount': 0,
      'status': 'active',
      'createdAt': null,
      'updatedAt': null,
    });
    expect(club.createdAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    expect(club.updatedAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
  });

  test('ClubMembership uses deterministic id and round-trips', () {
    final membership = ClubMembership.fromMap('club-1_user-1', {
      'clubId': 'club-1',
      'userId': 'user-1',
      'role': 'member',
      'status': 'active',
      'joinedAt': Timestamp.fromDate(created),
      'updatedAt': Timestamp.fromDate(updated),
    });
    expect(ClubMembership.documentId('club-1', 'user-1'), 'club-1_user-1');
    expect(membership.role, MembershipRole.member);
    expect(membership.status, MembershipStatus.active);
    expect(membership.toMap()['status'], 'active');
  });

  test('AppNotification round-trips optional referenceId', () {
    final notification = AppNotification.fromMap('notification-1', {
      'userId': 'user-1',
      'title': 'Club updated',
      'body': 'F-Code has new information.',
      'type': 'club',
      'referenceId': null,
      'isRead': false,
      'createdAt': Timestamp.fromDate(created),
    });
    expect(notification.referenceId, isNull);
    expect(notification.toMap()['isRead'], isFalse);
  });

  test('persisted unknown enum values fail closed', () {
    expect(() => ClubStatus.parse('deleted'), throwsFormatException);
    expect(() => MembershipStatus.parse('banned'), throwsFormatException);
    expect(() => MembershipRole.parse('owner'), throwsFormatException);
  });
}
