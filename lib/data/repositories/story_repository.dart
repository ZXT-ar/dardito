import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';
import '../catalogs/story_catalog.dart';
import '../models/story.dart';

abstract interface class StoryRepository {
  Future<List<CityStory>> fetchAll({bool forceRefresh = false});

  void dispose();
}

class StoryRepositoryException implements Exception {
  const StoryRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Loads the public, editorially published stories from the backend.
///
/// No story content is embedded in the Flutter bundle. The short in-memory
/// cache only prevents duplicate requests during the same app session.
class RemoteStoryRepository implements StoryRepository {
  RemoteStoryRepository({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _endpoint = endpoint ?? BackendConfig.publicStoriesEndpoint;

  static const _maximumResponseBytes = 2 * 1024 * 1024;
  static const _cacheDuration = Duration(minutes: 2);
  static const _timeout = Duration(seconds: 12);

  final http.Client _client;
  final bool _ownsClient;
  final Uri _endpoint;
  List<CityStory>? _cached;
  DateTime? _cachedAt;

  @override
  Future<List<CityStory>> fetchAll({bool forceRefresh = false}) async {
    final cached = _cached;
    final cachedAt = _cachedAt;
    if (!forceRefresh &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheDuration) {
      return List.unmodifiable(cached);
    }

    final http.Response response;
    try {
      response = await _client
          .get(_endpoint, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
    } on TimeoutException {
      throw const StoryRepositoryException(
        'El servicio de historias tardó demasiado en responder.',
      );
    } on http.ClientException {
      throw const StoryRepositoryException(
        'No fue posible conectar con el servicio de historias.',
      );
    }

    if (response.statusCode != 200) {
      throw StoryRepositoryException(
        'El servicio de historias respondió con estado ${response.statusCode}.',
      );
    }
    if (response.bodyBytes.length > _maximumResponseBytes) {
      throw const StoryRepositoryException(
        'La respuesta de historias supera el tamaño permitido.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const StoryRepositoryException(
        'El servicio devolvió un documento de historias inválido.',
      );
    }
    if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
      throw const StoryRepositoryException(
        'La versión del documento de historias no es compatible.',
      );
    }
    final rawStories = decoded['stories'];
    if (rawStories is! List || rawStories.length > 250) {
      throw const StoryRepositoryException(
        'La colección pública de historias no es válida.',
      );
    }

    final stories = <CityStory>[];
    final identifiers = <String>{};
    for (final raw in rawStories) {
      if (raw is! Map<String, dynamic>) {
        throw const StoryRepositoryException(
          'Una historia pública tiene un formato inválido.',
        );
      }
      final story = _parseStory(raw);
      if (!identifiers.add(story.id)) {
        throw const StoryRepositoryException(
          'La colección contiene identificadores duplicados.',
        );
      }
      stories.add(story);
    }
    if (stories.isEmpty) {
      throw const StoryRepositoryException(
        'Todavía no hay historias publicadas disponibles.',
      );
    }

    _cached = List.unmodifiable(stories);
    _cachedAt = DateTime.now();
    return List.unmodifiable(stories);
  }

  CityStory _parseStory(Map<String, dynamic> raw) {
    final id = _requiredString(raw, 'id', 120);
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const StoryRepositoryException(
        'Una historia contiene un identificador inválido.',
      );
    }
    final title = _requiredString(raw, 'title', 120);
    final summary = _requiredString(raw, 'summary', 420);
    final body = _requiredString(raw, 'body', 18000);
    final categoryId = _requiredString(raw, 'categoryId', 40);
    final categoryLabel = _requiredString(raw, 'categoryLabel', 80);
    final latitude = _requiredNumber(raw, 'latitude', -35.25, -34.55);
    final longitude = _requiredNumber(raw, 'longitude', -58.35, -57.55);
    final evidence = _requiredString(raw, 'evidence', 80);
    final readingMinutes = raw['readingMinutes'];
    if (readingMinutes is! int || readingMinutes < 1 || readingMinutes > 60) {
      throw const StoryRepositoryException(
        'Una historia contiene un tiempo de lectura inválido.',
      );
    }
    final likeCount = raw['likeCount'];
    if (likeCount is! int || likeCount < 0) {
      throw const StoryRepositoryException(
        'Una historia contiene un contador de Me gusta inválido.',
      );
    }
    final contributionOrigin = switch (raw['contributionOrigin']) {
      'community' => StoryContributionOrigin.community,
      'dardito_team' => StoryContributionOrigin.darditoTeam,
      null => StoryContributionOrigin.darditoTeam,
      _ => throw const StoryRepositoryException(
        'Una historia contiene una procedencia inválida.',
      ),
    };

    return CityStory(
      id: id,
      title: title,
      subtitle: _requiredString(raw, 'subtitle', 420),
      category: StoryCatalog.resolve(categoryId, categoryLabel),
      neighborhood: _requiredString(raw, 'neighborhood', 100),
      period: _requiredString(raw, 'period', 100),
      shortStory: summary,
      fullStory: body,
      source: _requiredString(raw, 'sourceName', 300),
      evidence: evidence,
      evidenceLabel: _evidenceLabel(raw['evidenceLabel'], evidence),
      mapX: .5,
      mapY: .5,
      latitude: latitude,
      longitude: longitude,
      featured: raw['featured'] == true,
      readMinutes: readingMinutes,
      likeCount: likeCount,
      publicAuthor: raw['publicAuthor'] is String
          ? raw['publicAuthor'] as String
          : null,
      contributionOrigin: contributionOrigin,
    );
  }

  String _requiredString(Map<String, dynamic> raw, String key, int maximum) {
    final value = raw[key];
    if (value is! String) {
      throw StoryRepositoryException('Falta el campo público $key.');
    }
    final normalized = value.replaceAll('\u0000', '').trim();
    if (normalized.isEmpty || normalized.length > maximum) {
      throw StoryRepositoryException('El campo público $key no es válido.');
    }
    return normalized;
  }

  String _evidenceLabel(Object? value, String evidence) {
    // Keep stored evidence intact, but never revive obsolete public labels.
    switch (evidence) {
      case 'documented':
        return 'Documentada';
      case 'oral_tradition':
      case 'community':
        return 'Aporte de vecinos';
    }
    if (value is String &&
        value.trim().isNotEmpty &&
        value.trim().length <= 100) {
      return value.trim();
    }
    return evidence;
  }

  double _requiredNumber(
    Map<String, dynamic> raw,
    String key,
    double minimum,
    double maximum,
  ) {
    final value = raw[key];
    if (value is! num || !value.isFinite) {
      throw StoryRepositoryException('Falta la coordenada pública $key.');
    }
    final number = value.toDouble();
    if (number < minimum || number > maximum) {
      throw StoryRepositoryException(
        'La coordenada pública $key no es válida.',
      );
    }
    return number;
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }
}
