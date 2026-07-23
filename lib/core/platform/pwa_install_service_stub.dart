enum InstallPlatform { android, ios, macos, windows, other }

class PwaInstallInfo {
  const PwaInstallInfo({
    required this.platform,
    required this.canPrompt,
    required this.isInstalled,
  });
  final InstallPlatform platform;
  final bool canPrompt;
  final bool isInstalled;
}

abstract interface class PwaInstallService {
  PwaInstallInfo get info;
  Future<bool> requestInstall();
}

PwaInstallService createPwaInstallService() => _StubPwaInstallService();

class _StubPwaInstallService implements PwaInstallService {
  @override
  PwaInstallInfo get info => const PwaInstallInfo(
    platform: InstallPlatform.other,
    canPrompt: false,
    isInstalled: false,
  );

  @override
  Future<bool> requestInstall() async => false;
}
