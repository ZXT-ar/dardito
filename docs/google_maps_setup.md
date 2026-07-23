# Google Maps en Dardito

## Configuración local

Durante el prototipo, la clave web se carga directamente en `web/index.html`,
tal como requiere `google_maps_flutter_web`. Una clave web siempre queda visible
para el navegador y debe protegerse mediante restricciones en Google Cloud.

El archivo `web/maps_config.js` permanece disponible para migrar a una plantilla
de despliegue cuando se incorpore la gestión centralizada de secretos:

```bash
cp web/maps_config.example.js web/maps_config.js
```

Luego reemplazá `YOUR_GOOGLE_MAPS_API_KEY` dentro del archivo local.

## Restricciones obligatorias en Google Cloud

Una clave de Maps JavaScript API necesariamente llega al navegador. Ocultarla
del repositorio evita filtraciones accidentales, pero la protección efectiva se
realiza en Google Cloud Console:

1. Seleccionar **Websites** como restricción de aplicación.
2. Autorizar `http://127.0.0.1:4174/*` y `http://localhost:4174/*` durante el
   desarrollo.
3. Al publicar, agregar únicamente los dominios HTTPS reales de Dardito.
4. En restricciones de API, permitir solamente **Maps JavaScript API**.
5. Configurar alertas de presupuesto, cuotas diarias y monitoreo de uso.
6. Usar claves separadas para web, Android e iOS.

La clave compartida durante el prototipo debe rotarse antes de producción.

## Personalización y límites

El estilo visual versionado está en
`assets/map/la_plata_map_style.json`. La cámara usa límites geográficos del
partido de La Plata, zoom mínimo y una corrección adicional al finalizar cada
desplazamiento para impedir que el usuario navegue fuera de la zona habilitada.
