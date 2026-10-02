import 'package:dardito/core/theme/app_theme.dart';
import 'package:dardito/data/catalogs/story_catalog.dart';
import 'package:dardito/data/models/story.dart';
import 'package:dardito/features/home/home_cartography.dart';
import 'package:dardito/features/home/home_explore_invitation.dart';
import 'package:dardito/features/explore/map/map_zoom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un solo plano conserva coordenadas y escala entre secciones', () {
    final p = HomeMapProjection(const Size(1440, 1396), 796, 600);
    expect(
      HomeMapProjection.project(-34.9205, -57.954),
      const Offset(1920, 1080),
    );
    expect(p.location(-34.9205, -57.954), p.anchor);
    final a = p.source(const Offset(1000, 800));
    final b = p.source(const Offset(1000, 1600));
    expect(b.dy - a.dy, closeTo(800 * p.scale, .001));
    expect(b.dx, a.dx);
  });
  test('zoom permite superar 18 sin salir de los límites', () {
    expect(MapZoom.clamp(19), 19);
    expect(MapZoom.clamp(30), 21);
    expect(MapZoom.clamp(5), 10.8);
  });
  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets(
      'mapa continuo, activación reversible y marcador real a $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final story = CityStory(
          id: 'test',
          title: 'Plaza Moreno',
          subtitle: '',
          category: StoryCatalog.categories.first,
          neighborhood: 'Centro',
          period: '1882',
          shortStory: '',
          fullStory: '',
          source: '',
          evidence: 'documented',
          evidenceLabel: 'Documentada',
          mapX: .5,
          mapY: .5,
          latitude: -34.9205,
          longitude: -57.954,
        );
        CityStory? opened;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    HomeCartography(
                      hero: const SizedBox(height: 796),
                      stories: [story],
                      onExplore: (s) => opened = s,
                    ),
                    const SizedBox(height: 900),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('continuous-home-map')),
          findsOneWidget,
        );
        CompassPainter needle() => tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<CompassPainter>()
            .single;
        expect(needle().angle, 0);
        scroll.jumpTo(620);
        await tester.pumpAndSettle();
        expect(needle().angle, greaterThan(2));
        final pin = find.text('01');
        await tester.ensureVisible(pin);
        await tester.pumpAndSettle();
        await tester.tap(pin);
        await tester.pump();
        expect(opened, same(story));
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        expect(needle().angle, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('movimiento reducido activa el mapa sin requerir scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 900),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: HomeCartography(
                hero: const SizedBox(height: 796),
                stories: const [],
                onExplore: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final style = tester.widget<AnimatedDefaultTextStyle>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('cartography-heading')),
            matching: find.byType(AnimatedDefaultTextStyle),
          )
          .first,
    );
    expect(style.style.color, tiloInk);
    expect(tester.takeException(), isNull);
  });
}
