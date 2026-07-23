import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';

class DarditoAssistantReply {
  const DarditoAssistantReply({
    required this.answer,
    required this.conversationId,
    required this.sourceIds,
  });

  final String answer;
  final String conversationId;
  final List<String> sourceIds;
}

abstract interface class DarditoAssistantService {
  Future<DarditoAssistantReply> send({
    required String message,
    required String conversationId,
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
  }) async {
    final response = await _client
        .post(
          BackendConfig.chatEndpoint,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': message,
            'conversationId': conversationId,
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
    return DarditoAssistantReply(
      answer: answer,
      conversationId: returnedConversationId,
      sourceIds: sourceIds,
    );
  }
}
