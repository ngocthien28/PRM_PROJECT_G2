import 'dart:typed_data';
import '../../auth/data/models/app_user.dart';
import 'models/club_membership.dart';
import 'models/club_model.dart';

class ClubLogoSource {
  const ClubLogoSource({required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;
}

abstract interface class ClubRepository {
  Stream<List<ClubModel>> watchClubs();
  Stream<ClubModel?> watchClub(String clubId);
  Stream<ClubMembership?> watchMembership(String clubId, String userId);
  Future<void> joinClub({required String clubId, required AppUser actor});
  Future<void> leaveClub({required String clubId, required AppUser actor});
  Future<ClubModel> createClub({
    required String name,
    required String description,
    required AppUser actor,
    ClubLogoSource? logo,
  });
  Future<ClubModel> updateClub({
    required String clubId,
    required String name,
    required String description,
    required AppUser actor,
    ClubLogoSource? newLogo,
  });
  Future<ClubModel> cancelClub({
    required String clubId,
    required AppUser actor,
  });
}
