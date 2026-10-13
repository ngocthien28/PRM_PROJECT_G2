import '../../features/clubs/data/club_repository.dart';

class ClubLogoUpload {
  const ClubLogoUpload(this.secureUrl, this.publicId);
  final String secureUrl, publicId;
}

abstract interface class ClubLogoService {
  Future<ClubLogoUpload> uploadLogo(ClubLogoSource source);
}
