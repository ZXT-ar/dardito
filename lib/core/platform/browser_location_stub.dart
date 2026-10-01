import 'browser_location_base.dart';

BrowserLocationController createBrowserLocationController() =>
    _StubBrowserLocationController();

class _StubBrowserLocationController implements BrowserLocationController {
  @override
  Uri get uri => Uri.base;

  @override
  void pushPath(String path) {}

  @override
  void replacePath(String path) {}

  @override
  void listen(BrowserLocationListener listener) {}

  @override
  void dispose() {}
}
