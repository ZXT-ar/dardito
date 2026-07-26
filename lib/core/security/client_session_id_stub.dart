import 'dart:math';

class ClientSessionId {
  ClientSessionId._();

  static final String value = _generate();

  static String _generate() {
    final random = Random.secure();
    return 'session-${DateTime.now().microsecondsSinceEpoch}-'
        '${random.nextInt(0x7fffffff)}-${random.nextInt(0x7fffffff)}';
  }
}
