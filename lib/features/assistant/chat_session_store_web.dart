import 'package:web/web.dart' as web;

/// Session-only, per-tab storage. Never use localStorage for conversations.
class ChatSessionStore {
  String _key(String userId) => 'dardito_chat_session_v1:$userId';
  String? read(String userId) {
    try {
      return web.window.sessionStorage.getItem(_key(userId));
    } catch (_) {
      return null;
    }
  }

  void write(String userId, String value) {
    try {
      web.window.sessionStorage.setItem(_key(userId), value);
    } catch (_) {
      /* Storage restrictions must not interrupt a conversation. */
    }
  }

  void clear(String userId) {
    try {
      web.window.sessionStorage.removeItem(_key(userId));
    } catch (_) {
      /* Best effort if storage is disabled. */
    }
  }
}
