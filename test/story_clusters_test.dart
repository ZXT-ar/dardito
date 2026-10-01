import 'package:dardito/data/catalogs/story_catalog.dart';
import 'package:dardito/data/models/story.dart';
import 'package:dardito/features/explore/map/story_clusters.dart';
import 'package:flutter_test/flutter_test.dart';

CityStory story(String id, double longitude) => CityStory(
  id: id,
  title: id,
  subtitle: 'Bajada',
  category: StoryCatalog.categories.first,
  neighborhood: 'Centro',
  period: '1900',
  shortStory: 'Resumen',
  fullStory: 'Relato',
  source: 'Archivo',
  evidence: 'documented',
  evidenceLabel: 'Documentada',
  mapX: .5,
  mapY: .5,
  latitude: -34.92,
  longitude: longitude,
);

void main() {
  test('agrupa cercanas, conserva lejanas y separa al acercarse', () {
    final stories = [
      story('a', -57.95),
      story('b', -57.949),
      story('c', -58.02),
    ];
    final far = clusterStories(stories, 12);
    expect(far.map((c) => c.stories.length), [2, 1]);
    expect(clusterStories(stories, 18).length, 3);
    expect(far.expand((c) => c.stories).map((s) => s.id).toSet(), {
      'a',
      'b',
      'c',
    });
  });
  test('coincidentes siguen accesibles incluso al máximo zoom', () {
    final stories = [story('a', -57.95), story('b', -57.95)];
    expect(clusterStories(stories, 18).single.stories.length, 2);
    expect(clusterStories([stories.first], 12).single.stories.single.id, 'a');
    expect(clusterStories([], 12), isEmpty);
  });
  test('agrupación estable sin unir cadenas de puntos lejanos', () {
    final stories = [
      story('a', -57.95),
      story('b', -57.9498),
      story('c', -57.9496),
    ];
    final clusters = clusterStories(stories, 18);
    expect(clusters.map((c) => c.stories.length), [2, 1]);
    expect(
      clusterStories(
        stories.reversed.toList(),
        18,
      ).map((c) => c.stories.map((s) => s.id).join(',')),
      clusters.map((c) => c.stories.map((s) => s.id).join(',')),
    );
  });
}
