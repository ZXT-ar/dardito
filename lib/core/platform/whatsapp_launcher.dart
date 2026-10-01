import 'package:url_launcher/url_launcher.dart';

import '../config/whatsapp_config.dart';

Future<bool> openDarditoWhatsApp({String? message}) async {
  try {
    return await launchUrl(
      WhatsAppConfig.conversationUri(message: message),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
