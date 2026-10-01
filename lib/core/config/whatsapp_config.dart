class WhatsAppConfig {
  WhatsAppConfig._();

  static const phoneNumber = '5492213197058';
  static const displayPhoneNumber = '+54 9 221 319-7058';

  static Uri conversationUri({String? message}) => Uri.https(
    'wa.me',
    '/$phoneNumber',
    message == null || message.trim().isEmpty
        ? null
        : <String, String>{'text': message.trim()},
  );
}
