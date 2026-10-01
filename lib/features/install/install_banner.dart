import 'package:flutter/material.dart';

import '../../core/platform/pwa_install_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';

class InstallBanner extends StatefulWidget {
  const InstallBanner({super.key});

  @override
  State<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<InstallBanner> {
  late final PwaInstallService _service;
  late PwaInstallInfo _info;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _service = createPwaInstallService();
    _info = _service.info;
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _info = _service.info);
    });
  }

  String get _deviceName => switch (_info.platform) {
    InstallPlatform.android => 'Android',
    InstallPlatform.ios => 'iPhone o iPad',
    InstallPlatform.macos => 'Mac',
    InstallPlatform.windows => 'Windows',
    InstallPlatform.other => 'este dispositivo',
  };

  IconData get _deviceIcon => switch (_info.platform) {
    InstallPlatform.android => Icons.android_rounded,
    InstallPlatform.ios => Icons.phone_iphone_rounded,
    InstallPlatform.macos => Icons.laptop_mac_rounded,
    InstallPlatform.windows => Icons.desktop_windows_rounded,
    InstallPlatform.other => Icons.install_desktop_rounded,
  };

  Future<void> _install() async {
    _info = _service.info;
    if (_info.isInstalled) return;
    if (!_info.canPrompt) {
      _showInstructions();
      return;
    }
    setState(() => _installing = true);
    final installed = await _service.requestInstall();
    if (!mounted) return;
    setState(() {
      _installing = false;
      _info = _service.info;
    });
    if (!installed && !_info.isInstalled) _showInstructions();
  }

  void _showInstructions() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) => _InstallInstructions(
      platform: _info.platform,
      deviceName: _deviceName,
      deviceIcon: _deviceIcon,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_info.isInstalled) {
      return Entrance(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: .74),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.yellow.withValues(alpha: .24)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_rounded,
                color: AppColors.successLime,
                size: 20,
              ),
              SizedBox(width: 9),
              Text(
                'El mapa ya está instalado',
                style: TextStyle(
                  color: AppColors.yellow,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Entrance(
      child: HoverLift(
        distance: 3,
        scale: 1.004,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: .13),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final identity = Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/brand/mhdlp_pictogram.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_deviceIcon, size: 16, color: AppColors.green),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'DETECTAMOS $_deviceName'.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  letterSpacing: .9,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Llevá el mapa con vos',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Acceso directo, pantalla completa y contenido disponible más rápido.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final action = FilledButton.icon(
                onPressed: _installing ? null : _install,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 17,
                  ),
                ),
                icon: _installing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _info.canPrompt
                            ? Icons.download_rounded
                            : Icons.add_to_home_screen_rounded,
                      ),
                label: Text(
                  _info.canPrompt ? 'Instalar el mapa' : 'Cómo instalarlo',
                ),
              );
              return compact
                  ? Column(
                      children: [
                        identity,
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: action),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 20),
                        action,
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }
}

class _InstallInstructions extends StatelessWidget {
  const _InstallInstructions({
    required this.platform,
    required this.deviceName,
    required this.deviceIcon,
  });
  final InstallPlatform platform;
  final String deviceName;
  final IconData deviceIcon;

  List<(IconData, String, String)> get _steps => switch (platform) {
    InstallPlatform.ios => [
      (
        Icons.ios_share_rounded,
        'Abrí Compartir',
        'En Safari, tocá el ícono de compartir de la barra inferior.',
      ),
      (
        Icons.add_box_outlined,
        'Agregar a inicio',
        'Elegí “Agregar a pantalla de inicio” en el menú.',
      ),
      (
        Icons.check_circle_outline_rounded,
        'Confirmá',
        'Tocá “Agregar”. El mapa aparecerá junto a tus aplicaciones.',
      ),
    ],
    InstallPlatform.macos => [
      (
        Icons.more_vert_rounded,
        'Abrí el menú',
        'En Chrome, abrí el menú del navegador. En Safari, usá Archivo.',
      ),
      (
        Icons.install_desktop_rounded,
        'Instalá la aplicación',
        'Elegí “Instalar el mapa” o “Agregar al Dock”.',
      ),
      (
        Icons.apps_rounded,
        'Abrilo desde tu Mac',
        'Quedará disponible en el Dock, Launchpad o Aplicaciones.',
      ),
    ],
    InstallPlatform.windows => [
      (
        Icons.install_desktop_rounded,
        'Buscá Instalar',
        'En Edge o Chrome, usá el ícono de instalación de la barra de direcciones.',
      ),
      (
        Icons.check_rounded,
        'Confirmá la instalación',
        'Aceptá “Instalar” en el cuadro del navegador.',
      ),
      (
        Icons.window_rounded,
        'Acceso desde Windows',
        'El mapa quedará en Inicio, Escritorio y la barra de tareas.',
      ),
    ],
    InstallPlatform.android => [
      (
        Icons.more_vert_rounded,
        'Abrí el menú de Chrome',
        'Tocá los tres puntos en la esquina superior.',
      ),
      (
        Icons.add_to_home_screen_rounded,
        'Instalá la app',
        'Elegí “Instalar aplicación” o “Agregar a pantalla principal”.',
      ),
      (
        Icons.check_circle_outline_rounded,
        'Confirmá',
        'El mapa aparecerá junto a tus aplicaciones.',
      ),
    ],
    InstallPlatform.other => [
      (
        Icons.browser_updated_rounded,
        'Usá un navegador compatible',
        'Abrí El Mapa de las Historias de La Plata con Chrome, Edge o Safari.',
      ),
      (
        Icons.install_desktop_rounded,
        'Buscá Instalar',
        'Usá el botón de instalación de la barra de direcciones o del menú.',
      ),
      (
        Icons.home_rounded,
        'Creá el acceso',
        'Confirmá para abrir el mapa como una aplicación independiente.',
      ),
    ],
  };

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 34),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/brand/mhdlp_pictogram.png',
                      width: 64,
                      height: 64,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instalar en $deviceName',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const Text(
                          'Solo lleva unos segundos.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              for (var i = 0; i < _steps.length; i++)
                _InstallStep(
                  number: i + 1,
                  icon: _steps[i].$1,
                  title: _steps[i].$2,
                  description: _steps[i].$3,
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.offline_bolt_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'La instalación no ocupa el espacio de una app tradicional y siempre abre la versión más reciente.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _InstallStep extends StatelessWidget {
  const _InstallStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });
  final int number;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Center(child: Icon(icon, color: AppColors.paper, size: 23)),
              Positioned(
                right: 4,
                top: 3,
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.yellow,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ],
    ),
  );
}
