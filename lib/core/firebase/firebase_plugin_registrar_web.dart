import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_storage_web/firebase_storage_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Refuerza el registro de los plugins críticos de Firebase en builds web
/// optimizados. El registrador generado por Flutter sigue siendo la vía
/// principal; esta llamada es idempotente y evita caer en MethodChannel si el
/// registrador web se ejecuta de forma incompleta.
void ensureFirebaseWebPluginsRegistered() {
  final registrar = webPluginRegistrar;
  FirebaseAuthWeb.registerWith(registrar);
  FirebaseCoreWeb.registerWith(registrar);
  FirebaseStorageWeb.registerWith(registrar);
}
