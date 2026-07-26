# Seguridad y moderación de Dardito

Versión operativa: 1.0 — 23 de julio de 2026

## Objetivo

Proteger a las personas, la identidad editorial de Dardito y la infraestructura sin
delegar las sanciones al modelo generativo. La moderación se ejecuta en el backend,
antes de recuperar el corpus y antes de llamar a Gemini. El mismo núcleo sirve para
web y, cuando se habilite, para WhatsApp.

## Regla de tarjetas

- Un mensaje infractor genera como máximo una tarjeta, aunque contenga varios
  insultos o active más de una categoría.
- Primera infracción: tarjeta amarilla `1/3`.
- Segunda infracción: tarjeta amarilla `2/3`.
- Tercera infracción: tarjeta roja y bloqueo de la sesión durante 72 horas.
- Mientras el bloqueo está activo no se llama al LLM ni se recupera corpus.
- Al terminar las 72 horas, el contador de esa sesión vuelve a cero.
- Amenazas creíbles y contenido sexual que involucre menores reciben roja directa.

El mensaje original infractor no se conserva en el registro de moderación. Se
almacenan su hash SHA-256, categorías, acción, canal, conversación y fecha. En la
memoria conversacional se reemplaza por `[mensaje moderado]`.

## Qué constituye una infracción

### Tarjeta amarilla

1. **Acoso e insultos directos:** insultos, degradación o agresión verbal hacia
   Dardito o terceras personas.
2. **Solicitudes obscenas:** pedido de pornografía, desnudos o contenido sexual
   explícito.
3. **Lenguaje genital o sexual:** menciones de genitales y términos sexuales o
   vulgares definidos por la política editorial, incluso cuando aparezcan aislados.
4. **Instrucciones sobre armas o explosivos:** fabricación, adquisición, uso,
   modificación, ocultamiento o detonación.
5. **Violencia gráfica o instrumental:** solicitud de métodos, pasos o detalles para
   matar, torturar o causar lesiones graves.

### Tarjeta roja inmediata

1. **Amenaza creíble:** expresión de intención de matar o herir a una persona.
2. **Explotación sexual infantil:** cualquier pedido sexual que involucre menores.

### No son infracciones

- Una consulta histórica, periodística, educativa o preventiva sobre guerras,
  delitos, armas o violencia, siempre que no solicite instrucciones dañinas.
- Pedir ayuda ante una crisis, violencia sufrida o riesgo de autolesión. Esos casos
  deben recibir una respuesta de apoyo, no una sanción.
- Preguntas fuera del alcance de Dardito, como programación. Se redirigen sin
  tarjeta.
- Críticas respetuosas, desacuerdo, errores ortográficos o lenguaje coloquial.

## Flujo de infraestructura

```text
Flutter Web / WhatsApp
        │
        ▼
Cloud Function darditoChat / adaptador WhatsApp
        │
        ├─ CORS + formato + longitud
        ├─ rate limit por IP/canal
        ├─ identidad de sesión hasheada
        ▼
Clasificador determinístico de moderación
        │
        ▼
Transacción Firestore moderation_sessions/{sessionHash}
        │
        ├─ bloqueo vigente ─────────────► respuesta roja, sin LLM
        ├─ infracción 1 o 2 ────────────► amarilla, sin LLM
        ├─ infracción 3 / crítica ──────► roja + 72 h, sin LLM
        └─ mensaje permitido
                    │
                    ▼
          memoria + corpus + Gemini
                    │
                    ▼
             respuesta de Dardito
```

La actualización del contador se realiza con una transacción de Firestore. Esto
evita que dos mensajes simultáneos lean el mismo contador y pierdan una infracción.

## Modelo de datos

```text
moderation_sessions/{sha256(canal + participante)}
  channel
  yellowCount
  blockedUntil
  lastCategories[]
  createdAt
  updatedAt

moderation_sessions/{id}/events/{uuid}
  action
  categories[]
  conversationId
  messageHash
  createdAt
```

