import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import 'event_poster_service.dart';
import 'models/event_form_input.dart';

/// Windows Firebase Storage SDK cannot connect to Storage Emulator. This
/// emulator-only transport uses the same authenticated Firebase HTTP endpoint;
/// Storage Rules still authorize the signed-in user for every upload/delete.
class EmulatorEventPosterService implements EventPosterService {
  EmulatorEventPosterService({
    required this.bucket,
    required this.idToken,
    this.host = '127.0.0.1',
    this.onProgress,
    http.Client? client,
  }) : _client = client ?? http.Client() {
    if (!{'127.0.0.1', 'localhost'}.contains(host) ||
        !RegExp(r'^demo-[a-z0-9-]+\.appspot\.com$').hasMatch(bucket)) {
      throw ArgumentError(
        'Only loopback Storage Emulator demo buckets are supported.',
      );
    }
  }

  final String host;
  final String bucket;
  final Future<String?> Function() idToken;
  final void Function(double?)? onProgress;
  final http.Client _client;

  Uri _uri({String? path, Map<String, String>? query}) => Uri(
    scheme: 'http',
    host: host,
    port: 9199,
    pathSegments: ['v0', 'b', bucket, 'o', ?path],
    queryParameters: query,
  );

  Future<Map<String, String>> _headers() async {
    final token = await idToken();
    if (token == null || token.isEmpty) {
      throw const AppException(
        'Sign in again before uploading a poster.',
        code: 'unauthenticated',
      );
    }
    return {'Authorization': 'Bearer $token'};
  }

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AppException(
        'You do not have permission to upload this event poster.',
        code: 'permission-denied',
      );
    }
    throw const AppException(
      'Poster storage could not complete the request. Check Storage Emulator and retry.',
      code: 'poster-upload-failed',
    );
  }

  @override
  Future<UploadedEventPoster> upload(
    String eventId,
    EventPosterSelection image,
  ) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(eventId)) {
      throw const AppException('Invalid event.', code: 'invalid-event');
    }
    final mime = await EventPosterValidator.validate(image);
    final extension = mime == 'image/jpeg' ? 'jpg' : mime.split('/').last;
    final path = 'events/$eventId/${const Uuid().v4()}.$extension';
    onProgress?.call(0);
    try {
      final response = await _client
          .post(
            _uri(query: {'name': path}),
            headers: {...await _headers(), 'Content-Type': mime},
            body: image.bytes!,
          )
          .timeout(const Duration(seconds: 30));
      _check(response);
      final metadata = jsonDecode(response.body) as Map<String, dynamic>;
      final tokens = metadata['downloadTokens'];
      if (metadata['name'] != path ||
          metadata['bucket'] != bucket ||
          tokens is! String ||
          tokens.isEmpty) {
        throw const FormatException('Invalid uploaded poster metadata');
      }
      onProgress?.call(1);
      return UploadedEventPoster(
        path: path,
        url: _uri(
          path: path,
          query: {'alt': 'media', 'token': tokens.split(',').first},
        ).toString(),
      );
    } on TimeoutException {
      throw const AppException(
        'Poster upload timed out. Check Storage Emulator and retry.',
        code: 'poster-upload-failed',
      );
    } on http.ClientException {
      throw const AppException(
        'Cannot connect to Storage Emulator. Check port 9199 and retry.',
        code: 'poster-upload-failed',
      );
    } on FormatException {
      throw const AppException(
        'Storage Emulator returned an invalid upload response. Retry.',
        code: 'poster-upload-failed',
      );
    } finally {
      onProgress?.call(null);
    }
  }

  @override
  Future<void> delete(UploadedEventPoster poster) async {
    if (!RegExp(
      r'^events/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+\.(jpg|png|webp)$',
    ).hasMatch(poster.path)) {
      throw const AppException('Invalid poster path.', code: 'invalid-poster');
    }
    final response = await _client
        .delete(_uri(path: poster.path), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 404) _check(response);
  }

  void close() => _client.close();
}
