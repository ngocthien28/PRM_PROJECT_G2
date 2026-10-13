import 'dart:convert';
import 'package:http/http.dart' as http;
import '../errors/app_exception.dart';
import '../../features/clubs/data/club_repository.dart';
import 'club_logo_service.dart';

class CloudinaryClubLogoService implements ClubLogoService {
  CloudinaryClubLogoService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  static const cloud = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'djznx3z7o',
  );
  static const preset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'campushub_club_logos_unsigned',
  );
  @override
  Future<ClubLogoUpload> uploadLogo(ClubLogoSource source) async {
    final ext = source.fileName.split('.').last.toLowerCase();
    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) {
      throw const AppException('Logo must be JPG, PNG, or WebP.');
    }
    if (source.bytes.length > 5 * 1024 * 1024) {
      throw const AppException('Logo must be 5 MB or smaller.');
    }
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('https://api.cloudinary.com/v1_1/$cloud/image/upload'),
          )
          ..fields['upload_preset'] = preset
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              source.bytes,
              filename: source.fileName,
            ),
          );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode ~/ 100 != 2) {
      throw const AppException('Could not upload Club logo.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final url = body['secure_url'], id = body['public_id'];
    if (url is! String || id is! String) {
      throw const AppException('Cloudinary returned an invalid response.');
    }
    return ClubLogoUpload(url, id);
  }
}