Firestore permanece cerrado a clientes. Sólo las Cloud Functions con Admin SDK
pueden leer o modificar sanciones.

## Identidad y límites actuales

En web se calculan dos alcances de seguridad, almacenados únicamente como hashes:

1. **Sesión persistente:** un identificador aleatorio guardado en
   `localStorage` como `dardito_security_session_id`. Conserva el contador de
   amarillas al recargar o volver a abrir el navegador.
2. **Red:** la IP obtenida por la Cloud Function desde `X-Forwarded-For`/`request.ip`.
   Cuando se emite una roja, el bloqueo de 72 horas se escribe tanto para la sesión
   como para esa IP.

`conversationId` se usa para memoria conversacional y no identifica un bloqueo. No
se utilizan cookies publicitarias, fingerprinting del dispositivo, ubicación ni
datos personales declarados.

Una ventana incógnita crea otra sesión local, pero seguirá bloqueada mientras use la
misma IP sancionada. Este control tiene límites: una VPN, un cambio de red o una IP
dinámica pueden evadirlo; inversamente, una red compartida puede bloquear a otros
usuarios de la misma salida. Para una identidad inequívoca entre redes se necesita
inicio de sesión y una política de cuenta.

Antes de exposición pública se recomienda:

1. Cuenta autenticada para una identidad estable entre navegadores y redes.
2. Firebase App Check para validar que las solicitudes proceden de la aplicación
   real; activarlo primero en modo métricas y luego exigirlo.
3. En WhatsApp, usar el hash del número verificado como identidad del mismo motor de
   sanciones.
4. Consola editorial de revisión y apelación, con rol administrativo y trazabilidad.
5. TTL/retención: eventos de moderación por 90 días; rate limits por 24 horas;
   conversaciones según la política de privacidad aprobada.
6. Alertas por picos de rojas, tasa de errores, gasto, cuota y latencia.
7. Pruebas periódicas en español rioplatense para detectar evasiones y falsos
   positivos. La lista determinística debe versionarse y revisarse editorialmente.

App Check complementa a Authentication y no reemplaza el rate limiting ni la
moderación. Para el endpoint HTTP `onRequest` actual se debe verificar el token de
App Check explícitamente o migrar el chat a una función callable.

## Gestión de incidentes y apelación

- La interfaz informa la tarjeta, el contador y la duración del bloqueo.
- No se expone al usuario la lista interna completa de patrones.
- Un administrador podrá revisar categoría, fecha, hash y contexto no sensible.
- Una apelación aprobada deberá restablecer `yellowCount` y `blockedUntil`, dejando
  un evento de auditoría separado.
- El sistema no debe intentar identificar legalmente a la persona ni compartir
  registros salvo obligación válida y revisión humana.

## Controles de seguridad generales

Ya implementados:

- secretos del LLM en Secret Manager;
- Firestore sin acceso directo de clientes;
- CORS con allowlist;
- límites de longitud y rate limit persistente;
- corpus exclusivamente server-side;
- identificadores hasheados;
- moderación previa al LLM y sanción transaccional;
- minimización del texto infractor;
- sin herramientas o acciones externas concedidas al LLM.

Pendientes prioritarios:

- rotar cualquier clave que haya sido compartida en chats, capturas o repositorios;
- restringir la clave de Google Maps por dominio y exclusivamente a Maps JavaScript API;
- App Check + autenticación anónima;
- política formal de retención, apelación y respuesta a incidentes;
- pruebas automatizadas de abuso, prompt injection y salidas inseguras.

## Referencias técnicas

- Firebase App Check: <https://firebase.google.com/docs/app-check>
- App Check para Cloud Functions: <https://firebase.google.com/docs/app-check/cloud-functions>
- Transacciones de Firestore: <https://firebase.google.com/docs/firestore/manage-data/transactions>
- OWASP LLM06 — Excessive Agency: <https://genai.owasp.org/llmrisk/llm062025-excessive-agency/>
