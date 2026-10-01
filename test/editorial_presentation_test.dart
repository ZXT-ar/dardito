import 'dart:convert';

import 'package:dardito/core/theme/app_theme.dart';
import 'package:dardito/data/catalogs/story_catalog.dart';
import 'package:dardito/data/repositories/catalog_repository.dart';
import 'package:dardito/data/repositories/story_repository.dart';
import 'package:dardito/features/home/home_page.dart';
import 'package:dardito/features/story/story_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('tarjetas completas y navegación a $width px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previousCategories = StoryCatalog.categories;
      addTearDown(() => StoryCatalog.categories = previousCategories);
      // An incomplete remote catalog must not remove any of the four doors.
      StoryCatalog.applyRemote(
        categoryEntries: const [
          PublicCatalogEntry(
            'architecture',
            'Arquitectura',
            description: 'Descripción editorial de arquitectura.',
          ),
          PublicCatalogEntry('memory', 'Memoria viva', description: '  '),
        ],
        evidenceEntries: const [],
      );
      var openedMap = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HomePage(
              stories: const [],
              onExplore: (_) => openedMap++,
              onExploreCategory: (_) => openedMap++,
              onNavigate: (_) {},
              onOpenLegal: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      for (final title in [
        'Arquitectura',
        'Misterios',
        'Cultura',
        'Tradición oral',
      ]) {
        final label = find.text(title);
        expect(label, findsOneWidget);
        await Scrollable.ensureVisible(tester.element(label), alignment: .5);
        await tester.pump(const Duration(seconds: 1));
        final card = find.ancestor(of: label, matching: find.byType(Card));
        final textWidgets = tester
            .widgetList<Text>(
              find.descendant(of: card, matching: find.byType(Text)),
            )
            .toList();
        expect(textWidgets, hasLength(2));
        expect(textWidgets.last.data, isNotEmpty);
        expect(textWidgets.last.maxLines, isNull);
        expect(textWidgets.last.overflow, isNot(TextOverflow.ellipsis));
        final cardRect = tester.getRect(card);
        final descriptionRect = tester.getRect(
          find.text(textWidgets.last.data!),
        );
        expect(descriptionRect.bottom, lessThanOrEqualTo(cardRect.bottom));
        await tester.tap(label);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      expect(openedMap, 4);
      expect(
        find.text('Descripción editorial de arquitectura.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Historias que se transmitieron'),
        findsOneWidget,
      );
      expect(find.text('Memoria viva'), findsNothing);
      expect(find.text('Una ciudad imaginada'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final entry in [
    ('documented', 'Historia documentada', 'Documentada'),
    (
      'oral_tradition',
      'Tradición oral · versiones en revisión',
      'Aporte de vecinos',
    ),
    ('community', 'Aporte de la comunidad', 'Aporte de vecinos'),
    ('legacy_custom', 'Clasificación histórica', 'Clasificación histórica'),
    ('legacy_without_label', null, 'legacy_without_label'),
  ]) {
    testWidgets('lee y abre ficha histórica ${entry.$1}', (tester) async {
      final repository = RemoteStoryRepository(
        endpoint: Uri.parse('https://example.test/stories'),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'schemaVersion': 1,
              'stories': [
                {
                  'id': 'historia-${entry.$1}',
                  'title': 'Historia conservada',
                  'subtitle': 'Bajada original',
                  'summary': 'Resumen original',
                  'body': 'Relato original conservado.',
                  'categoryId': 'memory',
                  'categoryLabel': 'Memoria viva',
                  'neighborhood': 'Centro',
                  'period': '1900',
                  'evidence': entry.$1,
                  if (entry.$2 != null) 'evidenceLabel': entry.$2,
                  'sourceName': 'Archivo original',
                  'latitude': -34.92,
                  'longitude': -57.95,
                  'readingMinutes': 2,
                  'likeCount': 0,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      final story = (await repository.fetchAll()).single;
      expect(story.evidence, entry.$1);
      expect(story.evidenceLabel, entry.$3);
      expect(story.category.id, 'memory');
      expect(story.fullStory, 'Relato original conservado.');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showStoryDetails(context, story),
                child: const Text('Abrir historia'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir historia'));
      await tester.pumpAndSettle();
      expect(find.text(entry.$3), findsOneWidget);
      expect(find.text('Relato original conservado.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
