# Pestañas en línea — opción 1

Reemplazo de las secciones de categorías y destacados de Inicio, sin modificar el hero, la cartografía ni otras tarjetas del sitio.

- Cuatro pestañas de papel sobre una línea, tonos arena, oliva y ocre. En móvil o con tipografía ampliada se acomodan en dos filas; nunca se ocultan categorías.
- Cada pestaña conserva su filtro (architecture, mystery, culture, memory). La descripción editorial sigue disponible como tooltip.
- Tres historias destacadas del catálogo, sin tarjetas blancas ni iconos decorativos. Columnas con separadores finos en escritorio y lectura vertical en móvil. Los títulos se muestran completos y abren la misma ficha de historia.
- «Ver todas» abre Explorar también en móvil. El resto de historias permanece en el catálogo.
- Hover y foco discretos; texto subrayado al recibir foco, áreas pulsables amplias y respeto de movimiento reducido.

Validación: `flutter analyze lib`; 11 pruebas en `paper_discovery_test.dart` y `editorial_presentation_test.dart` (390/768/1440 px y escala de texto 1.8), más revisión de navegador. Compilación con `scripts/build_preproduction.sh`; despliegue solo de Firebase Hosting en dardito-742d2.
