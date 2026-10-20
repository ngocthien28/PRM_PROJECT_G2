import 'dart:typed_data';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campushub/core/services/club_logo_service.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/clubs/data/club_repository.dart';
import 'package:campushub/features/clubs/data/club_repository_impl.dart';
import 'package:campushub/shared/enums/user_role.dart';

class FakeLogos implements ClubLogoService {
  @override
  Future<ClubLogoUpload> uploadLogo(ClubLogoSource source) async =>
      const ClubLogoUpload('https://cloudinary/logo.png', 'club/logo');
}

AppUser actor(String id, UserRole role) => AppUser(
  uid: id,
  email: '$id@test.com',
  displayName: id,
  role: role,
  status: 'active',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late FakeFirebaseFirestore db;
  late ClubRepositoryImpl repository;
  setUp(() {
    db = FakeFirebaseFirestore();
    repository = ClubRepositoryImpl(db, FakeLogos());
  });

  test('organizer creates and edits owned Club with Cloudinary logo', () async {
    final owner = actor('owner', UserRole.organizer);
    final club = await repository.createClub(
      name: 'F-Code',
      description: 'A sufficiently long Club description.',
      actor: owner,
      logo: ClubLogoSource(bytes: Uint8List(1), fileName: 'logo.png'),
    );
    expect(club.logoUrl, 'https://cloudinary/logo.png');
    expect(
      (await db.collection('club_memberships').doc('${club.id}_owner').get())
          .data()?['role'],
      'manager',
    );
    final edited = await repository.updateClub(
      clubId: club.id,
      name: 'F-Code Club',
      description: club.description,
      actor: owner,
    );
    expect(edited.name, 'F-Code Club');
  });

  test('organizer cannot edit another owner while admin can cancel', () async {
    final club = await repository.createClub(
      name: 'Photo',
      description: 'A sufficiently long Club description.',
      actor: actor('owner', UserRole.organizer),
    );
    await expectLater(
      repository.updateClub(
        clubId: club.id,
        name: 'X',
        description: club.description,
        actor: actor('other', UserRole.organizer),
      ),
      throwsA(isA<Exception>()),
    );
    final cancelled = await repository.cancelClub(
      clubId: club.id,
      actor: actor('admin', UserRole.admin),
    );
    expect(cancelled.status.name, 'cancelled');
  });

  test(
    'join and leave update deterministic membership and count once',
    () async {
      final club = await repository.createClub(
        name: 'Sport',
        description: 'A sufficiently long Club description.',
        actor: actor('owner', UserRole.organizer),
      );
      final student = actor('student', UserRole.student);
      await repository.joinClub(clubId: club.id, actor: student);
      var notices = await db.collection('notifications').get();
      expect(notices.size, 1);
      expect(notices.docs.single.data()['membershipStatus'], 'active');
      expect(notices.docs.single.data()['pushStatus'], 'pending');
      final repositoryAfterSignIn = ClubRepositoryImpl(db, FakeLogos());
      final restoredMembership = await repositoryAfterSignIn
          .watchMembership(club.id, student.uid)
          .first;
      expect(restoredMembership?.isActive, isTrue);
      await expectLater(
        repository.joinClub(clubId: club.id, actor: student),
        throwsA(isA<Exception>()),
      );
      expect(
        (await db.collection('clubs').doc(club.id).get())
            .data()?['memberCount'],
        1,
      );
      await repository.leaveClub(clubId: club.id, actor: student);
      notices = await db.collection('notifications').get();
      expect(notices.size, 2);
      expect(
        notices.docs.map((d) => d.data()['membershipStatus']),
        containsAll(['active', 'left']),
      );
      expect(
        (await db.collection('clubs').doc(club.id).get())
            .data()?['memberCount'],
        0,
      );
    },
  );
}
