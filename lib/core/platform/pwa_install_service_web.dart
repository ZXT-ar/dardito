import 'dart:js_interop';

import 'pwa_install_service_stub.dart';
export 'pwa_install_service_stub.dart'
    show InstallPlatform, PwaInstallInfo, PwaInstallService;

@JS('darditoPlatform')
external JSFunction get _platformFunction;

@JS('darditoCanInstall')
external JSFunction get _canInstallFunction;

@JS('darditoIsStandalone')
external JSFunction get _isStandaloneFunction;

@JS('darditoInstallPwa')
external JSFunction get _installFunction;

PwaInstallService createPwaInstallService() => _WebPwaInstallService();

class _WebPwaInstallService implements PwaInstallService {
  @override
  PwaInstallInfo get info => PwaInstallInfo(
    platform: _parsePlatform(
      (_platformFunction.callAsFunction() as JSString).toDart,
    ),
    canPrompt: (_canInstallFunction.callAsFunction() as JSBoolean).toDart,
    isInstalled: (_isStandaloneFunction.callAsFunction() as JSBoolean).toDart,
  );

  @override
  Future<bool> requestInstall() async {
    final promise = _installFunction.callAsFunction() as JSPromise<JSString>;
    final result = (await promise.toDart).toDart;
    return result == 'accepted';
  }

  InstallPlatform _parsePlatform(String value) => switch (value) {
    'android' => InstallPlatform.android,
    'ios' => InstallPlatform.ios,
    'macos' => InstallPlatform.macos,
    'windows' => InstallPlatform.windows,
    _ => InstallPlatform.other,
  };
}
