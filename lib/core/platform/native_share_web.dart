import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> shareWithSystem({
  required String title,
  required String text,
  required Uri url,
}) async {
  try {
    final data = web.ShareData(title: title, text: text, url: url.toString());
    if (!web.window.navigator.canShare(data)) return false;
    await web.window.navigator.share(data).toDart;
    return true;
  } catch (_) {
    return false;
  }
}
