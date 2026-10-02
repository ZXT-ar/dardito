import 'package:dardito/core/theme/app_theme.dart';
import 'package:dardito/data/catalogs/story_catalog.dart';
import 'package:dardito/data/models/story.dart';
import 'package:dardito/features/home/paper_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    (390.0, 1.0),
    (768.0, 1.0),
    (1440.0, 1.0),
    (390.0, 1.8),
  ]) {
    testWidgets('pestañas y lectura conservan destinos a $size', (
      tester,
    ) async {
      tester.view.physicalSize = Size(size.$1, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final stories = List.generate(
        4,
        (i) => CityStory(
          id: '$i',
          title: 'Historia de la ciudad número $i',
          subtitle: '',
          category: StoryCatalog.categories.first,
          neighborhood: '',
          period: '',
          shortStory: '',
          fullStory: '',
          source: '',
          evidence: 'documented',
          evidenceLabel: 'Documentada',
          mapX: .5,
          mapY: .5,
          latitude: -34.92,
          longitude: -57.95,
        ),
      );
      final categories = <String>[];
      CityStory? opened;
      var all = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(size.$1, 1000),
              textScaler: TextScaler.linear(size.$2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      PaperCategories(onExplore: categories.add),
                      const SizedBox(height: 72),
                      PaperFeatured(
                        stories: stories,
                        onOpen: (story) => opened = story,
                        onViewAll: () => all++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Arquitectura',
        'Misterios',
        'Cultura',
        'Tradición oral',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(categories, ['architecture', 'mystery', 'culture', 'memory']);
      for (final story in stories.take(3)) {
        final title = find.text(story.title);
        await tester.ensureVisible(title);
        await tester.pumpAndSettle();
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(opened, same(story));
      }
      expect(find.text(stories.last.title), findsNothing);
      await tester.ensureVisible(find.text('Ver todas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver todas'));
      expect(all, 1);
      expect(find.byType(Card), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
