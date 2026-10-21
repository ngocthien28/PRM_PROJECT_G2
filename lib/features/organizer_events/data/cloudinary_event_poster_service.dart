import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/cloudinary_club_logo_service.dart';
import 'event_poster_service.dart';
import 'models/event_form_input.dart';

/// Reuses the project's Cloudinary account/preset without an API secret.
class CloudinaryEventPosterService implements EventPosterService {
  CloudinaryEventPosterService({
    http.Client? client,
    this.cloudName = CloudinaryClubLogoService.cloud,
    this.uploadPreset = defaultPreset,
    this.requestTimeout = const Duration(seconds: 60),
    this.onProgress,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  static const defaultPreset = String.fromEnvironment(
    'CLOUDINARY_EVENT_POSTER_UPLOAD_PRESET',
    defaultValue: CloudinaryClubLogoService.preset,
  );
  final http.Client _client;
  final bool _ownsClient;
  final String cloudName;
  final String uploadPreset;
  final Duration requestTimeout;
  final void Function(double? progress)? onProgress;

  void close() {
    if (_ownsClient) _client.close();
  }

  @override
  Future<UploadedEventPoster> upload(
    String eventId,
    EventPosterSelection image,
  ) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(eventId)) {
      throw const AppException('Invalid event.', code: 'invalid-event');
    }
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(cloudName) ||
        uploadPreset.isEmpty) {
      throw const AppException(
        'Poster upload is not configured. Contact the administrator.',
        code: 'poster-upload-failed',
      );
    }
    final mime = await EventPosterValidator.validate(image);
    final extension = mime == 'image/jpeg' ? 'jpg' : mime.split('/').last;
    final publicId = 'campushub/event_posters/$eventId/${const Uuid().v4()}';
    final abort = Completer<void>();
    final request =
        _PosterUploadRequest(
            Uri.https('api.cloudinary.com', '/v1_1/$cloudName/image/upload'),
            abort.future,
            onProgress,
          )
          ..followRedirects = false
          ..fields['upload_preset'] = uploadPreset
          ..fields['public_id'] = publicId
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              image.bytes!,
              filename: 'poster.$extension',
              contentType: http.MediaType.parse(mime),
            ),
          );
    onProgress?.call(0);
    try {
      final response =
          await (() async => http.Response.fromStream(
            await _client.send(request),
          ))().timeout(
            requestTimeout,
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw TimeoutException('Poster upload timed out.');
            },
          );
      if (response.statusCode ~/ 100 != 2) {
        _rejectResponse(response);
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) _invalidResponse();
      final returnedId = body['public_id'];
      final url = body['secure_url'];
      final format = body['format'];
      // The existing logo preset may supply a folder prefix in fixed-folder
      // mode. Accept only that known prefix and the ID of this exact request.
      if (returnedId is! String ||
          (returnedId != publicId &&
              returnedId != 'campushub/club_logos/$publicId') ||
          body['resource_type'] != 'image' ||
          !{'jpg', 'jpeg', 'png', 'webp'}.contains(format) ||
          url is! String ||
          !RegExp(
            '^https://res[.]cloudinary[.]com/${RegExp.escape(cloudName)}/image/upload/v[0-9]+/${RegExp.escape(returnedId)}[.]$format\$',
          ).hasMatch(url)) {
        _invalidResponse();
      }
      final token = body['delete_token'];
      onProgress?.call(1);
      return UploadedEventPoster(
        path: returnedId,
        url: url,
        deleteToken: token is String && token.isNotEmpty ? token : null,
      );
    } on AppException {
      rethrow;
    } on TimeoutException catch (error) {
      throw AppException(
        'Poster upload timed out. Check your connection and select Save to retry.',
        code: 'poster-upload-failed',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw AppException(
        'Could not connect to the image service. Check your connection and select Save to retry.',
        code: 'poster-upload-failed',
        cause: error,
      );
    } on FormatException catch (error) {
      throw AppException(
        'The image service returned an invalid response. Please try again.',
        code: 'poster-upload-failed',
        cause: error,
      );
    } finally {
      onProgress?.call(null);
    }
  }

  Never _invalidResponse() => throw const AppException(
    'The image service returned an unexpected poster. Please contact the administrator.',
    code: 'poster-upload-failed',
  );

  Never _rejectResponse(http.Response response) {
    var detail = '';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is Map) {
        detail = (body['error'] as Map)['message']?.toString() ?? '';
      }
    } on FormatException {
      /* A non-JSON failure is still a failed upload. */
    }
    if (kDebugMode) {
      debugPrint(
        'Cloudinary poster upload failed [HTTP ${response.statusCode}]: $detail',
      );
    }
    final message = response.statusCode == 420 || response.statusCode == 429
        ? 'The image service usage limit has been reached. Please try again later.'
        : response.statusCode == 401 ||
              response.statusCode == 403 ||
              detail.toLowerCase().contains('preset')
        ? 'Poster upload is not configured. Contact the administrator.'
        : 'Poster upload failed. Please select Save to retry.';
    throw AppException(message, code: 'poster-upload-failed');
  }

  @override
  Future<void> delete(UploadedEventPoster poster) async {
    final token = poster.deleteToken;
    if (token == null) {
      throw const AppException(
        'Poster cleanup needs a deletion token.',
        code: 'poster-cleanup-unavailable',
      );
    }
    final response = await _client
        .post(
          Uri.https('api.cloudinary.com', '/v1_1/$cloudName/delete_by_token'),
          body: {'token': token},
        )
        .timeout(const Duration(seconds: 3));
    if (response.statusCode ~/ 100 != 2 ||
        (jsonDecode(response.body) as Map)['result'] != 'ok') {
      throw const AppException(
        'Poster cleanup could not be confirmed.',
        code: 'poster-cleanup-failed',
      );
    }
  }
}

/// Counts bytes consumed by the HTTP client, not server acknowledgement. Keep
/// progress below 100% until Cloudinary returns a validated delivery URL.
class _PosterUploadRequest extends http.MultipartRequest with http.Abortable {
  _PosterUploadRequest(Uri url, this.abortTrigger, this.onProgress)
    : super('POST', url);
  @override
  final Future<void> abortTrigger;
  final void Function(double?)? onProgress;

  @override
  http.ByteStream finalize() {
    final total = contentLength;
    var sent = 0;
    return http.ByteStream(
      super.finalize().map((chunk) {
        sent += chunk.length;
        onProgress?.call((sent / total).clamp(0, 0.99));
        return chunk;
      }),
    );
  }
}
