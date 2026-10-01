import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../data/models/story.dart';
import '../config/backend_config.dart';

class UsageAnalyticsService {
  UsageAnalyticsService._();

  static final UsageAnalyticsService instance = UsageAnalyticsService._();

  final String _sessionId = _newSessionId();
  final Stopwatch _elapsed = Stopwatch();
  final Map<String, DateTime> _recentStoryViews = {};
  Timer? _heartbeat;

  void start() {
    if (_heartbeat != null) return;
    _elapsed.start();
    unawaited(_send('session_start'));
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_send('session_ping'));
    });
  }

  void storyViewed(CityStory story) {
    final now = DateTime.now();
    final previous = _recentStoryViews[story.id];
    if (previous != null && now.difference(previous) < const Duration(seconds: 12)) {
      return;
    }
    _recentStoryViews[story.id] = now;
    _recentStoryViews.removeWhere(
      (_, viewedAt) => now.difference(viewedAt) > const Duration(minutes: 10),
    );
    unawaited(_send('story_view', storyId: story.id));
  }

  void dispose() {
    if (_heartbeat == null) return;
    unawaited(_send('session_ping'));
    _heartbeat?.cancel();
    _heartbeat = null;
    _elapsed.stop();
  }

  Future<void> _send(String type, {String? storyId}) async {
    try {
      await http
          .post(
            BackendConfig.usageEndpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'type': type,
              'sessionId': _sessionId,
              'elapsedSeconds': _elapsed.elapsed.inSeconds,
              'storyId': ?storyId,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // La analítica nunca debe interrumpir la experiencia pública.
    }
  }

  static String _newSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}
