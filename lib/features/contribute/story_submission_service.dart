import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';

const storyTitleLimit = 25;
const storyBodyLimit = 2500;
const storyPeriodLimit = 100;
const storyPhotoLimit = 3;
const storyPhotoBytesLimit = 8 * 1024 * 1024;
const storyPhotosTotalBytesLimit = 20 * 1024 * 1024;

class SelectedStoryPhoto {
  const SelectedStoryPhoto({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
}

class StorySubmissionException implements Exception {
  const StorySubmissionException(
    this.message, {
    this.code,
    this.details = const [],
  });
  final String message;
  final String? code;
  final List<String> details;
  @override
  String toString() => message;
}

class StorySubmissionService {
  StorySubmissionService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    http.Client? client,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final http.Client _client;

  Future<String> submit({
    required String title,
    required String story,
    required String category,
    required String neighborhood,
    required String period,
    required String evidence,
    required bool materialConsent,
    required bool legalConsent,
    required List<SelectedStoryPhoto> photos,
    required Map<String, Object> clientMetadata,
    required ValueChanged<double> onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified != true) {
      throw const StorySubmissionException(
        'Volvé a conectarte con Google para enviar tu historia.',
        code: 'UNAUTHENTICATED',
      );
    }
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const StorySubmissionException('No pudimos validar tu sesión.');
    }
    final safeTitle = _sanitizePlainText(title, storyTitleLimit);
    final safeStory = _sanitizePlainText(story, storyBodyLimit);
    final safePeriod = _sanitizePlainText(period, storyPeriodLimit);
    if (safeTitle.length < 3 ||
        safeStory.length < 30 ||
        safePeriod.length < 2 ||
        !RegExp(r'^[a-z0-9_-]{1,80}$').hasMatch(evidence) ||
        !RegExp(r'^[a-z0-9_-]{1,80}$').hasMatch(category) ||
        neighborhood.trim().isEmpty ||
        !materialConsent ||
        !legalConsent ||
        photos.length > storyPhotoLimit) {
      throw const StorySubmissionException(
        'Revisá los campos obligatorios antes de enviar.',
        code: 'INVALID_SUBMISSION',
      );
    }
    final submissionId = _newSubmissionId();
    final paths = <String>[];
    var prepared = false;
    try {
      if (photos.isNotEmpty) {
        final manifest = [
          for (var index = 0; index < photos.length; index++)
            {
              'name':
                  'photo_$index.${_photoExtension(photos[index].contentType)}',
              'size': photos[index].bytes.length,
              'contentType': photos[index].contentType,
            },
        ];
        prepared = true;
        final reservation = await _submissionRequest(token, {
          'action': 'prepare',
          'submissionId': submissionId,
          'photos': manifest,
        });
        final reservedPaths = reservation['photoPaths'];
        final expectedPaths = [
          for (final photo in manifest)
            'story_submissions/${user.uid}/$submissionId/${photo['name']}',
        ];
        if (reservation['submissionId'] != submissionId ||
            reservedPaths is! List ||
            !listEquals(reservedPaths, expectedPaths)) {
          throw const StorySubmissionException(
            'No pudimos autorizar las fotografías. Actualizá la página y volvé a intentar.',
            code: 'INVALID_UPLOAD_RESERVATION',
          );
        }
        paths.addAll(expectedPaths);
      }
      for (var index = 0; index < photos.length; index++) {
        final photo = photos[index];
        final reference = _storage.ref(paths[index]);
        final task = reference.putData(
          photo.bytes,
          SettableMetadata(
            contentType: photo.contentType,
            customMetadata: {'originalName': photo.name},
          ),
        );
        task.snapshotEvents.listen((snapshot) {
          if (snapshot.totalBytes <= 0) return;
          final photoProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(((index + photoProgress) / (photos.length + 1)) * .82);
        });
        await task;
      }
      onProgress(.86);
      final decoded = await _submissionRequest(token, {
        'submissionId': submissionId,
        'title': safeTitle,
        'story': safeStory,
        'category': category,
        'neighborhood': neighborhood,
        'period': safePeriod,
        'evidence': evidence,
        'materialConsent': materialConsent,
        'legalConsent': legalConsent,
        'contactConsent': legalConsent,
        'photoPaths': paths,
        'client': clientMetadata,
      });
      onProgress(1);
      return decoded['id'] as String? ?? submissionId;
    } catch (error) {
      if (prepared) {
        try {
          // The backend refuses to delete an already accepted contribution,
          // including when the original submit response timed out in transit.
          final cancellation = await _submissionRequest(token, {
            'action': 'cancel',
            'submissionId': submissionId,
          });
          if (cancellation['status'] == 'submitted') {
            onProgress(1);
            return submissionId;
          }
        } catch (_) {}
      }
      if (error is StorySubmissionException) rethrow;
      throw const StorySubmissionException(
        'No pudimos confirmar el envío. Revisá tu conexión y volvé a intentar.',
      );
    }
  }

  String _photoExtension(String contentType) => switch (contentType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };

  Future<Map<String, dynamic>> _submissionRequest(
    String token,
    Map<String, Object?> body,
  ) async {
    final response = await _client
        .post(
          BackendConfig.storySubmissionEndpoint,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StorySubmissionException(
        decoded['error'] as String? ?? 'No pudimos guardar tu historia.',
        code: decoded['code'] as String?,
        details: (decoded['details'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
      );
    }
    return decoded;
  }

  String _newSubmissionId() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(24, (_) => random.nextInt(256)),
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _sanitizePlainText(String value, int maxLength) {
    final sanitized = value
        .replaceAll(
          RegExp(r'[<>\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'),
          '',
        )
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
    return sanitized.length <= maxLength
        ? sanitized
        : sanitized.substring(0, maxLength);
  }
}
