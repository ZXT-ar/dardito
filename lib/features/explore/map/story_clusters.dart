import 'dart:math' as math;

import '../../../data/models/story.dart';

class StoryCluster {
  StoryCluster(this.stories);
  final List<CityStory> stories;
  double get latitude =>
      stories.fold(0.0, (sum, s) => sum + s.latitude) / stories.length;
  double get longitude =>
      stories.fold(0.0, (sum, s) => sum + s.longitude) / stories.length;
}

/// Groups overlapping markers in screen space. The same pixel distance means
/// fewer meters as the user zooms in. Complete-link grouping avoids long chains.
List<StoryCluster> clusterStories(
  List<CityStory> stories,
  double zoom, {
  double radius = 64,
}) {
  final scale = 256 * math.pow(2, zoom);
  final points = <String, math.Point<double>>{};
  final sorted = [...stories]..sort((a, b) => a.id.compareTo(b.id));
  for (final story in sorted) {
    final sinLat = math
        .sin(story.latitude * math.pi / 180)
        .clamp(-.9999, .9999);
    points[story.id] = math.Point(
      (story.longitude + 180) / 360 * scale,
      (.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale,
    );
  }
  final clusters = <StoryCluster>[];
  for (final story in sorted) {
    StoryCluster? match;
    for (final cluster in clusters) {
      if (cluster.stories.every(
        (other) => points[story.id]!.distanceTo(points[other.id]!) <= radius,
      )) {
        match = cluster;
        break;
      }
    }
    if (match == null) {
      clusters.add(StoryCluster([story]));
    } else {
      match.stories.add(story);
    }
  }
  return clusters;
}
