import 'browser_location_stub.dart'
    if (dart.library.js_interop) 'browser_location_web.dart'
    as implementation;

export 'browser_location_base.dart';

import 'browser_location_base.dart';

BrowserLocationController createBrowserLocationController() =>
    implementation.createBrowserLocationController();
