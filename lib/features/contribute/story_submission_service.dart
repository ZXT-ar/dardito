import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';

const storyTitleLimit = 25;
const storyBodyLimit = 2500;
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
  const StorySubmissionException(this.message, {this.code, this.details = const []});
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
    required bool materialConsent,
    required bool legalConsent,
    required bool contactConsent,
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
    final submissionId = _newSubmissionId();
    final uploaded = <Reference>[];
    final paths = <String>[];
    try {
      for (var index = 0; index < photos.length; index++) {
        final photo = photos[index];
        final extension = switch (photo.contentType) {
          'image/png' => 'png',
          'image/webp' => 'webp',
          _ => 'jpg',
        };
        final path =
            'story_submissions/${user.uid}/$submissionId/photo_$index.$extension';
        final reference = _storage.ref(path);
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
        uploaded.add(reference);
        paths.add(path);
      }
      onProgress(.86);
      final response = await _client
          .post(
            BackendConfig.storySubmissionEndpoint,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'submissionId': submissionId,
              'title': title,
              'story': story,
              'category': category,
              'neighborhood': neighborhood,
              'materialConsent': materialConsent,
              'legalConsent': legalConsent,
              'contactConsent': contactConsent,
              'photoPaths': paths,
              'client': clientMetadata,
            }),
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
      onProgress(1);
      return decoded['id'] as String? ?? submissionId;
    } catch (error) {
      for (final reference in uploaded) {
        try {
          await reference.delete();
        } catch (_) {}
      }
      if (error is StorySubmissionException) rethrow;
      throw const StorySubmissionException(
        'La carga se interrumpió. Tus datos no fueron enviados.',
      );
    }
  }

  String _newSubmissionId() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(24, (_) => random.nextInt(256)),
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
