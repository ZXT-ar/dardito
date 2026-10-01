import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';

class StoryLikeState {
  const StoryLikeState({
    required this.storyId,
    required this.liked,
    required this.likeCount,
  });

  final String storyId;
  final bool liked;
  final int likeCount;
}

typedef StoryLikeCallback = Future<StoryLikeState> Function(String storyId);

class StoryLikesScope extends InheritedWidget {
  const StoryLikesScope({
    super.key,
    required this.status,
    required this.toggle,
    required super.child,
  });

  final StoryLikeCallback status;
  final StoryLikeCallback toggle;

  static StoryLikesScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoryLikesScope>();

  @override
  bool updateShouldNotify(StoryLikesScope oldWidget) =>
      status != oldWidget.status || toggle != oldWidget.toggle;
}

abstract interface class StoryLikeService {
  Future<StoryLikeState> status(String storyId);
  Future<StoryLikeState> toggle(String storyId);
}

class FirebaseStoryLikeService implements StoryLikeService {
  FirebaseStoryLikeService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<StoryLikeState> status(String storyId) =>
      _request(action: 'status', storyId: storyId);

  @override
  Future<StoryLikeState> toggle(String storyId) =>
      _request(action: 'toggle', storyId: storyId);

  Future<StoryLikeState> _request({
    required String action,
    required String storyId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (user == null || token == null || token.isEmpty) {
      throw const StoryLikeException('Se requiere una sesión autenticada.');
    }
    final response = await _client
        .post(
          BackendConfig.storyLikesEndpoint,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'action': action, 'storyId': storyId}),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200 || decoded is! Map<String, dynamic>) {
      final message =
          decoded is Map<String, dynamic> && decoded['error'] is String
          ? decoded['error'] as String
          : 'No fue posible actualizar Me gusta.';
      throw StoryLikeException(message);
    }
    final returnedId = decoded['storyId'];
    final liked = decoded['liked'];
    final likeCount = decoded['likeCount'];
    if (returnedId != storyId ||
        liked is! bool ||
        likeCount is! int ||
        likeCount < 0) {
      throw const StoryLikeException(
        'El servicio devolvió una respuesta inválida.',
      );
    }
    return StoryLikeState(storyId: storyId, liked: liked, likeCount: likeCount);
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

class StoryLikeException implements Exception {
  const StoryLikeException(this.message);
  final String message;

  @override
  String toString() => message;
}
