import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';

class DarditoAssistantReply {
  const DarditoAssistantReply({
    required this.answer,
    required this.conversationId,
    required this.sourceIds,
    required this.moderationAction,
    required this.yellowCount,
  });

  final String answer;
  final String conversationId;
  final List<String> sourceIds;
  final String moderationAction;
  final int yellowCount;
}

abstract interface class DarditoAssistantService {
  Future<DarditoAssistantReply> send({
    required String message,
    required String conversationId,
    required String sessionId,
  });
}

class FirebaseDarditoAssistantService implements DarditoAssistantService {
  FirebaseDarditoAssistantService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<DarditoAssistantReply> send({
    required String message,
    required String conversationId,
    required String sessionId,
  }) async {
    if (message.characters.length > 350 || message.trim().isEmpty) {
      throw const FormatException(
        'La pregunta debe tener entre 1 y 350 caracteres.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (user == null || token == null || token.isEmpty) {
      throw const FormatException('Se requiere una sesión autenticada.');
    }
    final response = await _client
        .post(
          BackendConfig.chatEndpoint,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'message': message,
            'conversationId': conversationId,
            'sessionId': sessionId,
          }),
        )
        .timeout(const Duration(seconds: 45));

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200 || decoded is! Map<String, dynamic>) {
      throw const FormatException('Respuesta inválida del backend de Dardito.');
    }
    final answer = decoded['answer'];
    final returnedConversationId = decoded['conversationId'];
    if (answer is! String || returnedConversationId is! String) {
      throw const FormatException(
        'Respuesta incompleta del backend de Dardito.',
      );
    }
    final sources = decoded['sources'];
    final sourceIds = sources is List
        ? sources
              .whereType<Map<String, dynamic>>()
              .map((source) => source['id'])
              .whereType<String>()
              .toList(growable: false)
        : const <String>[];
    final moderation = decoded['moderation'];
    final moderationAction = moderation is Map<String, dynamic>
        ? moderation['action']
        : null;
    final yellowCount = moderation is Map<String, dynamic>
        ? moderation['yellowCount']
        : null;
    return DarditoAssistantReply(
      answer: answer,
      conversationId: returnedConversationId,
      sourceIds: sourceIds,
      moderationAction: moderationAction is String ? moderationAction : 'none',
      yellowCount: yellowCount is int ? yellowCount : 0,
    );
  }
}
