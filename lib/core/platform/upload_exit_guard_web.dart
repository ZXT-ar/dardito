import 'dart:js_interop';

import 'package:web/web.dart' as web;

class UploadExitGuard {
  web.EventListener? _listener;

  void enable() {
    if (_listener != null) return;
    _listener = ((web.Event event) {
      final beforeUnload = event as web.BeforeUnloadEvent;
      beforeUnload.preventDefault();
      beforeUnload.returnValue = 'Esperá, tu historia todavía se está cargando.';
    }).toJS;
    web.window.addEventListener('beforeunload', _listener);
  }

  void disable() {
    final listener = _listener;
    if (listener == null) return;
    web.window.removeEventListener('beforeunload', listener);
    _listener = null;
  }
}
