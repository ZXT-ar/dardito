# Backend Firebase de Dardito

## Objetivo

La web y WhatsApp usan el mismo núcleo conversacional. Cambia el adaptador de entrada/salida, pero se comparten el corpus, las reglas editoriales, la memoria, el rate limiting y el proveedor LLM.

```text
Flutter Web ── POST /api/chat ─┐
                               ├─ ChatService ─ Retrieval Firestore ─ Gemini API
WhatsApp ─ Webhook ─ Firestore ┘       │
                                      └─ conversaciones + trazabilidad
```

La región configurada es `southamerica-east1` (São Paulo), adecuada para usuarios de Argentina.

## Funciones incluidas

| Función | Tipo | Responsabilidad |
|---|---|---|
| `darditoChat` | HTTP v2 | Recibe consultas web, recupera corpus, llama al LLM y devuelve respuesta/fuentes. |
| `whatsappWebhook` | HTTP v2 | Verifica Meta, valida firma SHA-256, deduplica mensajes y confirma rápidamente. |
| `processWhatsAppInbound` | Firestore v2 | Procesa mensajes en segundo plano, usa el mismo chat y responde por Cloud API. |
| `upsertKnowledge` | Callable v2 | Alta/actualización de corpus sólo para usuarios con custom claim `admin: true`. |
| `submitStory` | HTTP v2 | Recibe aportes privados en estado `pending_review`. |
| `health` | HTTP v2 | Diagnóstico mínimo del servicio. |

## Colecciones Firestore

- `knowledge`: corpus publicado, borradores y archivados.
- `conversations/{id}/messages`: memoria breve y fuentes usadas.
- `whatsapp_inbound`: cola idempotente del canal; el teléfono se elimina después del envío exitoso.
- `story_submissions`: aportes pendientes de moderación.
- `rate_limits`: ventanas de control de abuso con identificadores hasheados.

Las reglas de Firestore niegan todo acceso cliente. Cloud Functions utiliza Admin SDK/IAM y es la única capa autorizada. Antes de construir un panel editorial, debe definirse Firebase Auth, custom claims y reglas específicas.

## Preparación de Firebase

Se necesita el plan Blaze porque Functions v2, Secret Manager y llamadas salientes al proveedor LLM/Meta pueden generar consumo.

1. Crear la base Firestore en modo producción.
2. Habilitar Cloud Functions, Cloud Build, Artifact Registry y Secret Manager cuando Firebase lo solicite.
3. Crear una clave de Gemini API en Google AI Studio.
4. Configurar los secretos sin guardarlos en el repositorio:

```bash
firebase use dardito-742d2
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set WHATSAPP_VERIFY_TOKEN
firebase functions:secrets:set WHATSAPP_APP_SECRET
firebase functions:secrets:set WHATSAPP_ACCESS_TOKEN
firebase functions:secrets:set WHATSAPP_PHONE_NUMBER_ID
```

Los cuatro secretos de WhatsApp pueden cargarse más adelante. La configuración
vive separada en `functions/src/whatsapp-config.ts`, por lo que el despliegue web
no los solicita. Hasta entonces las exportaciones de WhatsApp permanecen
desactivadas en `functions/src/index.ts`.

Configuración no sensible opcional en `functions/.env.dardito-742d2`:

```dotenv
GEMINI_MODEL=gemini-3.5-flash
WHATSAPP_GRAPH_VERSION=v23.0
ALLOWED_ORIGINS=https://dardito-742d2.web.app,https://dardito-742d2.firebaseapp.com
```

Actualizá `WHATSAPP_GRAPH_VERSION` a la versión vigente seleccionada en Meta antes de producción.

## Corpus inicial

