import 'dart:math';

import 'package:web/web.dart' as web;

class ClientSessionId {
  ClientSessionId._();

  static const _storageKey = 'dardito_security_session_id';
  static final String value = _loadOrCreate();

  static String _loadOrCreate() {
    final stored = web.window.localStorage.getItem(_storageKey);
    if (stored != null && RegExp(r'^[a-zA-Z0-9_-]{16,160}$').hasMatch(stored)) {
      return stored;
    }
    final random = Random.secure();
    final created =
        'session-${DateTime.now().microsecondsSinceEpoch}-'
        '${random.nextInt(0x7fffffff)}-${random.nextInt(0x7fffffff)}';
    web.window.localStorage.setItem(_storageKey, created);
    return created;
  }
}
