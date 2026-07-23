# Dardito

Primera versión funcional de la aplicación web **Dardito — El guardián de las historias de La Plata**, desarrollada con Flutter y Dart.

## Qué incluye

- Portada responsive basada en la identidad visual aprobada.
- Mapa estilizado e interactivo con marcadores, filtros por categoría y barrio, búsqueda y vista en grilla.
- Ocho historias iniciales con ficha completa, fuente y nivel editorial: documentada, tradición oral o aporte comunitario.
- Asistente conversacional funcional de demostración, con sugerencias y acceso contextual al mapa.
- Formulario validado para enviar historias, consentimiento y flujo de revisión.
- Accesos a WhatsApp listos para asociar al número definitivo.
- Experiencia adaptada a escritorio y móvil, con navegación específica para cada tamaño.
- Navegación flotante animada, transiciones entre secciones, entradas progresivas y microinteracciones de hover.
- Puerta de acceso OAuth para Gmail e iCloud, actualmente conectada a un servicio demo intercambiable.
- Centro legal accesible desde el footer, con términos, privacidad y selector animado entre documentos.
- Navbar realmente superpuesto sobre el contenido, sin una franja de fondo reservada por el layout.
- PWA instalable con detección de Android, iOS, macOS y Windows, prompt nativo cuando está disponible y guía específica por plataforma.
- Ícono propio de Dardito, service worker, funcionamiento standalone y accesos rápidos desde el sistema operativo.
- Metadatos PWA y build web de producción.
- Backend Firebase Functions v2 compartido entre web y WhatsApp, con RAG sobre corpus curado, Gemini, memoria, rate limiting, webhooks firmados y cola Firestore.

## Arquitectura

```text
lib/
├── core/                 # tema, tokens y componentes compartidos
├── data/
│   ├── models/           # entidades y niveles editoriales
│   └── repositories/     # contrato y repositorio local de contenidos
├── features/
│   ├── home/             # portada y propuesta de valor
│   ├── explore/          # mapa, búsqueda y filtros
│   ├── story/            # tarjetas y fichas de historias
│   ├── assistant/        # experiencia conversacional
│   └── contribute/       # recepción y moderación inicial
├── app.dart              # composición, navegación y dependencias
└── main.dart             # entrada
```

La capa de datos usa un contrato `StoryRepository`, por lo que el contenido local puede sustituirse por una API sin cambiar las pantallas. La autenticación utiliza el contrato `AuthService`: `DemoAuthService` permite probar hoy todo el recorrido y se reemplazará por la implementación OAuth real cuando estén disponibles los Client ID, secretos, redirects y endpoints del microservicio.

## Ejecutar

```bash
flutter pub get
flutter run -d chrome
```

Validación y build:

```bash
flutter analyze
flutter test
flutter build web --release
```

El resultado de producción se genera en `build/web`.

## Instalar Dardito como aplicación

La aplicación detecta automáticamente el sistema y muestra la acción correspondiente en la portada. En producción debe publicarse bajo HTTPS; `localhost` también permite probar service workers e instalación.

### Android

1. Abrir Dardito con Chrome.
2. Tocar **Instalar Dardito**. Si el prompt no está disponible, abrir el menú de tres puntos.
3. Elegir **Instalar aplicación** o **Agregar a pantalla principal**.
4. Dardito aparecerá junto a las demás aplicaciones.

### iPhone y iPad

1. Abrir Dardito con Safari.
2. Tocar el botón **Compartir**.
3. Elegir **Agregar a pantalla de inicio**.
4. Confirmar con **Agregar**.

iOS no expone un prompt automático de instalación; por eso la interfaz muestra una guía específica.

### macOS / MacBook

En Chrome o Edge, usar **Instalar Dardito** desde la aplicación o el ícono de instalación de la barra de direcciones. En Safari compatible, elegir **Archivo → Agregar al Dock**. La aplicación queda disponible en Dock, Launchpad o Aplicaciones.

### Windows

1. Abrir Dardito con Edge o Chrome.
2. Presionar **Instalar Dardito** o el ícono de instalación de la barra de direcciones.
3. Confirmar la instalación.
4. Elegir los accesos deseados: menú Inicio, Escritorio o barra de tareas.

La PWA se abre en una ventana independiente, conserva el acceso directo y actualiza sus recursos mediante el service worker generado por Flutter.

## Próxima etapa de integración

1. Conectar también `StoryRepository` al corpus Firestore para que mapa y agente lean una única fuente editorial.
2. Desplegar y operar el agente RAG ya implementado, configurar secretos, App Check, métricas y alertas.
3. Implementar OAuth real para Google y Sign in with Apple, incluyendo callback seguro y sesión persistente.
4. Conectar visualmente el formulario al endpoint de aportes ya disponible y sumar Storage privado para archivos.
5. Cargar credenciales y asociar los webhooks ya implementados al número definitivo de WhatsApp Business.
6. Sustituir o complementar el plano estilizado con una capa cartográfica georreferenciada.
7. Incorporar autenticación editorial, métricas, privacidad y términos definitivos.

## Backend Firebase

La infraestructura serverless está en `functions/`. El chat web ya utiliza `/api/chat` sin alterar su interfaz y conserva el motor local como respaldo mientras la función no esté disponible. La guía de secretos, corpus, emuladores, despliegue y WhatsApp está en [`docs/backend_firebase.md`](docs/backend_firebase.md).

> Las historias incluidas son contenido inicial de demostración. Deben revisarse editorialmente y documentarse antes de una publicación institucional.
