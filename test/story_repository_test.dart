import 'dart:convert';

import 'package:dardito/data/repositories/story_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('convierte el contrato público en historias de la aplicación', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.headers['Accept'], 'application/json');
      return http.Response(
        jsonEncode({
          'schemaVersion': 1,
          'stories': [
            {
              'id': 'tuneles',
              'title': 'Los túneles bajo la ciudad',
              'subtitle': 'Entre planos y versiones',
              'summary': 'Una leyenda urbana de La Plata.',
              'body': 'Relato editorial completo y documentado.',
              'categoryId': 'mystery',
              'categoryLabel': 'Misterios',
              'neighborhood': 'Centro',
              'period': 'Siglo XIX',
              'evidence': 'oral_tradition',
              'sourceName': 'Archivo editorial',
              'latitude': -34.9186,
              'longitude': -57.9464,
              'featured': true,
              'readingMinutes': 4,
              'likeCount': 7,
              'contributionOrigin': 'community',
              'publicAuthor': 'Club del barrio',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final repository = RemoteStoryRepository(
      client: client,
      endpoint: Uri.parse('https://example.test/api/stories'),
    );

    final stories = await repository.fetchAll();

    expect(stories, hasLength(1));
    expect(stories.single.id, 'tuneles');
    expect(stories.single.category.id, 'mystery');
    expect(stories.single.featured, isTrue);
    expect(stories.single.likeCount, 7);
    expect(stories.single.contributionOrigin.name, 'community');
    expect(stories.single.publicAuthor, 'Club del barrio');
    expect(stories.single.withLikeCount(8).publicAuthor, 'Club del barrio');
    expect(stories.single.evidenceLabel, 'Aporte de vecinos');
  });

  test('rechaza documentos públicos con coordenadas inválidas', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'schemaVersion': 1,
          'stories': [
            {
              'id': 'fuera-de-rango',
              'title': 'Historia inválida',
              'subtitle': 'No debe cargarse',
              'summary': 'Resumen',
              'body': 'Relato',
              'categoryId': 'culture',
              'categoryLabel': 'Cultura',
              'neighborhood': 'Centro',
              'period': 'Actualidad',
              'evidence': 'documented',
              'sourceName': 'Archivo',
              'latitude': 0,
              'longitude': 0,
              'featured': false,
              'readingMinutes': 2,
              'likeCount': 0,
              'contributionOrigin': 'dardito_team',
            },
          ],
        }),
        200,
      ),
    );
    final repository = RemoteStoryRepository(
      client: client,
      endpoint: Uri.parse('https://example.test/api/stories'),
    );

    expect(repository.fetchAll(), throwsA(isA<StoryRepositoryException>()));
  });
}
