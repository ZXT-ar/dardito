{{flutter_js}}
{{flutter_build_config}}

// Versionamos el entrypoint para evitar que una instalación/PWA antigua siga
// reutilizando un main.dart.js incompatible después de un despliegue.
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath === 'main.dart.js') {
    build.mainJsPath = 'main.dart.js?v=20261002-lectura-nocturna-v10';
  }
}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
