import 'package:dardito/core/config/whatsapp_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('crea el enlace canónico al número productivo de WhatsApp', () {
    expect(
      WhatsAppConfig.conversationUri().toString(),
      'https://wa.me/5492213197058',
    );
  });

  test('codifica el mensaje inicial sin alterar el número', () {
    final uri = WhatsAppConfig.conversationUri(
      message: 'Hola Dardito\nUna historia & su enlace',
    );

    expect(uri.host, 'wa.me');
    expect(uri.path, '/5492213197058');
    expect(
      uri.queryParameters['text'],
      'Hola Dardito\nUna historia & su enlace',
    );
  });
}
