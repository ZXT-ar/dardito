import 'package:dardito/features/assistant/story_image_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final origin = Uri.parse('https://dardito-742d2.web.app');
  test(
    'carga sólo imágenes públicas de las fuentes y reutiliza consultas',
    () async {
      final requested = <String>[];
      final service = StoryImageService(
        origin: origin,
        client: MockClient((request) async {
          requested.add(request.url.path);
          return http.Response('''
        <meta content="https://dardito-742d2.web.app/api/story-images/plaza" property="og:image">
        <meta property="og:image:alt" content="Imagen de Plaza &amp; barrio">
      ''', 200);
        }),
      );
      final images = await service.load(['plaza', 'plaza', '../private']);
      expect(images, hasLength(1));
      expect(
        images.single.url,
        'https://dardito-742d2.web.app/api/story-images/plaza',
      );
      expect(images.single.title, 'Imagen de Plaza & barrio');
      await service.load(['plaza']);
      expect(requested, ['/historias/plaza']);
    },
  );

  test(
    'omite logos, fotos de otras historias, hosts ajenos y fallos',
    () async {
      final service = StoryImageService(
        origin: origin,
        client: MockClient((request) async {
          final id = request.url.path.split('/').last;
          if (id == 'failed') throw http.ClientException('sin conexión');
          if (id == 'missing') return http.Response('No disponible', 404);
          final image = switch (id) {
            'logo' => 'https://dardito-742d2.web.app/assets/logo.jpg',
            'other' =>
              'https://dardito-742d2.web.app/api/story-images/different',
            _ => 'https://untrusted.example/api/story-images/external',
          };
          return http.Response(
            '<meta property="og:image" content="$image">',
            200,
          );
        }),
      );
      expect(
        await service.load(['logo', 'other', 'external', 'failed', 'missing']),
        isEmpty,
      );
      expect(await service.load([]), isEmpty);
    },
  );
}
