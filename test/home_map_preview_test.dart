import 'package:dardito/data/catalogs/story_catalog.dart';
import 'package:dardito/data/models/story.dart';
import 'package:dardito/features/explore/map/dardito_map_surface.dart';
import 'package:dardito/features/home/home_map_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra todo el catálogo y abre Explorar con clic y teclado', (
    tester,
  ) async {
    final stories = List.generate(
      9,
      (i) => CityStory(
        id: '$i',
        title: 'Historia $i',
        subtitle: '',
        category: StoryCatalog.categories.first,
        neighborhood: 'Centro',
        period: '1882',
        shortStory: 'Resumen',
        fullStory: 'Relato',
        source: 'Archivo',
        evidence: 'documented',
        evidenceLabel: 'Documentada',
        mapX: .5,
        mapY: .5,
        latitude: -34.92,
        longitude: -57.95 + i * .001,
      ),
    );
    var opened = 0;
    Widget preview(List<CityStory> current) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 470,
          child: HomeMapPreview(
            stories: current,
            style: null,
            onExplore: () => opened++,
          ),
        ),
      ),
    );
    await tester.pumpWidget(preview(stories));
    expect(
      tester.widget<DarditoMapSurface>(find.byType(DarditoMapSurface)).stories,
      same(stories),
    );
    await tester.tap(find.byKey(const ValueKey('home-map-open-explore')));
    await tester.pump();
    expect(opened, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, 2);
    final updated = stories.take(8).toList();
    await tester.pumpWidget(preview(updated));
    expect(
      tester.widget<DarditoMapSurface>(find.byType(DarditoMapSurface)).stories,
      same(updated),
    );
    expect(tester.takeException(), isNull);
  });
}
