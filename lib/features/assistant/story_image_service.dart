import 'package:http/http.dart' as http;

class AssistantStoryImage {
  const AssistantStoryImage({required this.url, required this.title});
  final String url;
  final String title;
}

/// Uses the existing public page's image metadata: the image endpoint alone
/// redirects to the brand logo when no authorized photo exists.
class StoryImageService {
  StoryImageService({http.Client? client, Uri? origin})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _origin = origin ?? Uri.base;

  final http.Client _client;
  final bool _ownsClient;
  final Uri _origin;
  final _cache = <String, Future<AssistantStoryImage?>>{};

  Future<List<AssistantStoryImage>> load(List<String> sourceIds) async {
    final ids = sourceIds
        .where((id) => RegExp(r'^[a-zA-Z0-9_-]{1,120}$').hasMatch(id))
        .toSet()
        .take(6);
    final images = await Future.wait(
      ids.map((id) => _cache.putIfAbsent(id, () => _loadOne(id))),
    );
    return images.whereType<AssistantStoryImage>().toList(growable: false);
  }

  Future<AssistantStoryImage?> _loadOne(String id) async {
    try {
      final response = await _client
          .get(
            _origin.resolve('/historias/$id'),
            headers: const {'Accept': 'text/html'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final image = _metadata(response.body, 'og:image');
      if (image == null) return null;
      final uri = Uri.tryParse(image);
      // Only the published story image is eligible, never fallback logos,
      // arbitrary links in the answer, or private editorial attachments.
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'dardito-742d2.web.app' ||
          uri.path != '/api/story-images/$id' ||
          uri.hasQuery) {
        return null;
      }
      final label = _metadata(response.body, 'og:image:alt');
      return AssistantStoryImage(
        url: _origin.resolve(uri.path).toString(),
        title: label ?? 'Imagen de la historia',
      );
    } catch (_) {
      // An unavailable photo must never prevent a text answer.
      return null;
    }
  }

  String? _metadata(String html, String property) {
    for (final tag in RegExp(
      r'<meta\b[^>]*>',
      caseSensitive: false,
    ).allMatches(html)) {
      final attributes = <String, String>{};
      for (final match in RegExp(
        '([\\w:-]+)\\s*=\\s*(["\\\'])(.*?)\\2',
        dotAll: true,
      ).allMatches(tag.group(0)!)) {
        attributes[match.group(1)!.toLowerCase()] = match.group(3)!;
      }
      if (attributes['property'] == property) {
        return attributes['content']
            ?.replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&');
      }
    }
    return null;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
