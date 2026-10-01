import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/firebase/firebase_plugin_registrar.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ensureFirebaseWebPluginsRegistered();
  runApp(const _DarditoBootstrap());
}

class _DarditoBootstrap extends StatefulWidget {
  const _DarditoBootstrap();

  @override
  State<_DarditoBootstrap> createState() => _DarditoBootstrapState();
}

class _DarditoBootstrapState extends State<_DarditoBootstrap> {
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 4));
    } on TimeoutException {
      // En algunos builds web optimizados Firebase Auth puede demorar su
      // primera notificación aunque la aplicación Firebase ya esté creada.
      // Si el core existe, es seguro continuar: Auth conserva su listener y
      // termina de hidratar la sesión en segundo plano.
      if (Firebase.apps.isEmpty) {
        if (mounted) {
          setState(() {
            _error = StateError('Firebase no pudo iniciar a tiempo.');
          });
        }
        return;
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
      return;
    }

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const DarditoApp();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF111411),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _error == null
                ? const _BootstrapLoader()
                : _BootstrapError(
                    onRetry: () {
                      setState(() => _error = null);
                      _initializeFirebase();
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapLoader extends StatelessWidget {
  const _BootstrapLoader();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/brand/mhdlp_logo_horizontal.jpg',
          width: 260,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
      const SizedBox(height: 24),
      const SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Color(0xFFF4B900),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Abriendo el mapa de historias…',
        style: TextStyle(color: Color(0xFFF5F0E7), fontSize: 15),
      ),
    ],
  );
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          'assets/brand/mhdlp_pictogram.png',
          width: 76,
          height: 76,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'No pudimos abrir El Mapa de las Historias de La Plata',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFFF5F0E7),
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Revisá tu conexión y volvé a intentarlo.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFFCBC5BA), fontSize: 15),
      ),
      const SizedBox(height: 22),
      FilledButton(
        onPressed: onRetry,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF4B900),
          foregroundColor: const Color(0xFF111411),
        ),
        child: const Text('Reintentar'),
      ),
    ],
  );
}
