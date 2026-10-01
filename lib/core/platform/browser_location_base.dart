typedef BrowserLocationListener = void Function(Uri uri);

abstract interface class BrowserLocationController {
  Uri get uri;

  void pushPath(String path);

  void replacePath(String path);

  void listen(BrowserLocationListener listener);

  void dispose();
}