El archivo `functions/seed/corpus.json` contiene las ocho historias actuales con clasificación editorial. Para cargarlo con credenciales administrativas locales:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/ruta/segura/service-account.json"
npm --prefix functions run seed
```

Si `gcloud auth` ya tiene una cuenta activa con permisos sobre el proyecto, el
mismo comando funciona sin descargar una cuenta de servicio:

```bash
npm --prefix functions run seed
```

El token se mantiene en memoria y no se imprime ni se guarda. No guardes el JSON
de una cuenta de servicio dentro del proyecto. Para cambios posteriores usá
`upsertKnowledge` desde un panel autenticado con claim `admin`.

## Desarrollo local

Firebase CLI 15 requiere JDK 21 o superior para el emulador de Firestore.

```bash
npm --prefix functions install
npm --prefix functions run build
firebase emulators:start --only functions,firestore,hosting
```

Al ejecutar sólo Flutter sin Hosting Emulator, puede apuntarse directamente a la función:

```bash
flutter run -d chrome \
  --dart-define=DARDITO_CHAT_ENDPOINT=http://127.0.0.1:5001/dardito-742d2/southamerica-east1/darditoChat
```

Con Hosting Emulator o Firebase Hosting no hace falta `dart-define`: el cliente usa `/api/chat` y el rewrite de `firebase.json`.

## Despliegue

```bash
npm --prefix functions run build
flutter build web --release
firebase deploy --only firestore:rules,firestore:indexes,functions:darditoChat,functions:health,functions:submitStory
firebase deploy --only hosting
```

Para desplegar por etapas:

```bash
firebase deploy --only functions:health,functions:darditoChat
```

Para habilitar WhatsApp más adelante, configurá los cuatro secretos de Meta,
volvé a exportar `whatsappWebhook` y `processWhatsAppInbound` desde
`functions/src/index.ts`, y recién entonces desplegá esas dos funciones.

## Configuración de WhatsApp Cloud API

1. Crear/configurar una app de Meta con el producto WhatsApp.
2. En Webhooks usar como callback la URL desplegada de `whatsappWebhook`.
3. Usar exactamente el valor guardado en `WHATSAPP_VERIFY_TOKEN`.
4. Suscribir el campo `messages`.
5. Guardar el App Secret en `WHATSAPP_APP_SECRET`; se usa para validar `X-Hub-Signature-256`.
6. Guardar el token permanente y Phone Number ID en los secretos correspondientes.
7. Configurar plantillas aprobadas para conversaciones iniciadas por la empresa. Las respuestas dentro de la ventana de atención pueden enviarse como texto libre según las reglas vigentes de Meta.

## Contrato HTTP del chat

Solicitud:

```json
{
  "message": "Contame un misterio del centro",
  "conversationId": "web-id-estable"
}
```

Respuesta:

```json
{
  "answer": "...",
  "conversationId": "web-id-estable",
  "sources": [
    {
      "id": "tuneles",
      "title": "Los túneles bajo la ciudad",
      "evidence": "oral_tradition",
      "sourceName": "Relatos urbanos y registros periodísticos; versiones en revisión"
    }
  ]
}
```

El corpus no se acepta desde el endpoint público: se administra por Firestore/`upsertKnowledge`, evitando que un usuario inyecte instrucciones como si fueran contenido editorial.

## Controles implementados y próximos

Implementado:

- secretos en Secret Manager;
- firma de webhooks Meta;
- deduplicación por message ID;
- rate limit persistente;
- identificadores de participantes hasheados;
- corpus server-side y fuentes retornadas;
- clasificación documentado/tradición oral/comunidad;
- conversación con memoria breve por `conversationId`;
- saludos, agradecimientos, despedidas y seguimiento contextual sin forzar historias;
- rechazo determinista de código, instrucciones técnicas, agresiones y temas ajenos;
- corpus aleatorio para “una historia al azar” y búsqueda temática con stopwords;
- CORS con allowlist;
- límites de longitud y fallback local en Flutter;
- Firestore cerrado a clientes.

Antes de producción pública:

- habilitar Firebase App Check en web y verificar tokens en `darditoChat`;
- configurar TTL para `whatsapp_inbound`, `rate_limits` y la retención de conversaciones;
- definir política de borrado/exportación de datos;
- agregar alertas de errores, presupuesto y cuotas;
- revisar editorialmente fuentes y textos del corpus;
- probar templates, ventana de atención y opt-in de WhatsApp;
- reemplazar el fallback local por un mensaje operativo cuando el backend tenga SLA definido.
