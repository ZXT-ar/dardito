# Cartografía viva — preproducción, 2026-10-02

La portada y «Cada punto guarda algo para contar» comparten una sola proyección cartográfica. No se repite una imagen ni se monta un segundo mapa. Las calles se dibujan como tinta sobre papel; las plazas cambian a verde tilo cuando la aguja apunta al título. El estado se revierte al volver arriba; con movimiento reducido se muestra directamente el contenido activo.

Los marcadores proceden del catálogo público y conservan las coordenadas originales de cada historia. Se seleccionan puntos visibles y separados, con título, foco de teclado y apertura de la ficha correspondiente. El trazo que los une es editorial, no un itinerario peatonal calculado. No se cambia el catálogo ni ningún microservicio.

## Datos y proyección

`assets/map/home_cartography.json` contiene calles de la captura MapLibre local previamente usada para la portada: tamaño 3840 × 2160, centro [-57.954, -34.9205], zoom 13.5, orientación 42.1°. Los parques se obtuvieron el 2026-10-02 de la API pública de OpenStreetMap, bounding box [-57.982, -34.939, -57.932, -34.900], conservando identificador de vía y nombre. Se proyectan con el mismo Mercator (mundo de 512 px) y la misma rotación que las calles. Una única escala uniforme y traslación posicionan geometría y marcadores en toda la superficie.

Datos © OpenStreetMap contributors, licencia ODbL: https://www.openstreetmap.org/copyright. La cartografía está empaquetada; el inicio no hace consultas cartográficas externas en tiempo de ejecución. La carga del catálogo público permanece igual.

## Mapa de Explorar

`MapZoom` centraliza los límites 10.8–21 para gestos y botones. Antes el límite superior era 18. La cartografía y detalle disponibles dependen del proveedor Google Maps.

## Validación y publicación

Pruebas de proyección, activación reversible, movimiento reducido, clic de marcador a 390/768/1440 px y límites de zoom. Suite Flutter completa y revisión visual en navegador de la portada, transición, marcadores y zoom. Publicación exclusivamente de Firebase Hosting, proyecto dardito-742d2, mediante `scripts/build_preproduction.sh` y `firebase deploy --only hosting --project dardito-742d2`. Sin despliegue de Functions, reglas ni Hostinger.
