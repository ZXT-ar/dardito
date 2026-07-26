# MPP — Control de acceso y auditoría

## Fuente de autorización

La colección `verificados` contiene documentos con ID aleatorio y un campo:

```text
mail: string
```

El valor debe guardarse en minúsculas y sin espacios, por ejemplo:

```text
fulano@gmail.com
```

La Function `verifyMppAccess` exige una sesión de Firebase Authentication
iniciada con Google y un correo verificado. Luego busca una coincidencia exacta
en `verificados.mail`.

## Acceso aprobado

Si el correo existe, la Function:

1. entrega los datos del monitor al navegador;
2. inicia una sesión MPP de 14 minutos y 30 segundos;
3. actualiza en el documento coincidente el mapa `acceso`:

```text
acceso:
  ultimo:
    id
    email
    uid
    provider
    ip
    ipHash
    userAgent
    language
    origin
    referrer
    country
    region
    city
    client
    fechaHora
  ultimoAccesoAt
  cantidad
```

El campo `client` contiene únicamente metadatos técnicos necesarios para la
auditoría: zona horaria, idioma, plataforma, navegador informado, dimensiones
de pantalla y ventana, densidad de píxeles, capacidad táctil, cookies y hora
local.

## Acceso rechazado

Si el correo no existe, no se entregan los datos del proyecto. Se crea un
documento con ID aleatorio en `curiosos`, con la misma auditoría técnica y:

```text
resultado: "sin_acceso"
createdAt: timestamp del servidor
```

La interfaz muestra `No tienes acceso` y permite usar otra cuenta o solicitar
acceso.

## Vencimiento de sesión

La sesión dura 14 minutos y 30 segundos. Treinta segundos antes del vencimiento
se muestra `¿Seguís ahí?` con una cuenta regresiva.

- Si la persona confirma, la Function vuelve a validar el correo y genera una
  nueva ventana de acceso.
- Si no confirma, Firebase Authentication cierra la sesión automáticamente.
- Si el correo fue retirado de `verificados`, la renovación se rechaza y se
  cierra la sesión.

## Seguridad

- Firestore no permite lecturas ni escrituras directas desde el navegador.
- `verificados`, `curiosos` y el contenido del monitor se consultan solamente
  con Admin SDK dentro de Cloud Functions.
- Los avances no forman parte del archivo JavaScript público del portal.
- La validación tiene límites por usuario e IP para reducir abuso.
- La IP y los metadatos son datos personales: deben incluirse en la política de
  privacidad y conservarse solo durante el plazo operativo necesario.
