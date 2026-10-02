import 'dart:js_interop';
import 'package:web/web.dart' as web;

class ThemeStore {
  static const key = 'dardito_theme_v1';
  JSFunction? _listener;
  bool read() {
    try {
      return web.window.localStorage.getItem(key) == 'dark';
    } catch (_) {
      return false;
    }
  }

  void write(bool dark) {
    try {
      web.window.localStorage.setItem(key, dark ? 'dark' : 'light');
    } catch (_) {}
  }

  void listen(void Function(bool) changed) {
    _listener = ((web.Event event) {
      final storage = event as web.StorageEvent;
      if (storage.key == key || storage.key == null) changed(read());
    }).toJS;
    web.window.addEventListener('storage', _listener);
  }

  void dispose() {
    if (_listener != null) web.window.removeEventListener('storage', _listener);
  }
}
