import 'package:dardito/data/catalogs/story_catalog.dart';
import 'package:dardito/data/models/story.dart';
import 'package:dardito/features/story/story_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final author in <String?>[
    null,
    'Un usuario',
    'vecino@example.com',
    'Club del barrio',
  ]) {
    testWidgets('resumen muestra identidad seleccionada: $author', (
      tester,
    ) async {
      final story = CityStory(
        id: 'historia',
        title: 'Una historia',
        subtitle: 'Bajada',
        category: StoryCatalog.resolve('culture', 'Cultura'),
        neighborhood: 'Centro',
        period: 'Actualidad',
        shortStory: 'Relato breve.',
        fullStory: 'Relato completo.',
        source: 'Archivo',
        evidence: 'community',
        evidenceLabel: 'Aporte de vecinos',
        mapX: 0,
        mapY: 0,
        latitude: -34.92,
        longitude: -57.95,
        publicAuthor: author,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              height: 360,
              child: StoryCard(story: story, onTap: () {}),
            ),
          ),
        ),
      );
      if (author == null) {
        expect(find.textContaining('Aporte de:'), findsNothing);
      } else {
        expect(find.text('Aporte de: $author'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
