import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => macos,
      TargetPlatform.windows => windows,
      _ => throw UnsupportedError(
        'Firebase todavía no está configurado para esta plataforma.',
      ),
    };
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDBSNZ7i5iX11eMcSrryF3-B9JyDVQL3PI',
    appId: '1:607361358605:web:d0a4757893ccfd37c5ee44',
    messagingSenderId: '607361358605',
    projectId: 'dardito-742d2',
    authDomain: 'auth.darditohistoriasplatenses.com',
    storageBucket: 'dardito-742d2.firebasestorage.app',
    measurementId: 'G-63Z7EYPDSQ',
  );

  // Se completarán al registrar cada aplicación nativa con FlutterFire.
  static const android = web;
  static const ios = web;
  static const macos = web;
  static const windows = web;
}
