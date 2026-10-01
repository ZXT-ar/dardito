import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'browser_location_base.dart';

BrowserLocationController createBrowserLocationController() =>
    _WebBrowserLocationController();

class _WebBrowserLocationController implements BrowserLocationController {
  web.EventListener? _popStateListener;

  @override
  Uri get uri => Uri.parse(web.window.location.href);

  @override
  void pushPath(String path) {
    web.window.history.pushState(null, '', path);
  }

  @override
  void replacePath(String path) {
    web.window.history.replaceState(null, '', path);
  }

  @override
  void listen(BrowserLocationListener listener) {
    dispose();
    _popStateListener = ((web.Event _) => listener(uri)).toJS;
    web.window.addEventListener('popstate', _popStateListener);
  }

  @override
  void dispose() {
    final listener = _popStateListener;
    if (listener == null) return;
    web.window.removeEventListener('popstate', listener);
    _popStateListener = null;
  }
}
